-- PHP Configuration: Intelephense + PHPStan
return {
  -- Configure Intelephense LSP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        phpactor = {
          enabled = false,
        },
        intelephense = {
          enabled = true,
          settings = {
            intelephense = {
              files = {
                maxSize = 5000000,
              },
              format = {
                braces = "k&r",
              },
              environment = {
                includePaths = {},
              },
            },
          },
        },
      },
    },
  },

  -- Configure PHPStan linting via nvim-lint
  {
    "mfussenegger/nvim-lint",
    optional = true,
    opts = {
      events = { "BufWritePost" },
      linters_by_ft = {
        php = { "phpstan" },
      },
    },
  },

  -- Ensure required tools are installed
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "intelephense",
        "phpstan",
      },
    },
  },
}
