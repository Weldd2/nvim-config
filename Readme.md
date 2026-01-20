# To install

The first step is to remove the old configuration (optional if you haven't old configuration)

```
# required
mv ~/.config/nvim{,.bak}

# optional but recommended
mv ~/.local/share/nvim{,.bak}
mv ~/.local/state/nvim{,.bak}
mv ~/.cache/nvim{,.bak}
```

Then, clone this repository

```
git clone https://github.com/Weldd2/nvim-config.git ~/.config/nvim
```

Remove the .git folder, so you can add it to your own repo later

```
rm -rf ~/.config/nvim/.git
```

Start neovim !

```
nvim
```

I recommend to read the documentation : `https://www.lazyvim.org/installation`.
