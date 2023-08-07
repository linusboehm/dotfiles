# manage dotfiles across machines

Based on: [https://www.atlassian.com/git/tutorials/dotfiles](blogpost)

## initial setup

```bash
mkdir -p $HOME/repos
git init --bare $HOME/repos/dotfiles  # bare repo to track dotfiles
alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'  # create alias to mng dotfiles
dotf config --local status.showUntrackedFiles no  # hide files that are not explicitly tracked
# or for zsh
echo "alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'" >> $HOME/.bashrc
```

Now the dotfiles in the home folder can be managed with git using the new `dotf` alias:

```bash
dotf status
dotf add .bashrc
dotf commit -m "added .bashrc"
dotf push
```

## setting up new machine

```bash
mkdir -p $HOME/repos
cd
git clone --bare git@github.com:LMBoehm/dotfiles.git $HOME/repos/dotfiles
alias dotf='/usr/bin/git --git-dir=$HOME/repos/dotfiles/ --work-tree=$HOME'  # create alias to mng dotfiles
dotf config status.showUntrackedFiles no
dotf checkout
if [ $? = 0 ]; then
    echo "checked out dotfiles";
else
    mkdir -p .config_backup
    echo "Backing up previous dotfiles";
    dotf checkout 2>&1 | egrep "\s+\." | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}
fi;
dotf checkout
echo "source $HOME/.bashrc_own" >> $HOME/.bashrc
cd
```
