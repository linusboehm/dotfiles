#!/bin/bash

set -euo pipefail
cd ~

BIN_DIR=".local/bin"

ARCH=$(uname -m)
OS=$(uname)

mkdir -p $BIN_DIR

if [[ "$OS" == "Linux" ]]; then
	PLATFORM="linux"
	if [[ "$ARCH" == "aarch64" ]]; then
		ARCH="aarch64";
	elif [[ $ARCH == "ppc64le" ]]; then
		ARCH="ppc64le";
	else
		ARCH="64";
	fi
else
	echo "Platform not supported"
	exit 1
fi

##### NPM
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
nvm install node
##### END NPM

##### RIGREP
if [[ ! -e "${BIN_DIR}/rg" ]]; then
    RIGREP_VERSION=ripgrep-14.1.0-x86_64-unknown-linux-musl
    curl -Ls "https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/${RIGREP_VERSION}.tar.gz" | tar -xz ${RIGREP_VERSION}/rg
    install ${RIGREP_VERSION}/rg $BIN_DIR
    rm -rf ${RIGREP_VERSION}
else
    echo "rg already installed."
fi
##### END RIGREP

##### LAZYGIT
if [[ ! -e "${BIN_DIR}/lazygit" ]]; then
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    LAZYGIT_ARCHIVE=lazygit_${LAZYGIT_VERSION}_${OS}_x86_${ARCH}.tar.gz
    curl -Ls "https://github.com/jesseduffield/lazygit/releases/latest/download/${LAZYGIT_ARCHIVE}" | tar -xz lazygit
    install lazygit $BIN_DIR/lazygit
    rm lazygit
else
    echo "rg already installed."
fi
##### END LAZYGIT

#### NEOVIM
if [[ ! -e ".local/nvim-linux64" ]]; then
    NVIM_ARCHIVE=nvim-${PLATFORM}${ARCH}.tar.gz
    URL=https://github.com/neovim/neovim/releases/latest/download/$NVIM_ARCHIVE
    echo "getting nvim from: $URL"
    curl -Ls $URL | tar -C ~/.local -xz
else
    echo "nvim already installed."
fi
#### END NEOVIM

## CONFIG
if [[ ! -d "~/.config/nvim" ]]; then
    mkdir -p ~/.config
    cd ~/.config
    git clone git@github.com:linusboehm/neovim.git nvim || echo "nvim config already downloaded"
    cd ~
else
    echo "nvim config already downloaded."
fi
###### END NEOVIM

#### STARSHIP
if [[ ! -e ".local/bin/starship" ]]; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y -b $BIN_DIR
else
    echo "starship already downloaded."
fi
#### END STARSHIP

#### DOTFILES
if [[ ! -d "repos/dotfiles" ]]; then
    shopt -s expand_aliases
    mkdir -p $HOME/repos
    git clone --bare git@github.com:LMBoehm/dotfiles.git $HOME/repos/dotfiles || echo "already downloaded repo"
    alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'  # create alias to mng dotfiles
    dotf config status.showUntrackedFiles no
    dotf checkout
    if [ $? = 0 ]; then
        echo "checked out dotfiles";
    else
        mkdir -p .config_backup
        echo "Backing up previous dotfiles";
        dotf checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config_backup/{}
    fi;
    dotf checkout
    echo "source $HOME/.bashrc_own.sh" >> $HOME/.bashrc
    cd
else
    echo "dotfiles already downloaded."
fi
#### END DOTFILES

### FZF
git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
~/.fzf/install
### END FZF

### TMUX PLUGINS
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
### END TMUX PLUGINS

##### BAT
if [[ ! -e "${BIN_DIR}/bat" ]]; then
    BAT_VERSION=v0.24.0
    BAT_FOLDER=bat-${BAT_VERSION}-x86_64-unknown-linux-gnu

    curl -Ls "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/${BAT_FOLDER}.tar.gz" | tar -xz ${BAT_FOLDER}/bat
    install $BAT_FOLDER/bat $BIN_DIR
    rm -rf $BAT_FOLDER

else
    echo "bat already installed."
fi
##### END BAT

##### FD
if [[ ! -e "${BIN_DIR}/fd" ]]; then
    FD_VERSION=v9.0.0
    FD_FOLDER=fd-${FD_VERSION}-x86_64-unknown-linux-musl
    
    # wget "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/${FD_FOLDER}.tar.gz"
    curl -Ls "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/${FD_FOLDER}.tar.gz" | tar -xz ${FD_FOLDER}/fd
    install $FD_FOLDER/fd $BIN_DIR
    rm -rf $FD_FOLDER
else
    echo "fd already installed."
fi
##### END FD
