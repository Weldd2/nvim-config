return {
  -- Mason : s'assurer que eslint_d est installé
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = { "eslint_d" },
    },
  },

  -- nvim-lint : phpcs + phpstan pour PHP
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      linters_by_ft = {
        php = { "phpcs", "phpstan" },
      },
      linters = {
        phpcs = {
          args = {
            "-q",
            "--report=json",
            function()
              return "--stdin-path=" .. vim.fn.expand("%:p:.")
            end,
            "--exclude=PSR12.Operators.OperatorSpacing",
            "-",
          },
        },
        phpstan = {
          args = {
            "analyze",
            "--error-format=json",
            "--no-progress",
            "--memory-limit=512M",
          },
        },
      },
    },
  },

  -- conform : eslint_d + prettier sur JS/TS/Vue, pint sur PHP
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        php = { "pint" },
        twig = { "prettier" },
        vue = { "eslint_d", "prettier" },
        javascript = { "eslint_d", "prettier" },
        javascriptreact = { "eslint_d", "prettier" },
        typescript = { "eslint_d", "prettier" },
        typescriptreact = { "eslint_d", "prettier" },
      },
      -- NB : ne PAS définir `format_on_save` / `format_after_save` ici.
      -- LazyVim les supprime (warning) et pilote lui-même le format au save
      -- via son autocmd. Le cas PHP (lent, non bloquant) est géré dans
      -- lua/config/autocmds.lua (autoformat désactivé + <leader>cf async).
      formatters = {
        pint = {
          prepend_args = function()
            local local_pint = vim.fn.getcwd() .. "/vendor/bin/pint"
            if vim.fn.executable(local_pint) == 1 then
              return { "--config", vim.fn.getcwd() .. "/pint.json" }
            end
            return {}
          end,
        },
      },
    },
  },

  -- Désactiver le formateur ESLint LSP de l'extra linting.eslint
  -- (on utilise eslint_d via conform à la place)
  {
    "neovim/nvim-lspconfig",
    opts = {
      setup = {
        eslint = function()
          -- Le LSP ESLint reste actif pour les diagnostics,
          -- mais on ne l'enregistre pas comme formateur LazyVim.
          -- Le fix est géré par eslint_d dans conform.
        end,
      },
    },
  },
}
