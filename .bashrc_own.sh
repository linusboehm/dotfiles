# .bashrc
HISTSIZE=40000
HISTFILESIZE=40000

# PATH=/opt/rh/llvm-toolset-7/root/bin:$PATH
# PATH=/usr/include/linux:$PATH
# PATH=/usr/include:$PATH
PATH=$PATH:$HOME/local/bin
PATH=$PATH:$HOME/.local/bin

alias ls='ls -G --color --group-directories-first'
alias ll='ls -lF --color --group-directories-first'
alias gh="echo \"$(git remote -v | grep fetch | awk '{print $2}' | sed 's/git@/http:\/\//' | sed 's/com:/com\//' | sed 's/\.git//')/tree/develop/$(pwd | sed -E 's/.*repos//')\""

function nbranch() {
	if [ -z "$1" ]; then
		echo "No argument supplied"
	else
		git checkout -b "$USER/$1"
		git push --set-upstream origin "$USER/$1"
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
else
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


# User specific aliases and functions
alias cmake="cmake3"
alias vim="nvim"
alias vimdiff="nvim -d"
alias ..="cd .."
alias ...="cd ../.."
# alias tshark='tshark --color'
# alias gdb=/opt/rh/devtoolset-7/root/usr/bin/gdb

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

alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'

# history
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"
# history -c
# history -r
alias hget='history -c; history -r'
