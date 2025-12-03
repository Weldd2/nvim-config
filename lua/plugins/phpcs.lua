return {
  -- Ajuste des diagnostics null-ls pour ignorer l'erreur TabsUsed
  {
    "nvimtools/none-ls.nvim",
    optional = true,
    opts = function(_, opts)
      local nls = require("null-ls")
      opts.sources = opts.sources or {}

      local phpcs = nls.builtins.diagnostics.phpcs.with({
        extra_args = { "--exclude=Generic.WhiteSpace.DisallowTabIndent" },
      })

      -- Retire la version par défaut pour éviter les doublons
      opts.sources = vim.tbl_filter(function(source)
        return source.name ~= phpcs.name
      end, opts.sources)

      table.insert(opts.sources, phpcs)
    end,
  },

  -- Même configuration côté nvim-lint
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = function()
      local lint = require("lint")
      local phpcs = lint.linters.phpcs
      if not phpcs then
        return
      end

      phpcs.args = {
        "-q",
        "--report=json",
        function()
          return "--stdin-path=" .. vim.fn.expand("%:p:.")
        end,
        "--exclude=Generic.WhiteSpace.DisallowTabIndent",
        "-",
      }
    end,
  },

  -- Active Prettier sur les fichiers PHP via conform
  {
    "stevearc/conform.nvim",
    optional = true,
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      local formatters = vim.deepcopy(opts.formatters_by_ft.php or {})

      if not vim.tbl_contains(formatters, "prettier") then
        table.insert(formatters, 1, "prettier")
      end

      opts.formatters_by_ft.php = formatters
    end,
  },
}

