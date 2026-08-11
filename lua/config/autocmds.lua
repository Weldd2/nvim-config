-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- PHP : pint peut prendre plusieurs secondes sur les gros contrôleurs.
-- On désactive donc le format-on-save synchrone de LazyVim pour les buffers PHP
-- (sinon `:w` bloque l'éditeur), et on fournit un format manuel asynchrone via
-- <leader>cf. IMPORTANT : ce keymap doit vivre dans un autocmd ici, et surtout
-- PAS dans un `init` du spec conform.nvim, sinon il écrase le `init` du core
-- LazyVim qui enregistre le formateur conform (→ plus aucun prettier au save).
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("php_async_format", { clear = true }),
  pattern = "php",
  callback = function(ev)
    vim.b[ev.buf].autoformat = false
    vim.keymap.set({ "n", "x" }, "<leader>cf", function()
      require("conform").format({ async = true, lsp_format = "fallback", bufnr = ev.buf })
    end, { buffer = ev.buf, desc = "Format (pint, async)" })

    -- Configuration de l'indentation pour PHP (4 espaces)
    vim.bo[ev.buf].expandtab = true     -- Utiliser des espaces au lieu de tabs
    vim.bo[ev.buf].shiftwidth = 4       -- Largeur de l'indentation automatique
    vim.bo[ev.buf].tabstop = 4          -- Largeur d'affichage d'un caractère tab
    vim.bo[ev.buf].softtabstop = 4      -- Nombre d'espaces lors de l'appui sur Tab
  end,
})

-- Afficher les whitespaces lors de la sélection en mode visuel
vim.api.nvim_create_autocmd("ModeChanged", {
  group = vim.api.nvim_create_augroup("visual_whitespace", { clear = true }),
  pattern = "*:[vV\x16]*", -- Entre en mode visuel (v, V, ou Ctrl-V)
  callback = function()
    vim.opt_local.list = true
    vim.opt_local.listchars = { space = "·", tab = "→ ", trail = "·", nbsp = "␣" }
  end,
})

vim.api.nvim_create_autocmd("ModeChanged", {
  group = vim.api.nvim_create_augroup("visual_whitespace", { clear = false }),
  pattern = "[vV\x16]*:*", -- Sort du mode visuel
  callback = function()
    vim.opt_local.list = false
  end,
})

