#!/bin/bash

set -euo pipefail
cd "$HOME"

BIN_DIR="$HOME/.local/bin"

ARCH=$(uname -m)
OS=$(uname | tr '[:upper:]' '[:lower:]')

mkdir -p "$BIN_DIR"

if [[ "$ARCH" != "x86_64" ]]; then
  echo "Architecture [$ARCH] not supported"
  exit 1
fi

if [[ "$OS" != "linux" ]]; then
  echo "Platform [$OS] not supported"
  exit 1
fi

function get_latest_from_gh() {
  REPO=${1/\/github.com/\/api.github.com/repos}
  PATTERN=$2
  DESC=$(basename "$REPO")
  echo "Installing $DESC..."
  rm -rf /tmp/setup_artifacts
  mkdir /tmp/setup_artifacts

  # LATEST=$(gh release list --repo "$REPO" --json isLatest,tagName --jq '.[] | select(.isLatest == true) | .tagName')
  # echo "$BINARY: $LATEST"
  # gh release view -R "$REPO"
  # URL=$(gh release view "$LATEST" -R "$REPO" --json assets -q ".assets[] | select(.name | test(\".*$PATTERN.*.tar.gz$\")) | .url")
  # echo "$URL: $LATEST"
  # curl -Ls "$URL" | tar -xz -C "/tmp/setup_artifacts"

  ASSETS=$(curl -s "$REPO/releases/latest" |
    jq -r ".assets[] | select(.name | test(\"$PATTERN\")) | select(.name | test(\"sha256\") | not) | .browser_download_url")
  MATCHES=$(echo "$ASSETS" | wc -l)
  if [[ $MATCHES -ne 1 ]]; then
    echo "expected 1 match for $REPO, found $MATCHES ($ASSETS)... Aborting"
    exit 1
  fi
  curl -Ls "$ASSETS" |
    tar -xz -C "/tmp/setup_artifacts"

  # gh release download -R "$REPO" -D /tmp/setup_artifacts -p "$PATTERN" --clobber
  # rm -rf /tmp/setup_artifacts/*sha256*
  # ARCHIVE=$(ls /tmp/setup_artifacts)
  # tar -xzf /tmp/setup_artifacts/$ARCHIVE -C /tmp/setup_artifacts || echo "couldn't extract: $REPO"
}

function install_latest_from_gh() {
  REPO=$1
  PATTERN=$2
  REPO_DIR=$(basename "$REPO")
  if [[ $# -eq 3 ]]; then
    BINARY=$3
  elif [[ $# -eq 2 ]]; then
    BINARY=$REPO_DIR
  fi
  if [[ ! -e "${BIN_DIR}/${BINARY}" ]]; then
    rm -rf /tmp/setup_artifacts
    get_latest_from_gh "$REPO" "$PATTERN"

    BIN_PATH=$(find /tmp/setup_artifacts -name "$BINARY")
    echo "bin path: $BIN_PATH"
    install "$BIN_PATH" "$BIN_DIR"
    rm -rf /tmp/setup_artifacts
  else
    echo "$BINARY already installed."
  fi
}

# ##### GH
# ##### CURRENTLY NOT NEEDED
# if [[ ! -e "${BIN_DIR}/gh" ]]; then
#   VERSION=2.46.0
#   FOLDER=gh_${VERSION}_${OS}_386
#
#   curl -Ls "https://github.com/cli/cli/releases/download/v${VERSION}/${FOLDER}.tar.gz" | tar -xz "$FOLDER"/bin/gh
#   install "$FOLDER"/bin/gh "$BIN_DIR"
#   rm -rf "$FOLDER"
#   # gh extension install https://www.github.com/dlvhdr/gh-dash
# else
#   echo "gh already installed."
# fi
# ##### END GH

install_latest_from_gh "https://github.com/BurntSushi/ripgrep" "${ARCH}-unknown-${OS}-musl.tar.gz" "rg"
install_latest_from_gh "https://github.com/jesseduffield/lazygit" ".*Linux_${ARCH}.*"
install_latest_from_gh "https://github.com/sharkdp/bat" ".*${ARCH}-unknown-${OS}-gnu.tar.gz"
install_latest_from_gh "https://github.com/sharkdp/fd" ".*-${ARCH}-unknown-${OS}-musl.tar.gz"

# ########################
#### NEOVIM
# NPM required for some linters in nvim
if [[ ! -d "$HOME/.nvm" ]]; then
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
  nvm install node
else
  echo "nvm already installed."
fi

if [[ ! -e ".local/nvim-linux64" ]]; then
  get_latest_from_gh "https://github.com/neovim/neovim" ".*nvim-${OS}64.tar.gz$" "nvim"
  mv /tmp/setup_artifacts/nvim-linux64 "$HOME/.local/"
  rm -rf /tmp/setup_artifacts
else
  echo "nvim already installed."
fi

## CONFIG
if [[ ! -d "$HOME/.config/nvim" ]]; then
  mkdir -p "$HOME/.config"
  git clone https://github.com/linusboehm/lazyvim.git ~/.config/nvim || echo "nvim config already downloaded"
  cd ~
else
  echo "nvim config already installed."
fi

# ########################
#### STARSHIP
if [[ ! -e ".local/bin/starship" ]]; then
  curl -sS https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR"
else
  echo "starship already installed."
fi

# ########################
#### DOTFILES
if [[ ! -d "repos/dotfiles" ]]; then
  shopt -s expand_aliases
  mkdir -p "$HOME/repos"
  git clone --bare https://github.com/linusboehm/dotfiles.git "$HOME/repos/dotfiles" || echo "already downloaded repo"
  function dotf() {
    /usr/bin/git --git-dir="$HOME"/repos/dotfiles/ --work-tree="$HOME" "$@" # create alias to mng dotfiles
  }
  dotf config status.showUntrackedFiles no
  set +e
  dotf checkout
  RET_CODE=$?
  set -e
  if [ "$RET_CODE" = 0 ]; then
    echo "checked out dotfiles"
  else
    mkdir -p .config_backup
    echo "Backing up previous dotfiles"
    dotf checkout 2>&1 | grep -E "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config_backup/{}
  fi
  dotf checkout
  echo "source $HOME/.bashrc_own.sh" >>"$HOME"/.bashrc
  cd
else
  echo "dotfiles already installed."
fi

# ########################
### FZF
if [[ ! -e ".fzf/bin/fzf" ]]; then
  git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
  ~/.fzf/install
else
  echo "fzf already installed."
fi

# ########################
### TMUX PLUGINS
if [[ ! -d ".tmux/plugins/tpm" ]]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
else
  echo "tpm already installed."
fi

if [[ ! -e ".cargo/bin/cargo" ]]; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
else
  echo "cargo already installed."
fi
