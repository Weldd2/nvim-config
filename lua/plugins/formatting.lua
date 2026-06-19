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
      -- pint peut être très lent sur de gros fichiers PHP (PatientController…).
      -- => format synchrone court pour tout le monde, mais async pour PHP
      --    afin que `:w` ne bloque jamais l'éditeur.
      format_on_save = function(bufnr)
        if vim.bo[bufnr].filetype == "php" then
          return false
        end
        return { timeout_ms = 1000, lsp_format = "fallback" }
      end,
      format_after_save = function(bufnr)
        if vim.bo[bufnr].filetype ~= "php" then
          return nil
        end
        -- pint tourne ici en arrière-plan (format_after_save = asynchrone),
        -- donc même un gros contrôleur ne bloque jamais l'éditeur. Le
        -- timeout_ms est juste une limite de sécurité, pas une attente : on
        -- le laisse large pour ne plus jamais "timeout" sur les gros fichiers.
        return { timeout_ms = 120000, lsp_format = "fallback" }
      end,
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

  -- Format manuel PHP en asynchrone : pint peut prendre plusieurs secondes
  -- sur les gros contrôleurs. En async, conform ne bloque pas l'éditeur et
  -- `timeout_ms` est ignoré → plus jamais de "Formatter 'pint' timeout".
  -- (mapping bufferlocal => prioritaire sur le <leader>cf global de LazyVim)
  {
    "stevearc/conform.nvim",
    optional = true,
    init = function()
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "php",
        callback = function(ev)
          vim.keymap.set({ "n", "x" }, "<leader>cf", function()
            require("conform").format({ async = true, lsp_format = "fallback", bufnr = ev.buf })
          end, { buffer = ev.buf, desc = "Format (pint, async)" })
        end,
      })
    end,
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
