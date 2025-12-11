-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Tools Group
map("n", "<leader>tg", function()
  Snacks.lazygit()
end, { desc = "LazyGit" })
map("n", "<leader>td", function()
  Snacks.terminal("lazydocker")
end, { desc = "LazyDocker" })
map("n", "<leader>tp", function()
  Snacks.terminal("posting")
end, { desc = "Posting (HTTP)" })
map("n", "<leader>tm", function()
  Snacks.terminal("tttui")
end, { desc = "Monkeytype" })

-- Lazy Group
-- Remove default mappings to avoid conflicts/delays
pcall(vim.keymap.del, "n", "<leader>l")
pcall(vim.keymap.del, "n", "<leader>L")

map("n", "<leader>ll", "<cmd>Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>le", "<cmd>LazyExtras<cr>", { desc = "Lazy Extras" })
map("n", "<leader>lL", function()
  LazyVim.news.changelog()
end, { desc = "LazyVim Changelog" })
