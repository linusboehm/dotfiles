install neovim by cloning and

```bash
git clone https://github.com/neovim/neovim
cd neovim/
make CMAKE_EXTRA_FLAGS="-DCMAKE_INSTALL_PREFIX=$HOME/.local/neovim" CMAKE_BUILD_TYPE=Release
make install
```
