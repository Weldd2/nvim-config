-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- Tools Group
map("n", "<leader>tg", function()
  Snacks.lazygit()
end, { desc = "LazyGit" })
map("n", "<leader>td", function()
  Snacks.terminal("lazydocker")
end, { desc = "LazyDocker" })
map("n", "<leader>tp", function()
  Snacks.terminal("posting")
end, { desc = "Posting (HTTP)" })
map("n", "<leader>tm", function()
  Snacks.terminal("tttui")
end, { desc = "Monkeytype" })

-- NPM Scripts Manager - Auto-detect from package.json with smart keybindings
local npm = {
  jobs = {}, -- { script_name = { job_id, log_file } }
  log_dir = vim.fn.stdpath("cache") .. "/npm_logs",
  keymaps_set = false,
  last_cwd = nil,

  -- Explicit key mappings for common scripts (stable, name-based)
  -- These take priority and never change
  explicit_keys = {
    dev = "d",
    build = "b",
    start = "s",
    test = "t",
    lint = "l",
    format = "f",
    preview = "p",
    serve = "S",
    watch = "w",
    clean = "c",
    install = "i",
    typecheck = "T",
  },

  -- Reserved keys for utility functions
  reserved_keys = {
    r = true, -- Run picker
    q = true, -- Stop picker
    Q = true, -- Stop all
    ["?"] = true, -- Status/help
    L = true, -- Logs
  },
}

vim.fn.mkdir(npm.log_dir, "p")

local function find_package_json()
  local path = vim.fn.getcwd()
  while path ~= "/" do
    local pkg = path .. "/package.json"
    if vim.fn.filereadable(pkg) == 1 then
      return pkg, path
    end
    path = vim.fn.fnamemodify(path, ":h")
  end
  return nil, nil
end

local function get_npm_scripts()
  local pkg_path, cwd = find_package_json()
  if not pkg_path then
    return nil, nil
  end

  local content = vim.fn.readfile(pkg_path)
  local ok, json = pcall(vim.fn.json_decode, table.concat(content, "\n"))
  if ok and json and json.scripts then
    return json.scripts, cwd
  end
  return nil, cwd
end

local function is_running(script_name)
  local job = npm.jobs[script_name]
  return job and job.job_id and vim.fn.jobwait({ job.job_id }, 0)[1] == -1
end

local function npm_start(script_name, cwd)
  if is_running(script_name) then
    vim.notify("'" .. script_name .. "' already running", vim.log.levels.WARN)
    return
  end

  local log_file = npm.log_dir .. "/" .. script_name:gsub("[^%w]", "_") .. ".log"
  vim.fn.writefile({}, log_file)

  local job_id = vim.fn.jobstart({ "npm", "run", script_name }, {
    cwd = cwd,
    env = { CI = "true", NO_COLOR = "1", FORCE_COLOR = "0" },
    on_stdout = function(_, data)
      if data then
        vim.fn.writefile(data, log_file, "a")
      end
    end,
    on_stderr = function(_, data)
      if data then
        vim.fn.writefile(data, log_file, "a")
      end
    end,
    on_exit = function(_, code)
      vim.schedule(function()
        vim.notify("'" .. script_name .. "' exited (code: " .. code .. ")", vim.log.levels.INFO)
      end)
      npm.jobs[script_name] = nil
    end,
  })

  if job_id > 0 then
    npm.jobs[script_name] = { job_id = job_id, log_file = log_file, cwd = cwd }
    vim.notify("Started '" .. script_name .. "'", vim.log.levels.INFO)
  else
    vim.notify("Failed to start '" .. script_name .. "'", vim.log.levels.ERROR)
  end
end

local function npm_stop(script_name)
  if is_running(script_name) then
    vim.fn.jobstop(npm.jobs[script_name].job_id)
    vim.notify("Stopped '" .. script_name .. "'", vim.log.levels.INFO)
    npm.jobs[script_name] = nil
  else
    vim.notify("'" .. script_name .. "' not running", vim.log.levels.WARN)
  end
end

-- Smart key generation based on script name (deterministic, not order-based)
local function generate_smart_key(script_name, used_keys)
  -- 1. Check explicit mapping first
  if npm.explicit_keys[script_name] and not used_keys[npm.explicit_keys[script_name]] then
    return npm.explicit_keys[script_name]
  end

  -- 2. For scripts with prefix (build-dev, lint:fix), use suffix
  local prefix, suffix = script_name:match("^(%w+)[%-%:](.+)$")
  if suffix then
    -- Try first letter of suffix (lowercase)
    local key = suffix:sub(1, 1):lower()
    if not used_keys[key] and not npm.reserved_keys[key] then
      return key
    end
    -- Try uppercase
    key = suffix:sub(1, 1):upper()
    if not used_keys[key] and not npm.reserved_keys[key] then
      return key
    end
    -- Try last meaningful part (e.g., "fix" from "lint:fix")
    local last_part = suffix:match(".*[%-%:]?(%w+)$") or suffix
    key = last_part:sub(1, 1):lower()
    if not used_keys[key] and not npm.reserved_keys[key] then
      return key
    end
  end

  -- 3. Try first letter of script name
  local key = script_name:sub(1, 1):lower()
  if not used_keys[key] and not npm.reserved_keys[key] then
    return key
  end

  -- 4. Try uppercase first letter
  key = script_name:sub(1, 1):upper()
  if not used_keys[key] and not npm.reserved_keys[key] then
    return key
  end

  -- 5. Try each letter in the script name
  for i = 2, #script_name do
    local char = script_name:sub(i, i)
    if char:match("%a") then
      key = char:lower()
      if not used_keys[key] and not npm.reserved_keys[key] then
        return key
      end
      key = char:upper()
      if not used_keys[key] and not npm.reserved_keys[key] then
        return key
      end
    end
  end

  -- 6. Fallback to numbers
  for i = 1, 9 do
    key = tostring(i)
    if not used_keys[key] then
      return key
    end
  end

  return nil
end

-- Generate all keymaps for scripts
local function generate_script_keymaps(scripts)
  local keymaps = {}
  local used_keys = {}

  -- Copy reserved keys
  for k, _ in pairs(npm.reserved_keys) do
    used_keys[k] = true
  end

  -- Sort scripts by priority: explicit mappings first, then alphabetically
  local sorted_scripts = {}
  for name, cmd in pairs(scripts) do
    table.insert(sorted_scripts, { name = name, cmd = cmd })
  end
  table.sort(sorted_scripts, function(a, b)
    local a_explicit = npm.explicit_keys[a.name] and 0 or 1
    local b_explicit = npm.explicit_keys[b.name] and 0 or 1
    if a_explicit ~= b_explicit then
      return a_explicit < b_explicit
    end
    return a.name < b.name
  end)

  for _, script in ipairs(sorted_scripts) do
    local key = generate_smart_key(script.name, used_keys)
    if key then
      used_keys[key] = true
      keymaps[key] = { name = script.name, cmd = script.cmd }
    end
  end

  return keymaps
end

-- Clear dynamic keymaps
local function clear_npm_keymaps()
  -- Get all keymaps starting with <leader>tn
  local maps = vim.api.nvim_get_keymap("n")
  for _, m in ipairs(maps) do
    if m.lhs:match("^<leader>tn.") and not npm.reserved_keys[m.lhs:sub(-1)] then
      pcall(vim.keymap.del, "n", m.lhs)
    end
  end
end

-- Setup dynamic keymaps based on current package.json
local function setup_npm_keymaps()
  local scripts, cwd = get_npm_scripts()
  if not scripts then
    return
  end

  -- Only refresh if cwd changed
  if npm.last_cwd == cwd and npm.keymaps_set then
    return
  end

  clear_npm_keymaps()

  local keymaps = generate_script_keymaps(scripts)

  for key, script in pairs(keymaps) do
    local lhs = "<leader>tn" .. key
    map("n", lhs, function()
      npm_start(script.name, cwd)
    end, { desc = script.name })
  end

  npm.keymaps_set = true
  npm.last_cwd = cwd
end

-- Picker: select a script to run
local function npm_run_picker()
  local scripts, cwd = get_npm_scripts()
  if not scripts then
    vim.notify("No package.json found", vim.log.levels.ERROR)
    return
  end

  local keymaps = generate_script_keymaps(scripts)
  local items = {}

  for key, script in pairs(keymaps) do
    local status = is_running(script.name) and "● " or "  "
    table.insert(items, {
      name = script.name,
      cmd = script.cmd,
      key = key,
      status = status,
    })
  end

  table.sort(items, function(a, b)
    return a.name < b.name
  end)

  vim.ui.select(items, {
    prompt = "NPM Scripts (<leader>tn + key)",
    format_item = function(item)
      return item.status .. "[" .. item.key .. "] " .. item.name .. " → " .. item.cmd
    end,
  }, function(choice)
    if choice then
      npm_start(choice.name, cwd)
    end
  end)
end

local function npm_stop_picker()
  local running = {}
  for name, job in pairs(npm.jobs) do
    if is_running(name) then
      table.insert(running, { name = name, job_id = job.job_id })
    end
  end

  if #running == 0 then
    vim.notify("No scripts running", vim.log.levels.WARN)
    return
  end

  vim.ui.select(running, {
    prompt = "Stop NPM Script",
    format_item = function(item)
      return item.name .. " (job: " .. item.job_id .. ")"
    end,
  }, function(choice)
    if choice then
      npm_stop(choice.name)
    end
  end)
end

local function npm_status()
  local scripts, cwd = get_npm_scripts()
  local keymaps = scripts and generate_script_keymaps(scripts) or {}

  local lines = { "NPM Scripts (<leader>tn + key):", "" }

  -- Show running scripts first
  local running = {}
  for name, job in pairs(npm.jobs) do
    if is_running(name) then
      table.insert(running, name)
    end
  end

  if #running > 0 then
    table.insert(lines, "Running:")
    for _, name in ipairs(running) do
      table.insert(lines, "  ● " .. name)
    end
    table.insert(lines, "")
  end

  -- Show available keymaps
  table.insert(lines, "Keymaps:")
  local sorted = {}
  for key, script in pairs(keymaps) do
    table.insert(sorted, { key = key, name = script.name })
  end
  table.sort(sorted, function(a, b)
    return a.key < b.key
  end)

  for _, item in ipairs(sorted) do
    local status = is_running(item.name) and "●" or " "
    table.insert(lines, "  " .. status .. " [" .. item.key .. "] " .. item.name)
  end

  table.insert(lines, "")
  table.insert(lines, "Utility: [r]un [q]stop [Q]all [?]status [L]ogs")

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

local function npm_logs_picker()
  local items = {}
  for name, job in pairs(npm.jobs) do
    table.insert(items, { name = name, log_file = job.log_file })
  end

  local logs = vim.fn.glob(npm.log_dir .. "/*.log", false, true)
  for _, log in ipairs(logs) do
    local name = vim.fn.fnamemodify(log, ":t:r")
    local exists = false
    for _, item in ipairs(items) do
      if item.name == name then
        exists = true
        break
      end
    end
    if not exists then
      table.insert(items, { name = name, log_file = log })
    end
  end

  if #items == 0 then
    vim.notify("No logs available", vim.log.levels.WARN)
    return
  end

  vim.ui.select(items, {
    prompt = "View Logs",
    format_item = function(item)
      local status = is_running(item.name) and "● " or "  "
      return status .. item.name
    end,
  }, function(choice)
    if choice then
      vim.cmd("edit " .. choice.log_file)
    end
  end)
end

local function npm_stop_all()
  local count = 0
  for name, _ in pairs(npm.jobs) do
    if is_running(name) then
      npm_stop(name)
      count = count + 1
    end
  end
  vim.notify("Stopped " .. count .. " script(s)", vim.log.levels.INFO)
end

-- Utility keymaps (fixed, always available)
map("n", "<leader>tnr", npm_run_picker, { desc = "Run (picker)" })
map("n", "<leader>tnq", npm_stop_picker, { desc = "Stop (picker)" })
map("n", "<leader>tnQ", npm_stop_all, { desc = "Stop All" })
map("n", "<leader>tn?", npm_status, { desc = "Status/Help" })
map("n", "<leader>tnL", npm_logs_picker, { desc = "Logs" })

-- Auto-setup keymaps on DirChanged and BufEnter
vim.api.nvim_create_autocmd({ "DirChanged", "BufEnter" }, {
  callback = function()
    vim.defer_fn(setup_npm_keymaps, 100)
  end,
})

-- Initial setup
setup_npm_keymaps()

-- Lazy Group
-- Remove default mappings to avoid conflicts/delays
pcall(vim.keymap.del, "n", "<leader>l")
pcall(vim.keymap.del, "n", "<leader>L")

map("n", "<leader>ll", "<cmd>Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>le", "<cmd>LazyExtras<cr>", { desc = "Lazy Extras" })
map("n", "<leader>lL", function()
  LazyVim.news.changelog()
end, { desc = "LazyVim Changelog" })
