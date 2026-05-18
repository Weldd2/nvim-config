-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.tabstop = 8
vim.opt.shiftwidth = 8
vim.opt.softtabstop = 0

if vim.g.neovide then
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"
end
