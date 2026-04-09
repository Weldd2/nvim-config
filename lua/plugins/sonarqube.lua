return {
  {
    "iamkarasik/sonarqube.nvim",
    config = function()
      local java_path = "/opt/homebrew/opt/openjdk/bin/java"

      -- Use plugin's own install path (via :SonarQubeInstallLsp)
      -- Falls back to Mason path if present
      local data_dir = vim.fn.stdpath("data")
      local plugin_ext = data_dir .. "/sonarqube/extension"
      local mason_ext = data_dir .. "/mason/packages/sonarlint-language-server/extension"

      local extension_path = plugin_ext
      if vim.fn.isdirectory(plugin_ext) == 0 and vim.fn.isdirectory(mason_ext) == 1 then
        extension_path = mason_ext
      end

      local jar_path = extension_path .. "/server/sonarlint-ls.jar"
      if vim.fn.filereadable(jar_path) == 0 then
        vim.notify(
          "SonarLint LSP not found. Run :SonarQubeInstallLsp to install it.",
          vim.log.levels.WARN
        )
      end

      require("sonarqube").setup({
        lsp = {
          cmd = {
            java_path,
            "-jar",
            jar_path,
            "-stdio",
            "-analyzers",
            extension_path .. "/analyzers/sonarhtml.jar",
            extension_path .. "/analyzers/sonariac.jar",
            extension_path .. "/analyzers/sonarjs.jar",
            extension_path .. "/analyzers/sonarphp.jar",
            extension_path .. "/analyzers/sonartext.jar",
            extension_path .. "/analyzers/sonarxml.jar",
          },
          log_level = "OFF",
          handlers = {
            ["sonarlint/showRuleDescription"] = function(_, res, _, _)
              local uri = "https://rules.sonarsource.com/%s/RSPEC-%s"
              local lang = res.languageKey
              local spec = string.match(res.key, "S(%d+)")
              vim.ui.open(string.format(uri, lang, spec))
            end,
          },
        },
        rules = { enabled = true },
        html = { enabled = true },
        iac = { enabled = true },
        javascript = {
          enabled = true,
          clientNodePath = vim.fn.exepath("node"),
        },
        php = { enabled = true },
        text = { enabled = true },
        xml = { enabled = true },
        csharp = { enabled = false },
        go = { enabled = false },
        java = { enabled = false },
        python = { enabled = false },
      })

      -- Connected Mode: sync rules & quality profile from SonarQube
      vim.api.nvim_create_autocmd("LspAttach", {
        pattern = "*",
        callback = function(args)
          local client = vim.lsp.get_client_by_id(args.data.client_id)
          if client and client.name == "sonarqube" then
            client.notify("workspace/didChangeConfiguration", {
              settings = {
                sonarlint = {
                  connectedMode = {
                    connections = {
                      sonarqube = {
                        {
                          connectionId = "cegedim-sonarqube",
                          serverUrl = "https://sonarqube.cegedim-sante.com",
                          token = vim.env.SONARQUBE_TOKEN,
                        },
                      },
                    },
                    project = {
                      connectionId = "cegedim-sonarqube",
                      projectKey = "maiia-medecin_web_mediweb_AZWAeIa726Ufn5yFJDDE",
                    },
                  },
                },
              },
            })
            return true
          end
        end,
      })
    end,
  },
}
