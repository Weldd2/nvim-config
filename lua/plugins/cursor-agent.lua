-- Intégration Cursor CLI : buffer listé, keymaps lazy, bufferline.
return {
  {
    "folke/snacks.nvim",
    keys = {
      { "<leader>a", "", desc = "+cursor", mode = { "n", "v" } },
      {
        "<leader>bc",
        function()
          require("cursor_agent").open()
        end,
        desc = "Cursor : ouvrir / focus buffer",
      },
      {
        "<leader>an",
        function()
          require("cursor_agent").new_chat()
        end,
        desc = "Cursor : nouveau chat",
      },
      {
        "<leader>as",
        function()
          require("cursor_agent").send_context()
        end,
        mode = { "n", "x" },
        desc = "Cursor : envoyer fichier / sélection",
      },
      {
        "<leader>ax",
        function()
          require("cursor_agent").interrupt()
        end,
        desc = "Cursor : interrompre",
      },
      {
        "<leader>ah",
        function()
          require("cursor_agent").history()
        end,
        desc = "Cursor : conversations",
      },
    },
  },
  {
    "akinsho/bufferline.nvim",
    optional = true,
    opts = {
      options = {
        name_formatter = function(buf)
          local ok, ft = pcall(function()
            return vim.bo[buf.bufnr].filetype
          end)
          if ok and ft == "cursor_agent" then
            return "Cursor"
          end
        end,
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      icons = {
        ft = {
          cursor_agent = "󰚩 ",
        },
      },
    },
  },
}
