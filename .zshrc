plugins=(shrink-path)
PATH=/usr/local/opt/llvm/bin:$PATH:$HOME/local/bin

alias q='QHOME=~/q rlwrap -r ~/q/m64/q'
alias developer='source /Users/linus/q_developer/config/config.profile; q /Users/linus/q_developer/launcher.q_ '


autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

# linus@Linuss-MacBook-Air ~/r/vaccipy [master]>
PROMPT='%F{cyan}%n%f@%m %F{yellow}%.%f> '

alias icloud="cd /Users/linus/Library/Mobile\ Documents/com~apple~CloudDocs/"

# export LSCOLORS=ExGxBxDxCxEgEdxbxgxcxd
alias ls='ls -G'
alias ll='ls -lG'
alias ..='cd ..'
alias ...='cd ../..'
alias vim='nvim'
alias vimdiff='nvim -d'


function cr() {
	g++ -Wall \
		-std=c++20 \
		-O1 \
		-fsanitize=address \
		-fno-omit-frame-pointer \
		-fno-sanitize-recover=all \
		-o $1.out $1.cpp &&
		./$1.out
}


# # Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"
# zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
# autoload -Uz compinit && compinit 
# zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

# setopt nocaseglob
# # case insensitive path-completion 
# zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*' 
eval "$(starship init zsh)"

alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'
