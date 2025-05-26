#!/bin/bash
# .bashrc
HISTSIZE=40000
HISTFILESIZE=40000

PATH=$PATH:$HOME/.local/bin

alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'

alias ls='ls -G --color --group-directories-first'
alias ll='ls -lF --color --group-directories-first'

# User specific aliases and functions
export PATH="$HOME/.local/neovim/bin:$PATH"
alias cmake="cmake3"
alias vim="$HOME/.local/neovim/bin/nvim"
alias vimdiff="nvim -d"

function wttr() {
  if [ $# -eq 0 ]; then
    # curl -s https://v2.wttr.in/nyc?F
    curl -s v2.wttr.in/nyc?F | sed 's/^│//; s/│$//' | sed '/^[[:space:]╷]*$/d' | grep -v '^└─*┘$' | tail -n +2 | awk '{buffer[NR]=$0} END {print buffer[NR]; for (i=1; i<NR; i++) print buffer[i]}' | head -n -3 | awk '{buffer[NR]=$0} END {print buffer[NR]; for (i=1;
    i<NR; i++) print buffer[i]}' | head -n -2 | grep -v -E '([→↘↗].*){5,}'
  else
    # curl -s https://v2.wttr.in/"$*"?F
    curl -s v2.wttr.in/"$*"?F | sed 's/^│//; s/│$//' | sed '/^[[:space:]╷]*$/d' | grep -v '^└─*┘$' | tail -n +2 | awk '{buffer[NR]=$0} END {print buffer[NR]; for (i=1; i<NR; i++) print buffer[i]}' | head -n -3 | awk '{buffer[NR]=$0} END {print buffer[NR]; for (i=1;
i<NR; i++) print buffer[i]}' | head -n -2 | grep -v -E '([→↘↗].*){5,}'
  fi
}
function wttr1() {
  if [ $# -eq 0 ]; then
    curl -s https://wttr.in/F{nyc}?F
  else
    curl -s https://wttr.in/"$*"?F
  fi
}

# Dirs
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."
alias dnvim="cd $HOME/.config/nvim"
# alias tshark='tshark --color'
# alias gdb=/opt/rh/devtoolset-7/root/usr/bin/gdb

alias config='cd ~/.config/'
alias prec='pre-commit run --files $(git diff --name-only)'
alias precc='pre-commit run --files $(git diff --name-only HEAD^)'
alias precpr='pre-commit run --files $(git diff --name-only master...)'
alias ndb='vim -c DBUIToggle'

# # fzf
# alias pfzf='fzf --preview "bat --color=always {}"'
alias fvim='vim $(fzf --preview "bat --color=always {}")'
alias fkill='ps -ef | fzf | awk "{print $2}" | xargs kill -9'
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && ls; }
# fvim() { nvim "$(find . -type f -not -path '*/.*' | fzf --preview 'bat --color=always {}')"; }

function gfzf() {
    is_in_git_repo || return
    local filter
    if [[ -n $* ]] && [ -e $ ]; then
      filter="-- $*"
    fi;

    COMMIT=$(git log \
          --graph --color=always --abbrev=7 \
          --format="%C(bold blue)%h %C(auto)- %s%C(reset)%C(auto)%d %C(dim white)- %an%C(reset) %C(green)(%ar)%C(reset)" "$@" | \
              fzf --ansi --no-sort --layout=reverse --tiebreak=index \
                  --preview="f() { set -- \$(echo -- \$@ | rg -o '\b[a-f0-9]{7,}\b'); [ \$# -eq 0 ] || git show --color=always \$1 $filter | delta; }; f {}" \
                  --preview-window=bottom:60%)
    COMMIT_SHA=$(echo "$COMMIT" | rg -o '\b[a-f0-9]{7,}\b')
    echo "$COMMIT_SHA"
}                                                                                                                                                         \

# function gh() {
#   GIT_BASE=$(git remote -v | grep fetch | awk '{print $2}' | sed 's/git@/http:\/\//' | sed 's/com:/com\//' | sed 's/\.git//')
#   echo "${GIT_BASE}/tree/develop$(pwd | sed -E 's/.*repos//')"
# }

# git checkout worktree
# checks out a bare repo with
function gcw() {
  if [ "$1" = "" ]; then
    echo "No argument supplied"
    return
  fi
  REPO_ADDR=$1
  if [[ $# -eq 1 ]]; then # use repo dir name
    REPO_DIR=$(basename "$REPO_ADDR" .git)
  elif [[ $# -eq 2 ]]; then # repo url and dest path supplied
    REPO_DIR=$2
  fi
  echo "cloning into $REPO_DIR"

  git clone --bare -- "$REPO_ADDR" "$REPO_DIR" && cd "$REPO_DIR" || return

  # get name of the HEAD remote branch (main/master/...)
  MAIN_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5) # detect name of the main remote branch (main/master/...)
  git worktree add "$MAIN_BRANCH"
  cd "$MAIN_BRANCH"
  pre-commit install &>/dev/null || echo "pre-commit install failed"
  echo "cd to ${MAIN_BRANCH}-worktree directory.. (now in $PWD)"
}

function renamebranch() {
  if [ "$1" = "" ]; then
    echo "No argument supplied"
    return
  fi
  NEW_BRANCH_NAME=$1
  CURR_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)

  # rename local branch
  git branch -m "$CURR_BRANCH_NAME" "$NEW_BRANCH_NAME"
  # delete the old branch on remote
  git push origin :"$CURR_BRANCH_NAME"
  # don't push to old remote branch
  git branch --unset-upstream "$NEW_BRANCH_NAME"
  # push new branch to remote
  git push origin "$NEW_BRANCH_NAME"
  # set upstream
  git push origin -u "$NEW_BRANCH_NAME"
}

function confirm() {
  read -p "$1 [Y/n]?" -r
  echo # (optional) move to a new line
  [[ $REPLY =~ ^[Yy]$ ]]
  return
}

function diffv() {
  if [ "$#" -ne 2 ]; then
    echo "require 2 args"
    return
  fi
  # imply-local: https://github.com/sindrets/diffview.nvim/blob/3dc498c9777fe79156f3d32dddd483b8b3dbd95f/doc/diffview.txt#L148
  vim -c "DiffviewOpen $1..$2 --imply-local"
}

function reviewpr() {
  if [ "$1" = "" ]; then
    echo "No argument supplied. Please provide PR ID"
    return
  fi
  PR_ID=$1
  PR_BRANCH=PR_REVIEW
  BARE_DIR=$(git rev-parse --git-common-dir)
  # MAIN_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5)

  cd "$BARE_DIR"
  echo "removing $PR_BRANCH worktree"
  git worktree remove --force "$PR_BRANCH" 2>/dev/null || echo "$PR_BRANCH worktree doesn't exist"
  echo "removing $PR_BRANCH branch"
  git branch -D "$PR_BRANCH" 2>/dev/null || echo "$PR_BRANCH branch doesn't exist"
  git fetch origin pull/"$PR_ID/head:$PR_BRANCH"
  git worktree add "$PR_BRANCH" "$PR_BRANCH" || echo "$PR_BRANCH already exists"
  cd "$PR_BRANCH"
  CYAN='\033[0;36m'
  NC='\033[0m' # No Color
  # echo "Running cmake..."
  # ./run_cmake.sh &>/dev/null || echo "ERROR RUNNING CMAKE"
  # echo "Done"
  CMP_COMMIT=$(gfzf --)
  printf "commit:\n$CMP_COMMIT\n"
  printf "${CYAN}Changed files:\n"
  printf "  %s\n" "$(git diff --name-only "$CMP_COMMIT"...)"
  printf "$NC"

  if confirm "run pre-commit hooks [pre-commit run --files \$(git diff --name-only $CMP_COMMIT...)]"; then
    echo "runnign pre-commit hooks"
    # pre-commit run --show-diff-on-failure --files $(git diff --name-only $CMP_COMMIT...)
    # shellcheck disable=SC2086,SC2046
    pre-commit run --files $(git diff --name-only "$CMP_COMMIT"...) # ignore
  fi
  if confirm "open diffview [vim -c \"DiffviewOpen ${CMP_COMMIT}... --imply-local\"]"; then
    echo "running pre-commit hooks: [vim -c \"DiffviewOpen ${CMP_COMMIT}... --imply-local\"]"
    # imply-local: https://github.com/sindrets/diffview.nvim/blob/3dc498c9777fe79156f3d32dddd483b8b3dbd95f/doc/diffview.txt#L148
    vim -c "DiffviewOpen $CMP_COMMIT... --imply-local"
  fi
  echo "DONE WITH REVIEW"
}

function getbranch() {
  BRANCH_NAME=$1
  if git ls-remote --exit-code --heads origin refs/heads/"$BRANCH_NAME" &>/dev/null; then
    BARE_DIR=$(git rev-parse --git-common-dir)
    cd "$BARE_DIR"
    WT_PATH=$BARE_DIR/$BRANCH_NAME

    # git config --get remote.origin.fetch
    # -> should return: `+refs/heads/*:refs/remotes/origin/*`
    # -> if not, set refspec: git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    echo "fetching"
    git fetch
    echo "adding worktree"
    git worktree add "$BRANCH_NAME" || echo "already exists"
    cd "$WT_PATH"
    git checkout "$BRANCH_NAME"
  else
    echo "branch ${BRANCH_NAME} doens't exist in origin"
  fi
}

function removebranch() {
  BRANCH_NAME=$1
  BARE_DIR=$(git rev-parse --git-common-dir)
  cd "$BARE_DIR"

  # delete the old branch on remote
  git push origin :"$BRANCH_NAME" || echo "remote branch doesn't exists"
  # remove worktree
  git worktree remove --force "$BRANCH_NAME" 2>/dev/null || echo "$BRANCH_NAME worktree doesn't exist"
  git branch -D "$BRANCH_NAME"
}

function removecurrbranch() {
  CURR_BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD)
  BARE_DIR=$(git rev-parse --git-common-dir)
  cd "$BARE_DIR"

  # delete the old branch on remote
  git push origin :"$CURR_BRANCH_NAME" || echo "remote branch doesn't exists"
  # remove worktree
  git worktree remove --force "$CURR_BRANCH_NAME" 2>/dev/null || echo "$CURR_BRANCH_NAME worktree doesn't exist"
  git branch -D "$CURR_BRANCH_NAME"
}

function getinitials() {
  word_count=$(echo "$1" | wc -w)

  if [ "$word_count" -eq 1 ]; then
    echo "$1" | awk '{print toupper(substr($0, 1, 2))}'
  else
    echo "$1" | awk '{for(i=1;i<=NF;i++) printf "%s", toupper(substr($i,1,1))}'
  fi
}

function nbranch() {
  if [ "$1" = "" ]; then
    echo "No argument supplied"
    return
  fi

  INITIALS=$(getinitials "$(git config user.name)")

  DESC="${1#"${INITIALS}_"}"
  BRANCH_NAME=${INITIALS}_$DESC

  # check if inside a worktree (1st check) or if inside a bare repository (2nd check)
  if [[ $(git rev-parse --git-dir) != $(git rev-parse --git-common-dir) || $(git rev-parse --is-bare-repository) == "true" ]]; then
    # get directory of the root bare dir (make worktree branch relative to bare dir)
    BARE_DIR=$(git rev-parse --git-common-dir)
    cd "$BARE_DIR"
    WT_PATH=$BARE_DIR/$BRANCH_NAME
    echo "In bare git worktree repo... checking out $BRANCH_NAME into $WT_PATH"
    git worktree add -b "$BRANCH_NAME" "$WT_PATH"
    cd "$WT_PATH"
    git push --set-upstream origin "$BRANCH_NAME"
  else
    echo "In normal git repo"
    git checkout -b "$BRANCH_NAME"
    git push --set-upstream origin "$BRANCH_NAME"
  fi
}

alias resurrect="tmux new-session -d && tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && tmux kill-session -t 0"
function ta() {
  if [ "$1" = "" ]; then
    tmux a -d -t main
  else
    tmux a -d -t "$1"
  fi
}

function za() {
  zellij attach --create main
}

function tn() {
  if [ "$1" = "" ]; then
    tmux new -s main
  else
    tmux new -s "$1"
  fi
}
function tl() {
  tmux 'ls'
}

# Source global definitions
if [[ "$OSTYPE" == "darwin"* ]]; then
  eval "$(starship init zsh)"
  source /usr/share/fzf/shell/key-bindings.zsh
else
  source "$HOME/.fzf.bash"
  if [ -f /etc/bashrc ]; then
    . /etc/bashrc
  fi
  eval "$(starship init bash)"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
  # Mac OSX: no leak sanatizer
  function cr() {
    g++ -Wall \
      -g \
      -Werror \
      -Wextra \
      -std=c++20 \
      -O1 \
      -fsanitize=undefined \
      -fsanitize=address \
      -fno-omit-frame-pointer \
      -fno-sanitize-recover=all \
      -o "$1".out "$1".cpp &&
      ./"$1".out
  }
else
  function cr() {
    g++ -Wall \
      -g \
      -Werror \
      -Wextra \
      -std=c++20 \
      -O1 \
      -fsanitize=address \
      -fsanitize=leak \
      -fsanitize=undefined \
      -fno-sanitize-recover=all \
      -fno-omit-frame-pointer \
      -o "$1".out "$1".cpp &&
      ./"$1".out
      # -L /usr/lib/gcc/x86_64-redhat-linux/8/ \
  }
fi

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# export CXX=/usr/local/bin/g++

# ## clang format
# function format {
# 	curr=$(pwd)
# 	x=$curr
# 	while [ "$x" != "/" ]; do
# 		if [[ $(basename $x) == "src" ]]; then
# 			cd $x/..
# 			for script in $(find . -name "clang-format-diff.py"); do
# 				cd src
# 				if [[ $1 == "--dry-run" ]]; then
# 					git diff -U0 --no-color --relative HEAD^ | ../$script -p1
# 				else
# 					git diff -U0 --no-color --relative HEAD^ | ../$script -p1 -i
# 				fi
# 				break
# 			done
# 			break
# 		fi
# 		x=$(dirname "$x")
# 	done
# 	cd $curr
# }

# source <(kubectl completion bash)
# . "$HOME/.cargo/env"

if [ -f /usr/share/bash-completion/completions/git ]; then
  source /usr/share/bash-completion/completions/git
fi

# history
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
alias hget='history -c; history -r'

# bat
export BAT_THEME=tokyonight_night
source ~/.fzf/fzf-git.sh/fzf-git.sh

export FZF_DEFAULT_OPTS="--bind 'ctrl-d:preview-half-page-down,ctrl-u:preview-half-page-up'"

function is_in_git_repo() {
    # git rev-parse HEAD > /dev/null 2>&1
    git rev-parse HEAD > /dev/null
}


eval "$(zoxide init bash)"

# https://github.com/mtzfactory/dotfiles/blob/c847d957aeb8b12555db28fce2ae5a4bf886bc5c/custom-git-commands/git-fzf-test#L75
# function gfzf() {
#     local filter;
#
#     if [ -n $@ ] && [ -e $@ ]; then
#         filter=\"-- $@\";
#     fi;
#
#     # export LESS='-R'
#     # export BAT_PAGER='less -S -R -M -i';
#   # COMMIT_SHA=$(echo "$COMMIT" | rg -o '\b[a-f0-9]{7,}\b');                                                                                     \
#
#     git log \
#         --graph --color=always --abbrev=7 --glob="refs/heads/*" \
#         --format=format:"%C(bold blue)%h%C(reset) %C(dim white)%an%C(reset)%C(bold yellow)%d%C(reset) %C(white)%s%C(reset) %C(bold green)(%ar)%C(reset)" $@ |
#             fzf --ansi --no-sort --layout=reverse --tiebreak=index \
#                 --preview="f() { set -- $(echo -- $@ | rg -o '\b[a-f0-9]{7,}\b'); [ $# -eq 0 ] || git show --color=always $1 $filter | delta --line-numbers; }; f" \
#                 --bind="ctrl-j:preview-down,ctrl-k:preview-up,ctrl-f:preview-page-down,ctrl-b:preview-page-up" \
#                 --bind="ctrl-m:execute:
#                         (rg -o '\b[a-f0-9]{7,}\b' | head -1 | xargs -I % -- git show --color=always %) << 'FZF-EOF'
#                         {}
#                         FZF-EOF" \
#                 --preview-window=right:60%;
#                 # --bind="alt-h:execute-silent:
#                 #         (f() { set -- $(rg -o '\b[a-f0-9]{7,}\b' | head -1 | tr -d $'\n');
#                 #         [[ -n $TMUX ]] && tmux display -d0 \"#[bg=blue,italics] Branches #[none,fg=black,bg=default] $(git branch --contains $1 | sed 's/^\*\?\s'
#                 #         | sort | paste -sd, - | sed 's/,/, /g')\"; }; f) << 'FZF-EOF'
#                 #         {}
#                 #         FZF-EOF" \
#                 # --bind="alt-H:execute-silent: \
#                 #         (f() { set -- $(rg -o '\b[a-f0-9]{7,}\b' | head -1 | tr -d $'\n'); \
#                 #         SUMMARY=\"$(git show --format='%s' $1 | head -1)\"; \
#                 #         [[ -n $TMUX ]] && tmux display -d0 \"#[bg=blue,italics] Branches (Grep) #[none,fg=black,bg=default] $(git log --all --format='%H' -F \
#                 #         --grep=\"$SUMMARY\" | xargs -I{} -- git branch --contains {} \
#                 #         | sed 's/^\*\?\s\+/' | sort | uniq | paste -sd, - | sed 's/,/, /g')\"; }; f) << FZFEOF\n \
#                 #         {} \
#                 #         \nFZFEOF" \
#                 # --bind="alt-n:execute-silent: \
#                 #         (f() { set -- $(rg -o '\b[a-f0-9]{7,}\b' | head -1 | tr -d $'\n'); \
#                 #         [[ -n $TMUX ]] && tmux display -d0 \"#[bg=blue,italics] Tags #[none,fg=black,bg=default] $(git tag --contains $1 | sed 's/^\*\?\s\+/' \
#                 #         | sort | paste -sd, - | sed 's/,/, /g')\"; }; f) << FZFEOF\n \
#                 #         {} \
#                 #         \nFZFEOF" \
#                 # --bind="alt-N:execute-silent: \
#                 #         (f() { set -- $(rg -o '\b[a-f0-9]{7,}\b' | head -1 | tr -d $'\n'); \
#                 #         SUMMARY=\"$(git show --format='%s' $1 | head -1)\"; \
#                 #         [[ -n $TMUX ]] && tmux display -d0 \"#[bg=blue,italics] Tags (Grep) #[none,fg=black,bg=default] $(git log --all --format='%H' -F \
#                 #         --grep=\"$SUMMARY\" | xargs -I{} -- git tag --contains {} \
#                 #         | sed 's/^\*\?\s\+/' | sort | uniq | paste -sd, - | sed 's/,/, /g')\"; }; f) << FZFEOF\n \
#                 #         {} \
#                 #         \nFZFEOF" \
#                 # --bind="ctrl-y:execute-silent: \
#                 #         (f() { set -- $(rg -o '\b[a-f0-9]{7,}\b' | head -1 | tr -d $'\n'); \
#                 #         printf '%s' $1 | clipboard; [[ -n $TMUX ]] && tmux display \"#[bg=blue,italics] Yanked #[none,fg=black,bg=default] $1\"; }; f) << FZFEOF\n \
#                 #         {} \
#                 #         \nFZFEOF" \
#                 # --bind="ctrl-s:execute-silent: \
#                 #         (f() { set -- $(rg -o '\b[a-f0-9]{7,}\b' | head -1 | tr -d $'\n'); \
#                 #         SUMMARY=\"$(git show --format='%s' $1 | head -1)\"; \
#                 #         printf '%s' \"$SUMMARY\" | clipboard; \
#                 #         [[ -n $TMUX ]] && tmux display \"#[bg=blue,italics] Yanked #[none,fg=black,bg=default] $SUMMARY\"; }; f) << FZFEOF\n \
#                 #         {} \
#                 #         \nFZFEOF" \
#                 # --bind="ctrl-l:execute:(f() { set -- $(rg -o '\b[a-f0-9]{7,}\b' | head -1 | tr -d $'\n'); git lgl | less -p $1 +'u'; }; f) << FZFEOF\n \
#                 #         {} \
#                 #         \nFZFEOF" \
# };
