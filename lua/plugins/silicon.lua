local langs = {
  "javascript",
  "typescript",
  "bash",
  "php",
  "lua",
  "markdown",
  "json",
  "yaml",
  "sql",
  "html",
  "css",
  "scss",
  "python",
  "rust",
  "go",
  "ruby",
  "java",
  "c",
  "cpp",
  "swift",
  "kotlin",
  "scala",
  "haskell",
  "elixir",
  "clojure",
  "vim",
  "toml",
  "dockerfile",
  "makefile",
  "graphql",
  "vue",
  "svelte",
  "tsx",
  "jsx",
}

-- Mapping vim filetype -> silicon language (quand différent)
local filetype_map = {
  javascriptreact = "jsx",
  typescriptreact = "tsx",
  sh = "bash",
  zsh = "bash",
  fish = "bash",
  dockerfile = "dockerfile",
  make = "makefile",
  ["yaml.docker-compose"] = "yaml",
  twig = "html",
  blade = "html",
}

-- Récupère le langage silicon depuis le filetype vim
local function get_silicon_lang()
  local ft = vim.bo.filetype
  return filetype_map[ft] or ft
end

-- Ouvre une fenêtre flottante pour coller du code
local function open_paste_window(callback)
  local buf = vim.api.nvim_create_buf(false, true)
  local width = math.floor(vim.o.columns * 0.7)
  local height = math.floor(vim.o.lines * 0.6)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Paste code, then <leader>Z to screenshot ",
    title_pos = "center",
  })

  -- Keymap pour capturer le code
  vim.keymap.set("n", "<leader>Z", function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    vim.api.nvim_win_close(win, true)
    callback(lines)
  end, { buffer = buf, desc = "Capture pasted code" })

  -- Fermer avec q ou Escape
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  -- Passer en mode insert pour coller facilement
  vim.cmd("startinsert")
end

-- Génère le screenshot avec le code donné
local function screenshot_with_lang(lines, lang)
  -- Créer un buffer temporaire avec le code
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_option_value("filetype", lang, { buf = buf })

  -- Ouvrir le buffer temporairement, sélectionner tout, screenshot
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  -- Sélectionner tout le contenu
  vim.cmd("normal! ggVG")

  -- Screenshot
  local silicon = require("nvim-silicon")
  local opts = vim.tbl_deep_extend("force", silicon.options, { language = lang })
  silicon.shoot(opts)

  -- Fermer le buffer après un délai
  vim.defer_fn(function()
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end, 100)
end

return {
  "michaelrommel/nvim-silicon",
  lazy = true,
  cmd = "Silicon",
  keys = {
    -- Mode visuel : screenshot direct avec langage du buffer
    {
      "<leader>z",
      function()
        local silicon = require("nvim-silicon")
        local lang = get_silicon_lang()
        local opts = vim.tbl_deep_extend("force", silicon.options, { language = lang })
        silicon.shoot(opts)
      end,
      mode = "v",
      desc = "Screenshot code",
    },
    -- Mode visuel : screenshot avec choix du langage
    {
      "<leader>Z",
      function()
        vim.ui.select(langs, { prompt = "Language: " }, function(choice)
          if choice then
            local silicon = require("nvim-silicon")
            local opts = vim.tbl_deep_extend("force", silicon.options, { language = choice })
            silicon.shoot(opts)
          end
        end)
      end,
      mode = "v",
      desc = "Screenshot code (select lang)",
    },
    -- Mode normal : ouvre une fenêtre pour coller du code
    {
      "<leader>Z",
      function()
        open_paste_window(function(lines)
          if #lines == 0 or (#lines == 1 and lines[1] == "") then
            vim.notify("No code to screenshot", vim.log.levels.WARN)
            return
          end
          vim.ui.select(langs, { prompt = "Language: " }, function(choice)
            if choice then
              screenshot_with_lang(lines, choice)
              vim.notify("✓ Screenshot copied to clipboard!", vim.log.levels.INFO)
            end
          end)
        end)
      end,
      mode = "n",
      desc = "Screenshot pasted code",
    },
  },
  config = function()
    require("nvim-silicon").setup({
      font = "JetBrainsMono Nerd Font=34",
      theme = "Dracula",
      to_clipboard = true,
      no_window_controls = true,
      pad_horiz = 80,
      pad_vert = 100,
    })
  end,
}
