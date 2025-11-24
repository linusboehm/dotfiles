#!/usr/bin/env python3
# jenkins_notify.py
# Notify via ntfy when a Jenkins job build finishes.
#
# Usage (YAML creds):
#   python ntfy_jenkins.py --creds ~/creds/jensins_creds.yml --job nudge-qa-test-el8
#
# YAML format:
#   user: "alice"
#   api_token: "xxxxxxxxxxxxxxxxx"
#   ntfy_url: "https://ntfy.sh"
#   ntfy_topic: "some_topic"
#   jenkins_url: "https://jenkins.com"
#   interval: 3
#   insecure: false

import argparse
import datetime
import os
import sys
import time
import urllib.parse

import requests
import yaml  # type: ignore
from requests.exceptions import RequestException


def parse_arguments():
    p = argparse.ArgumentParser(
        description="Notify via ntfy when a Jenkins job build finishes."
    )

    p.add_argument(
        "--creds",
        help="Path to YAML file with {user, api_token[, ntfy_url, interval, insecure]}",
    )
    p.add_argument(
        "--wait-next",
        action="store_true",
        help="Wait for next build if none is running",
    )
    p.add_argument(
        "--ntfy-url",
        default=None,
        help="ntfy base URL (default: https://ntfy.sh or creds.yml ntfy_url)",
    )
    p.add_argument(
        "--interval",
        type=int,
        default=None,
        help="Poll interval seconds (default: 3 or creds.yml interval)",
    )
    p.add_argument("--job", help="Slash style name, e.g. folder1/folder2/my-job")
    return p.parse_args()


def job_pathize(slash_name: str) -> str:
    # "a/b/c" -> "job/a/job/b/job/c"
    return "/".join(f"job/{p}" for p in slash_name.split("/") if p)


def fmt_duration(ms: int) -> str:
    secs = int(ms // 1000)
    h, r = divmod(secs, 3600)
    m, s = divmod(r, 60)
    out = []
    if h:
        out.append(f"{h}h")
    if m:
        out.append(f"{m}m")
    out.append(f"{s}s")
    return " ".join(out)


def get_json(url, auth, verify=True, timeout=20):
    r = requests.get(url, auth=auth, timeout=timeout, verify=verify)
    r.raise_for_status()
    return r.json()


def notify(ntfy_url, topic, title, body, tags="white_check_mark", priority=3):
    url = ntfy_url.rstrip("/") + "/" + urllib.parse.quote(topic, safe="")
    headers = {"Title": title, "Tags": tags, "Priority": str(priority)}
    try:
        requests.post(url, data=body.encode("utf-8"), headers=headers, timeout=20)
    except RequestException:
        # Don't crash if ntfy fails; we still exit with build code below.
        pass


def load_yaml_creds(path: str) -> dict:
    if not os.path.exists(path):
        print(f"Error: creds file not found: {path}", file=sys.stderr)
        sys.exit(2)
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}
            if not isinstance(data, dict):
                raise ValueError("Top-level YAML must be a mapping.")
            return data
    except Exception as e:
        print(f"Error: failed to read creds YAML: {e}", file=sys.stderr)
        sys.exit(2)


def print_progress(
    est: int, start_ts: int, last_bucket: int, full_name: str, target_num: int
) -> int:
    if est > 0:
        now_ms = int(time.time() * 1000)
        elapsed = max(0, now_ms - start_ts)
        pct = max(0, min(99, int((elapsed / est) * 100)))
        bucket = (pct // 10) * 10
        if bucket != last_bucket:
            remaining_ms = max(0, est - elapsed)
            eta_s = remaining_ms // 1000
            h, r = divmod(eta_s, 3600)
            m, s = divmod(r, 60)
            finish_time = datetime.datetime.fromtimestamp(time.time() + eta_s).strftime(
                "%Y-%m-%d %H:%M:%S"
            )
            eta = (f"{h}h " if h else "") + (f"{m}m " if m else "") + f"{s}s"
            msg = f"{full_name} #{target_num}: ~{pct}% done, ETA {eta} ({finish_time})"
            print(msg, file=sys.stderr)
    return bucket


def setup_config(args, creds) -> dict:
    user = creds["user"]
    token = creds["api_token"]
    ntfy_url = args.ntfy_url or creds.get("ntfy_url", "https://ntfy.sh")
    interval = (
        args.interval if args.interval is not None else int(creds.get("interval", 3))
    )
    insecure = bool(creds.get("insecure", False))
    verify = not insecure
    auth = (user, token)

    return {
        "auth": auth,
        "ntfy_url": ntfy_url,
        "interval": interval,
        "verify": verify,
        "jenkins_url": creds["jenkins_url"],
        "ntfy_topic": creds["ntfy_topic"],
    }


def monitor_build(
    build_api, auth, verify, interval, full_name, target_num, config, job_name
):
    print(f"Tracking {full_name} #{target_num} …", file=sys.stderr)
    est = None
    last_bucket = -1

    while True:
        try:
            bj = get_json(build_api, auth, verify)
            if est is None:
                est = int(bj.get("estimatedDuration", 0))
                start_ts = int(bj.get("timestamp", 0))
        except RequestException:
            time.sleep(interval)
            continue

        last_bucket = print_progress(est, start_ts, last_bucket, full_name, target_num)

        if not bj.get("building", False):
            result = bj.get("result") or "UNKNOWN"
            duration = fmt_duration(bj.get("duration", 0))

            tag, prio, code = {
                "SUCCESS": ("white_check_mark", 3, 0),
                "UNSTABLE": ("warning", 3, 3),
                "ABORTED": ("no_entry_sign", 3, 130),
                "FAILURE": ("x", 4, 1),
            }.get(result, ("grey_question", 3, 2))

            build_base = (
                f"{config['jenkins_url'].rstrip('/')}"
                f"/{job_pathize(job_name)}/{target_num}"
            )
            title = f"Jenkins: {full_name} #{target_num} {result}"
            body = f"{full_name} #{target_num} finished with {result} in {duration}"
            print(title)
            print(f"  {body}")
            print(f"  {build_base}")
            notify(
                config["ntfy_url"],
                config["ntfy_topic"],
                title,
                body,
                tags=tag,
                priority=prio,
            )
            return code

        time.sleep(interval)


def determine_target_build(job_api, auth, verify, args, interval):
    try:
        job = get_json(job_api, auth, verify)
    except RequestException as e:
        print(f"Error: failed to query job API: {e}", file=sys.stderr)
        return None, None, 2

    full_name = job.get("fullName", args.job)
    last_build = job.get("lastBuild") or {}
    lb_num = last_build.get("number")
    lb_building = bool(last_build.get("building", False))

    print(
        f"Job: {full_name=}, {last_build=}, {lb_num=}, {lb_building=}", file=sys.stderr
    )

    if lb_num is None:
        if not args.wait_next:
            print(
                f"{full_name}: no builds found. Use --wait-next to wait for next.",
                file=sys.stderr,
            )
            return None, None, 2
        print("Waiting for the first build to start…", file=sys.stderr)

    target_num = lb_num

    if lb_num is not None and not lb_building and not args.wait_next:
        print(
            f"Tracking latest build #{lb_num} (may already be finished)…",
            file=sys.stderr,
        )
    else:
        while True:
            try:
                job = get_json(job_api, auth, verify)
            except RequestException:
                time.sleep(interval)
                continue
            last_build = job.get("lastBuild") or {}
            new_num = last_build.get("number")
            building = last_build.get("building", False)

            if building and new_num is not None:
                target_num = new_num
                break

            if (
                args.wait_next
                and new_num is not None
                and (lb_num is None or new_num > lb_num)
            ):
                target_num = new_num
                break

            time.sleep(interval)

    if target_num is None:
        print("Could not determine build number to track.", file=sys.stderr)
        return None, None, 2

    return target_num, full_name, 0


def main():
    args = parse_arguments()
    creds = load_yaml_creds(args.creds)
    config = setup_config(args, creds)
    # Build job API URL
    job_path = job_pathize(args.job)
    job_api = (
        f"{config['jenkins_url'].rstrip('/')}/{job_path}/api/json"
        "?tree=fullName,lastBuild[number,building,url],lastCompletedBuild[number]"
    )
    # Determine which build to track
    target_num, full_name, exit_code = determine_target_build(
        job_api, config["auth"], config["verify"], args, config["interval"]
    )
    if exit_code != 0:
        return exit_code

    # Build monitoring API URL
    build_api = f"{config['jenkins_url'].rstrip('/')}/{job_path}/{target_num}/api/json"

    # Monitor the build until completion
    return monitor_build(
        build_api,
        config["auth"],
        config["verify"],
        config["interval"],
        full_name,
        target_num,
        config,
        args.job,
    )


if __name__ == "__main__":
    sys.exit(main())
