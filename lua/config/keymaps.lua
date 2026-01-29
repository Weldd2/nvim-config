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
-- NPM Scripts Manager - Auto-detect from package.json
local npm = {
  jobs = {}, -- { script_name = { job_id, log_file } }
  log_dir = vim.fn.stdpath("cache") .. "/npm_logs",
}

-- Ensure log directory exists
vim.fn.mkdir(npm.log_dir, "p")

-- Find package.json in current directory or parents
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

-- Parse scripts from package.json
local function get_npm_scripts()
  local pkg_path, cwd = find_package_json()
  if not pkg_path then
    return nil, nil
  end

  local content = vim.fn.readfile(pkg_path)
  local json = vim.fn.json_decode(table.concat(content, "\n"))

  if json and json.scripts then
    return json.scripts, cwd
  end
  return nil, cwd
end

-- Check if a job is running
local function is_running(script_name)
  local job = npm.jobs[script_name]
  return job and job.job_id and vim.fn.jobwait({ job.job_id }, 0)[1] == -1
end

-- Start a script
local function npm_start(script_name, cwd)
  if is_running(script_name) then
    vim.notify("'" .. script_name .. "' already running", vim.log.levels.WARN)
    return
  end

  local log_file = npm.log_dir .. "/" .. script_name:gsub("[^%w]", "_") .. ".log"
  vim.fn.writefile({}, log_file)

  local job_id = vim.fn.jobstart({ "npm", "run", script_name }, {
    cwd = cwd,
    env = { CI = "true" },
    on_stdout = function(_, data)
      if data then vim.fn.writefile(data, log_file, "a") end
    end,
    on_stderr = function(_, data)
      if data then vim.fn.writefile(data, log_file, "a") end
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

-- Stop a script
local function npm_stop(script_name)
  if is_running(script_name) then
    vim.fn.jobstop(npm.jobs[script_name].job_id)
    vim.notify("Stopped '" .. script_name .. "'", vim.log.levels.INFO)
    npm.jobs[script_name] = nil
  else
    vim.notify("'" .. script_name .. "' not running", vim.log.levels.WARN)
  end
end

-- Picker: select a script to run
local function npm_run_picker()
  local scripts, cwd = get_npm_scripts()
  if not scripts then
    vim.notify("No package.json found", vim.log.levels.ERROR)
    return
  end

  local items = {}
  for name, cmd in pairs(scripts) do
    local status = is_running(name) and "● " or "  "
    table.insert(items, { name = name, cmd = cmd, status = status })
  end

  table.sort(items, function(a, b) return a.name < b.name end)

  vim.ui.select(items, {
    prompt = "NPM Scripts",
    format_item = function(item)
      return item.status .. item.name .. " → " .. item.cmd
    end,
  }, function(choice)
    if choice then
      npm_start(choice.name, cwd)
    end
  end)
end

-- Picker: select a running script to stop
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

-- Show status of all running scripts
local function npm_status()
  local running = {}
  for name, job in pairs(npm.jobs) do
    if is_running(name) then
      table.insert(running, name .. " (job: " .. job.job_id .. ")")
    end
  end

  if #running == 0 then
    vim.notify("No scripts running", vim.log.levels.INFO)
  else
    vim.notify("Running:\n" .. table.concat(running, "\n"), vim.log.levels.INFO)
  end
end

-- View logs picker
local function npm_logs_picker()
  local items = {}
  for name, job in pairs(npm.jobs) do
    table.insert(items, { name = name, log_file = job.log_file })
  end

  -- Also check for existing log files
  local logs = vim.fn.glob(npm.log_dir .. "/*.log", false, true)
  for _, log in ipairs(logs) do
    local name = vim.fn.fnamemodify(log, ":t:r")
    local exists = false
    for _, item in ipairs(items) do
      if item.name == name then exists = true break end
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

-- Stop all running scripts
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

map("n", "<leader>nr", npm_run_picker, { desc = "NPM Run (picker)" })
map("n", "<leader>nq", npm_stop_picker, { desc = "NPM Stop (picker)" })
map("n", "<leader>nQ", npm_stop_all, { desc = "NPM Stop All" })
map("n", "<leader>ns", npm_status, { desc = "NPM Status" })
map("n", "<leader>nl", npm_logs_picker, { desc = "NPM Logs" })

-- Quick shortcuts for common scripts (dev)
map("n", "<leader>nd", function()
  local _, cwd = get_npm_scripts()
  if cwd then npm_start("dev", cwd) end
end, { desc = "NPM dev" })
map("n", "<leader>nb", function()
  local _, cwd = get_npm_scripts()
  if cwd then npm_start("build", cwd) end
end, { desc = "NPM build" })

-- Lazy Group
-- Remove default mappings to avoid conflicts/delays
pcall(vim.keymap.del, "n", "<leader>l")
pcall(vim.keymap.del, "n", "<leader>L")

map("n", "<leader>ll", "<cmd>Lazy<cr>", { desc = "Lazy" })
map("n", "<leader>le", "<cmd>LazyExtras<cr>", { desc = "Lazy Extras" })
map("n", "<leader>lL", function()
  LazyVim.news.changelog()
end, { desc = "LazyVim Changelog" })
