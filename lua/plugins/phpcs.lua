return {
  -- Ajuste des diagnostics null-ls pour ignorer l'erreur TabsUsed
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}

      local phpcs = nls.builtins.diagnostics.phpcs.with({
        extra_args = { "--exclude=PSR12.Operators.OperatorSpacing" },
      })

      -- Retire la version par défaut pour éviter les doublons
      opts.sources = vim.tbl_filter(function(source)
        return source.name ~= phpcs.name
      end, opts.sources)

      table.insert(opts.sources, phpcs)
    end,
  },

  -- nvim-lint : phpcs + phpstan
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

  -- Active Pint sur les fichiers PHP et Prettier sur Twig via conform
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = {
      formatters_by_ft = {
        php = { "pint" },
        twig = { "prettier" },
      },
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
}

