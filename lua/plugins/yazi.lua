-- Yazi File Explorer Configuration
return {
	-- Disable Snacks Explorer
	{
		"folke/snacks.nvim",
		opts = {
			explorer = { enabled = false },
		},
		keys = {
			{ "<leader>fe", false },
			{ "<leader>fE", false },
			{ "<leader>e", false },
			{ "<leader>E", false },
		},
	},

	-- Configure Yazi
	{
		"mikavilpas/yazi.nvim",
		version = "*",
		event = "VeryLazy",
		dependencies = {
			{ "nvim-lua/plenary.nvim", lazy = true },
		},
		keys = {
			{
				"<leader>E",
				mode = { "n", "v" },
				"<cmd>Yazi<cr>",
				desc = "Open yazi at the current file",
			},
			{
				"<leader>e",
				"<cmd>Yazi cwd<cr>",
				desc = "Open the file manager in nvim's working directory",
			},
			{
				"<leader>fe",
				"<cmd>Yazi<cr>",
				desc = "Explorer Yazi (root dir)",
			},
			{
				"<leader>fE",
				"<cmd>Yazi cwd<cr>",
				desc = "Explorer Yazi (cwd)",
			},
			{
				"<c-up>",
				"<cmd>Yazi toggle<cr>",
				desc = "Resume the last yazi session",
			},
		},
		opts = {
			-- ✅ Ouvre Yazi automatiquement quand on lance nvim avec un dossier
			open_for_directories = true,
			floating_window_scaling_factor = 0.9,
			yazi_floating_window_winblend = 0,
			yazi_floating_window_border = "rounded",
			keymaps = {
				show_help = "<f1>",
				open_file_in_vertical_split = "<c-v>",
				open_file_in_horizontal_split = "<c-x>",
				open_file_in_tab = "<c-t>",
				grep_in_directory = "<c-s>",
				replace_in_directory = "<c-g>",
				cycle_open_buffers = "<tab>",
				copy_relative_path_to_selected_files = "<c-y>",
				send_to_quickfix_list = "<c-q>",
				change_working_directory = "<c-\\>",
				open_and_pick_window = "<c-o>",
			},
			log_level = vim.log.levels.OFF,
		},
	},
}
