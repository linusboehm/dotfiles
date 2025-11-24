#!/usr/bin/env python3
# jenkins_notify.py
# Notify via ntfy when a Jenkins job (and optionally its downstream children) finish.

# YAML creds example (~/.config/jenkins/creds.yml):
#   user: "alice"
#   api_token: "XXXXXXXXX"
#   jenkins_url: "https://jenkins.example.com"
#   ntfy_url: "https://ntfy.sh"
#   ntfy_topic: "my-topic"
#   interval: 3
#   insecure: false

import argparse
import datetime
import os
import re
import sys
import time
import urllib.parse
from urllib.parse import urlparse

import requests  # pip install requests pyyaml
import yaml
from requests.exceptions import RequestException

# ---------- CLI ----------


def parse_arguments():
    p = argparse.ArgumentParser(
        description="Notify via ntfy when a Jenkins job build finishes."
    )
    p.add_argument("--creds", required=True, help="Path to YAML config")
    p.add_argument(
        "--job", required=True, help="Slash style job name, e.g. folder1/folder2/my-job"
    )
    p.add_argument(
        "--wait-next",
        action="store_true",
        help="Wait for next build if none is running",
    )
    p.add_argument(
        "--check-children",
        default=True,
        action="store_true",
        help="Monitor downstream children recursively",
    )
    p.add_argument(
        "--max-depth",
        type=int,
        default=3,
        help="Max child depth (default 3, 1 = only direct children)",
    )
    return p.parse_args()


# ---------- Helpers ----------


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
        pass  # notification failure shouldn't crash the script


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


def setup_config(args, creds) -> dict:
    user = creds["user"]
    token = creds["api_token"]
    ntfy_url = creds.get("ntfy_url", "https://ntfy.sh")
    interval = int(creds.get("interval", 3))
    insecure = bool(creds.get("insecure", False))
    verify = not insecure
    auth = (user, token)
    return {
        "auth": auth,
        "verify": verify,
        "jenkins_url": creds["jenkins_url"],
        "ntfy_url": ntfy_url,
        "ntfy_topic": creds["ntfy_topic"],
        "interval": interval,
    }


def print_progress(
    est_ms: int, start_ts_ms: int, last_bucket: int, full_name: str, build_num: int
) -> int:
    if est_ms > 0 and start_ts_ms > 0:
        now_ms = int(time.time() * 1000)
        elapsed = max(0, now_ms - start_ts_ms)
        pct = max(0, min(99, int((elapsed / est_ms) * 100)))
        bucket = (pct // 10) * 10
        if bucket != last_bucket:
            remaining_ms = max(0, est_ms - elapsed)
            eta_s = remaining_ms // 1000
            h, r = divmod(eta_s, 3600)
            m, s = divmod(r, 60)
            finish_local = datetime.datetime.fromtimestamp(
                time.time() + eta_s
            ).strftime("%Y-%m-%d %H:%M:%S")
            eta = (f"{h}h " if h else "") + (f"{m}m " if m else "") + f"{s}s"
            print(
                f"{full_name} #{build_num}: ~{pct}% done, ETA {eta} (~{finish_local})",
                file=sys.stderr,
            )
        return bucket
    return last_bucket


# ---------- Discover children from finished build ----------

_CHILD_URL_RE = re.compile(r"/(?:(?:job/[^/]+/)+)(\d+)/?$")


def _slash_name_from_job_url(url: str) -> str | None:
    try:
        path = urlparse(url).path.strip("/")
    except Exception:
        return None
    parts = path.split("/")
    if parts and parts[-1].isdigit():
        parts = parts[:-1]
    names = []
    for i in range(0, len(parts), 2):
        if parts[i] == "job" and i + 1 < len(parts):
            names.append(parts[i + 1])
    return "/".join(names) if names else None


def _build_number_from_url(url: str) -> int | None:
    try:
        m = _CHILD_URL_RE.search(urlparse(url).path)
        return int(m.group(1)) if m else None
    except Exception:
        return None


def find_children(build_api: str, auth, verify) -> list[dict]:
    try:
        extra = get_json(
            build_api
            + "?tree=actions[downstreamBuilds[number,url,jobName],subBuilds[result,url,jobName,buildNumber]]",
            auth,
            verify,
        )
    except RequestException:
        return []
    children: list[dict] = []
    for act in extra.get("actions", []) or []:
        for d in act.get("downstreamBuilds") or []:
            job = d.get("jobName") or _slash_name_from_job_url(d.get("url") or "")
            num = d.get("number") or _build_number_from_url(d.get("url") or "")
            if job and num:
                children.append({"job": job, "number": int(num), "url": d.get("url")})
        for s in act.get("subBuilds") or []:
            job = s.get("jobName") or _slash_name_from_job_url(s.get("url") or "")
            num = s.get("buildNumber") or _build_number_from_url(s.get("url") or "")
            if job and num:
                children.append(
                    {
                        "job": job,
                        "number": int(num),
                        "url": s.get("url"),
                        "result": s.get("result"),
                    }
                )
    return children


# ---------- Core: monitor a single build ----------


def monitor_build(
    build_api,
    auth,
    verify,
    interval,
    full_name_for_print,
    build_num,
    config,
    job_name_for_url,
):
    print(f"Tracking {full_name_for_print} #{build_num} …", file=sys.stderr)
    est = None
    start_ts = 0
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

        last_bucket = print_progress(
            est or 0, start_ts, last_bucket, full_name_for_print, build_num
        )

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
                f"{config['jenkins_url'].rstrip('/')}/"
                f"{job_pathize(job_name_for_url)}/{build_num}"
            )
            title = f"Jenkins: {full_name_for_print} #{build_num} {result}"
            body = (
                f"{full_name_for_print} #{build_num} finished "
                f"with {result} after {duration}\n{build_base}"
            )
            print(title)
            print(f"  {body.replace(chr(10), '  ')}")
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


# ---------- Build selection ----------


def determine_target_build(
    job_api, auth, verify, wait_next: bool, interval: int, job_fallback_name: str
):
    try:
        job = get_json(job_api, auth, verify)
    except RequestException as e:
        print(f"Error: failed to query job API: {e}", file=sys.stderr)
        return None, None, 2

    full_name = job.get("fullName", job_fallback_name)
    last_build = job.get("lastBuild") or {}
    lb_num = last_build.get("number")
    lb_building = bool(last_build.get("building", False))

    if lb_num is None:
        if not wait_next:
            print(
                f"{full_name}: no builds found. Use --wait-next to wait for next.",
                file=sys.stderr,
            )
            return None, None, 2
        print("Waiting for the first build to start…", file=sys.stderr)

    target_num = lb_num

    if lb_num is not None and not lb_building and not wait_next:
        print(
            f"Tracking latest build #{lb_num} (may already be finished)…",
            file=sys.stderr,
        )
    else:
        # Wait for a running or next build
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
                wait_next
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


# ---------- Recursive driver (single entry) ----------


def monitor_build_tree(
    job, build_num, config, max_depth=3, check_children=False, depth=0, visited=None
):
    """
    Monitor one build, then (optionally) its downstream children up to max_depth.
    Returns worst non-zero exit code across the subtree.
    """
    visited = visited or set()
    key = (job, build_num)
    if key in visited:
        return 0
    visited.add(key)

    job_path = job_pathize(job)
    build_api = f"{config['jenkins_url'].rstrip('/')}/{job_path}/{build_num}/api/json"

    # Name to print: prefer Jenkins' full display name if available
    try:
        meta = get_json(build_api, config["auth"], config["verify"])
        full_name = meta.get("fullDisplayName") or meta.get("fullName") or job
    except RequestException:
        full_name = job

    code = monitor_build(
        build_api,
        config["auth"],
        config["verify"],
        config["interval"],
        full_name,
        build_num,
        config,
        job,
    )

    if not check_children or depth >= max_depth:
        return code

    # Discover and recurse
    children = find_children(build_api, config["auth"], config["verify"])
    if not children:
        return code

    indent = "  " * depth
    print(
        f"{indent}Found {len(children)} downstream build(s) under {job} #{build_num}",
        file=sys.stderr,
    )

    worst = code
    for c in children:
        c_job = c["job"]
        c_num = c["number"]
        child_code = monitor_build_tree(
            c_job, c_num, config, max_depth, check_children, depth + 1, visited
        )
        if worst == 0 and child_code != 0:
            worst = child_code
    return worst


# ---------- main ----------


def main():
    args = parse_arguments()
    creds = load_yaml_creds(args.creds)
    config = setup_config(args, creds)

    job_path = job_pathize(args.job)
    job_api = (
        f"{config['jenkins_url'].rstrip('/')}/{job_path}/api/json"
        "?tree=fullName,lastBuild[number,building,url],lastCompletedBuild[number]"
    )

    target_num, full_name, exit_code = determine_target_build(
        job_api,
        config["auth"],
        config["verify"],
        args.wait_next,
        config["interval"],
        args.job,
    )
    if exit_code != 0:
        return exit_code

    return monitor_build_tree(
        job=args.job,
        build_num=target_num,
        config=config,
        max_depth=args.max_depth,
        check_children=args.check_children,
    )


if __name__ == "__main__":
    sys.exit(main())
