return {
  {
    "rebelot/kanagawa.nvim",
    opts = {
      overrides = function(colors)
        return {
          -- Couleur de sélection plus visible
          Visual = { bg = colors.palette.waveBlue2 },
        }
      end,
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa",
    },
  },
}
