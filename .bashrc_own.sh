# .bashrc
HISTSIZE=40000
HISTFILESIZE=40000

PATH=$PATH:$HOME/.local/bin

alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'

alias ls='ls -G --color --group-directories-first'
alias ll='ls -lF --color --group-directories-first'

# User specific aliases and functions
alias cmake="cmake3"
alias vim="nvim"
alias vimdiff="nvim -d"

# Dirs
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias ......="cd ../../../../.."
# alias tshark='tshark --color'
# alias gdb=/opt/rh/devtoolset-7/root/usr/bin/gdb

alias config='cd ~/.config/'

# # fzf
# alias pfzf='fzf --preview "bat --color=always {}"'
alias fvim='vim $(fzf --preview "bat --color=always {}")'
alias fkill='ps -ef | fzf | awk "{print $2}" | xargs kill -9'
fcd() { cd "$(find . -type d -not -path '*/.*' | fzf)" && ls; }
# fvim() { nvim "$(find . -type f -not -path '*/.*' | fzf --preview 'bat --color=always {}')"; }

function gh() {
    GIT_BASE=$(git remote -v | grep fetch | awk '{print $2}' | sed 's/git@/http:\/\//' | sed 's/com:/com\//' | sed 's/\.git//')
    echo "${GIT_BASE}/tree/develop$(pwd | sed -E 's/.*repos//')"
}


# git checkout worktree
# checks out a bare repo with 
function gcw() {
	if [ -z "$1" ]; then
		echo "No argument supplied"
        exit 0
    fi
    REPO_ADDR=$1
    if [[ $# -eq 1 ]]; then # use repo dir name
        REPO_DIR=$(basename "$REPO_ADDR" .git)
    elif [[ $# -eq 2 ]]; then # repo url and dest path supplied
        REPO_DIR=$2
    fi
    echo "cloning into $REPO_DIR"

    git clone --bare -- $REPO_ADDR $REPO_DIR && cd $REPO_DIR

    # get name of the HEAD remote branch (main/master/...)
    MAIN_BRANCH=$(git remote show origin | grep 'HEAD branch' | cut -d' ' -f5) # detect name of the main remote branch (main/master/...)
    git worktree add ${MAIN_BRANCH}
    cd $MAIN_BRANCH
    pre-commit install &>/dev/null || echo "pre-commit install failed"
    echo "cd to ${MAIN_BRANCH}-worktree directory.. (now in $PWD)"
}

function getbranch() {
    BRANCH_NAME=$1
    if git ls-remote --exit-code --heads origin refs/heads/$BRANCH_NAME &>/dev/null; then
        BARE_DIR=$(git rev-parse --git-common-dir)
        cd $BARE_DIR
        WT_PATH=$BARE_DIR/$BRANCH_NAME

        echo "fetching"
        git fetch
        echo "adding worktree"
        git worktree add $BRANCH_NAME || echo "already exists"
        cd $WT_PATH
    else
        echo "branch ${BRANCH_NAME} doens't exist in origin"
    fi
}

function nbranch() {
	if [ -z "$1" ]; then
		echo "No argument supplied"
        exit 0
    fi

    INITIALS=$(git config user.name | sed "s/[a-z ]//g" | tr '[:lower:]' '[:upper:]')
    DESC="${1#${INITIALS}_}"
    BRANCH_NAME=${INITIALS}_$DESC

    # check if inside a worktree (1st check) or if inside a bare repository (2nd check)
    if [[ $(git rev-parse --git-dir) != $(git rev-parse --git-common-dir) || $(git rev-parse --is-bare-repository) == "true" ]]; then
        # get directory of the root bare dir (make worktree branch relative to bare dir)
        BARE_DIR=$(git rev-parse --git-common-dir)
        cd $BARE_DIR
        WT_PATH=$BARE_DIR/$BRANCH_NAME
        echo "In bare git worktree repo... checking out $BRANCH_NAME into $WT_PATH"
        git worktree add -b $BRANCH_NAME $WT_PATH
        cd $WT_PATH
        git push --set-upstream origin "$BRANCH_NAME"
    else
        echo "In normal git repo"
        git checkout -b "$BRANCH_NAME"
        git push --set-upstream origin "$BRANCH_NAME"
    fi
}

alias resurrect="tmux new-session -d && tmux run-shell ~/.config/tmux/plugins/tmux-resurrect/scripts/restore.sh && tmux kill-session -t 0"
function ta() {
	if [ -z "$1" ]; then
		tmux a -d -t main
	else
		tmux a -d -t $1
	fi
}

function tn() {
	if [ -z "$1" ]; then
		tmux new -s main
	else
		tmux new -s $1
	fi
}
function tl() {
	tmux ls
}

# Source global definitions
if [[ "$OSTYPE" == "darwin"* ]]; then
    eval "$(starship init zsh)"
    source /usr/share/fzf/shell/key-bindings.zsh
else
    source ~/.fzf.bash
	if [ -f /etc/bashrc ]; then
		. /etc/bashrc
	fi
    eval "$(starship init bash)"
fi

if [[ "$OSTYPE" == "darwin"* ]]; then
	# Mac OSX: no leak sanatizer
	function cr() {
		g++ -Wall \
			-Werror \
			-Wextra \
			-std=c++20 \
			-O1 \
			-fsanitize=address \
			-fsanitize=undefined \
			-fno-omit-frame-pointer \
			-fno-sanitize-recover=all \
			-o $1.out $1.cpp &&
			./$1.out
	}
else
	function cr() {
		g++ -Wall \
			-Werror \
			-Wextra \
			-std=c++20 \
			-O1 \
			-fsanitize=leak \
			-fsanitize=address \
			-fsanitize=undefined \
			-fno-omit-frame-pointer \
			-fno-sanitize-recover=all \
			-o $1.out $1.cpp &&
			./$1.out
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

source /usr/share/bash-completion/completions/git

# history
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
# history -c
# history -r
alias hget='history -c; history -r'

 export PATH="$PATH:/home/lboehm/.local/nvim-linux64/bin"
