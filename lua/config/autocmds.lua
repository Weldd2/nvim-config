-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Fix WhichKey group underline (remove diagnostic style blue underline)
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    vim.api.nvim_set_hl(0, "WhichKeyGroup", { link = "Keyword", underline = false })
  end,
})

-- Indentation par filetype
-- PHP/Twig : tabs (Pint/Prettier use tabs)
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "php", "twig" },
  callback = function()
    vim.bo.expandtab = false
    vim.bo.tabstop = 4
    vim.bo.shiftwidth = 4
    vim.bo.softtabstop = 4
  end,
})
-- JS/TS/Vue/CSS/HTML/JSON/YAML/Lua/Markdown : 2 espaces
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "javascript", "typescript", "vue", "css", "scss", "html", "json", "yaml", "lua", "markdown" },
  callback = function()
    vim.bo.expandtab = true
    vim.bo.tabstop = 2
    vim.bo.shiftwidth = 2
    vim.bo.softtabstop = 2
  end,
})

-- Détection des fichiers .ftl avec support HTML + FTL
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  pattern = { "*.ftl", "*.ftlh", "*.ftlx" },
  callback = function()
    vim.bo.filetype = "ftl"
  end,
})
