-- Conditional PHP + Vue/TypeScript Formatter Configuration
return {
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      -- Helper function to check for Prettier config with PHP support
      local function has_prettier_with_php(ctx)
        local prettier_configs = {
          ".prettierrc",
          ".prettierrc.json",
          ".prettierrc.yml",
          ".prettierrc.yaml",
          ".prettierrc.js",
          "prettier.config.js",
          "prettier.config.cjs",
        }

        local config_file = vim.fs.find(prettier_configs, { path = ctx.filename, upward = true })[1]

        if not config_file then
          return false
        end

        -- For JSON files, parse and check for PHP plugin
        if config_file:match("%.json$") or config_file == ".prettierrc" then
          local f = io.open(config_file, "r")
          if f then
            local content = f:read("*all")
            f:close()

            local ok, config = pcall(vim.json.decode, content)
            if ok and config then
              if config.plugins then
                for _, plugin in ipairs(config.plugins) do
                  if type(plugin) == "string" and plugin:match("php") then
                    return true
                  end
                end
              end

              if config.phpVersion or config.trailingCommaPHP or config.braceStyle then
                return true
              end
            end
          end
        end

        -- For YAML/JS files, do a simple string match
        local f = io.open(config_file, "r")
        if f then
          local content = f:read("*all")
          f:close()

          if content:match("plugin%-php") or content:match("phpVersion") or content:match("trailingCommaPHP") then
            return true
          end
        end

        return false
      end

      -- Configure formatters by filetype
      opts.formatters_by_ft = opts.formatters_by_ft or {}

      -- PHP: conditional formatting
      opts.formatters_by_ft.php = function(bufnr)
        local ctx = { filename = vim.api.nvim_buf_get_name(bufnr) }

        if has_prettier_with_php(ctx) then
          return { "prettier" }
        else
          return { "php_cs_fixer" }
        end
      end

      -- ✅ Vue: Prettier formatting
      opts.formatters_by_ft.vue = { "prettier" }

      -- ✅ TypeScript/JavaScript: Prettier formatting
      opts.formatters_by_ft.javascript = { "prettier" }
      opts.formatters_by_ft.javascriptreact = { "prettier" }
      opts.formatters_by_ft.typescript = { "prettier" }
      opts.formatters_by_ft.typescriptreact = { "prettier" }

      -- ✅ CSS/HTML/JSON: Prettier formatting
      opts.formatters_by_ft.css = { "prettier" }
      opts.formatters_by_ft.scss = { "prettier" }
      opts.formatters_by_ft.html = { "prettier" }
      opts.formatters_by_ft.json = { "prettier" }
      opts.formatters_by_ft.jsonc = { "prettier" }
      opts.formatters_by_ft.yaml = { "prettier" }
      opts.formatters_by_ft.markdown = { "prettier" }

      -- Configure formatter options
      opts.formatters = opts.formatters or {}

      opts.formatters.php_cs_fixer = {
        command = "php-cs-fixer",
        args = {
          "fix",
          "$FILENAME",
          "--allow-risky=yes",
        },
        stdin = false,
        cwd = require("conform.util").root_file({
          ".php-cs-fixer.php",
          ".php-cs-fixer.dist.php",
          "composer.json",
        }),
      }

      -- ✅ Prettier: support Vue, TypeScript, etc.
      opts.formatters.prettier = {
        command = "prettier",
        args = { "--stdin-filepath", "$FILENAME" },
        -- Prettier détecte automatiquement le parser basé sur l'extension du fichier
      }

      return opts
    end,
  },

  -- Ensure formatters are installed
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        "prettier",
        "php-cs-fixer",
      },
    },
  },
}
