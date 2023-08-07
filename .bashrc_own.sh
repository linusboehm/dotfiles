# .bashrc
HISTSIZE=40000
HISTFILESIZE=40000

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
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

# PATH=/opt/rh/llvm-toolset-7/root/bin:$PATH
# PATH=/usr/include/linux:$PATH
# PATH=/usr/include:$PATH
PATH=$PATH:$HOME/local/bin

# User specific aliases and functions
alias cmake="cmake3"
alias vim="nvim"
alias vimdiff="nvim -d"
alias ..="cd .."
alias ...="cd ../.."
# alias tshark='tshark --color'
# alias gdb=/opt/rh/devtoolset-7/root/usr/bin/gdb

export CXX=/usr/local/bin/g++

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
alias dotf='/usr/bin/git --git-dir=/Users/linus/repos/dotfiles/ --work-tree=/Users/linus'

eval "$(starship init bash)"
