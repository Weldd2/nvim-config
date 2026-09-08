-- Cursor CLI dans un buffer Neovim listé (pas de float).
-- Une session par racine de projet. H/L naviguent via bufferline.
-- <leader>bc ouvre / focus. Tant que le buffer existe, l'agent tourne.

local M = {}

---@class CursorAgentSession
---@field buf integer
---@field job integer
---@field started number
---@field root string
---@field continue boolean

---@type table<string, CursorAgentSession>
local sessions = {}

local STATE_FILE = vim.fn.stdpath("state") .. "/cursor_agent.json"
---@type { roots: table<string, boolean> }|nil
local state_cache

local RESPAWN_GUARD_MS = 2000

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Cursor Agent" })
end

---@return string?
function M.executable()
  local candidates = {
    vim.fn.exepath("agent"),
    vim.fn.expand("~/.local/bin/agent"),
    vim.fn.exepath("cursor-agent"),
    vim.fn.expand("~/.local/bin/cursor-agent"),
  }
  for _, path in ipairs(candidates) do
    if path ~= "" and vim.fn.executable(path) == 1 then
      return path
    end
  end
end

local function project_root()
  local ok, root = pcall(function()
    return LazyVim.root()
  end)
  if ok and type(root) == "string" and root ~= "" then
    return root
  end
  return vim.uv.cwd() or vim.fn.getcwd()
end

local function load_state()
  if state_cache then
    return state_cache
  end
  state_cache = { roots = {} }
  local f = io.open(STATE_FILE, "r")
  if not f then
    return state_cache
  end
  local raw = f:read("*a")
  f:close()
  local ok, decoded = pcall(vim.json.decode, raw)
  if ok and type(decoded) == "table" and type(decoded.roots) == "table" then
    state_cache.roots = decoded.roots
  end
  return state_cache
end

local function save_state()
  local state = load_state()
  local dir = vim.fn.fnamemodify(STATE_FILE, ":h")
  vim.fn.mkdir(dir, "p")
  local f = io.open(STATE_FILE, "w")
  if not f then
    return
  end
  f:write(vim.json.encode(state))
  f:close()
end

local function remember_root(root)
  local state = load_state()
  if not state.roots[root] then
    state.roots[root] = true
    save_state()
  end
end

local function known_root(root)
  return load_state().roots[root] == true
end

---@param opts { workspace: string, continue?: boolean, resume?: string, ls?: boolean }
local function build_cmd(opts)
  local bin = M.executable()
  if not bin then
    notify("CLI Cursor introuvable (`agent` / `cursor-agent` pas dans le PATH).", vim.log.levels.ERROR)
    return nil
  end

  local cmd = { bin }

  if opts.ls then
    cmd[#cmd + 1] = "ls"
    return cmd
  end

  cmd[#cmd + 1] = "--trust"

  if opts.resume then
    cmd[#cmd + 1] = "--resume"
    cmd[#cmd + 1] = opts.resume
  elseif opts.continue then
    cmd[#cmd + 1] = "--continue"
  end

  if opts.workspace and opts.workspace ~= "" then
    cmd[#cmd + 1] = "--workspace"
    cmd[#cmd + 1] = opts.workspace
  end

  return cmd
end

local function setup_highlights()
  local function color(group, prop, fallback)
    local ok, c = pcall(function()
      return Snacks.util.color(group, prop)
    end)
    return (ok and c) or fallback
  end

  local bg = color("NormalFloat", "bg", color("Normal", "bg", nil))
  local accent = color("Function", "fg", color("Title", "fg", nil))
  local muted = color("Comment", "fg", nil)
  local key = color("String", "fg", accent)

  vim.api.nvim_set_hl(0, "CursorAgentNormal", { bg = bg })
  vim.api.nvim_set_hl(0, "CursorAgentWinBar", { bg = bg, fg = accent, bold = true })
  vim.api.nvim_set_hl(0, "CursorAgentWinBarNC", { bg = bg, fg = muted })
  vim.api.nvim_set_hl(0, "CursorAgentKey", { bg = bg, fg = key, bold = true })
  vim.api.nvim_set_hl(0, "CursorAgentMuted", { bg = bg, fg = muted })
end

setup_highlights()
vim.api.nvim_create_autocmd("ColorScheme", {
  group = vim.api.nvim_create_augroup("cursor_agent_hl", { clear = true }),
  callback = setup_highlights,
})

---@param buf integer
---@return string
local function winbar_text(buf)
  local root = vim.b[buf].cursor_agent_root
  local project = root and vim.fn.fnamemodify(root, ":t") or "?"
  return table.concat({
    "%#CursorAgentWinBar# Cursor ",
    "%#CursorAgentMuted#· ",
    "%#CursorAgentWinBar#",
    project,
    " %#CursorAgentMuted#│ ",
    "%#CursorAgentKey#i%#CursorAgentMuted# écrire  ",
    "%#CursorAgentKey#Esc%#CursorAgentMuted# normal  ",
    "%#CursorAgentKey#n%#CursorAgentMuted# nouveau  ",
    "%#CursorAgentKey#x%#CursorAgentMuted# stop  ",
    "%#CursorAgentKey#<leader>bc%#CursorAgentMuted# focus",
  })
end

---@param buf integer
local function apply_win_opts(buf)
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_buf(win) ~= buf then
    return
  end
  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.list = false
  wo.spell = false
  wo.cursorline = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  wo.scrolloff = 0
  wo.sidescrolloff = 0
  wo.winhighlight = table.concat({
    "Normal:CursorAgentNormal",
    "NormalNC:CursorAgentNormal",
    "WinBar:CursorAgentWinBar",
    "WinBarNC:CursorAgentWinBarNC",
  }, ",")
  wo.winbar = winbar_text(buf)
end

---@param session CursorAgentSession
---@param data string
local function chan_send(session, data)
  if not session or not session.job then
    return false
  end
  if vim.fn.jobwait({ session.job }, 0)[1] ~= -1 then
    return false
  end
  return (pcall(vim.api.nvim_chan_send, session.job, data))
end

---@param session CursorAgentSession
---@param text string
---@param tries? integer
local function send_when_ready(session, text, tries)
  tries = tries or 0
  if not session or not vim.api.nvim_buf_is_valid(session.buf) then
    return
  end
  if vim.fn.jobwait({ session.job }, 0)[1] ~= -1 then
    if tries < 40 then
      vim.defer_fn(function()
        send_when_ready(session, text, tries + 1)
      end, 150)
    end
    return
  end
  local drawn = vim.api.nvim_buf_line_count(session.buf) > 1
  if not drawn and tries < 40 then
    vim.defer_fn(function()
      send_when_ready(session, text, tries + 1)
    end, 150)
    return
  end
  chan_send(session, text)
end

---@param buf integer
local function setup_buffer(buf)
  vim.bo[buf].filetype = "cursor_agent"
  vim.bo[buf].bufhidden = "hide"
  vim.b[buf].cursor_agent = true

  local group = vim.api.nvim_create_augroup("cursor_agent_buf_" .. buf, { clear = true })

  vim.api.nvim_create_autocmd({ "BufWinEnter", "WinEnter" }, {
    group = group,
    buffer = buf,
    callback = function()
      apply_win_opts(buf)
    end,
  })

  -- Mode normal par défaut : H/L et les leader restent utilisables.
  -- `i` pour écrire ; Esc (terminal) revient en normal sans tuer l'agent.
  vim.keymap.set("t", "<Esc>", function()
    vim.cmd.stopinsert()
  end, { buffer = buf, desc = "Mode normal (sans interrompre l'agent)" })

  vim.keymap.set("n", "<Esc>", function()
    local session = sessions[vim.b[buf].cursor_agent_root or ""]
    if not session then
      for _, s in pairs(sessions) do
        if s.buf == buf then
          session = s
          break
        end
      end
    end
    if session then
      chan_send(session, "\27")
    end
  end, { buffer = buf, desc = "Envoyer Esc au CLI" })

  vim.keymap.set("n", "x", function()
    M.interrupt()
  end, { buffer = buf, desc = "Interrompre l'agent" })

  vim.keymap.set("n", "n", function()
    M.new_chat()
  end, { buffer = buf, desc = "Nouveau chat Cursor" })
end

---@param root string
---@return integer[]
local function windows_showing(buf)
  local wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      wins[#wins + 1] = win
    end
  end
  return wins
end

---@param win integer
local function is_special_win(win)
  local buf = vim.api.nvim_win_get_buf(win)
  local ft = vim.bo[buf].filetype
  return ft == "neo-tree" or ft == "snacks_layout_box" or ft == "NvimTree" or ft == "yazi"
end

---@param prefer_current? boolean
---@return integer
local function target_win(prefer_current)
  if prefer_current ~= false then
    local win = vim.api.nvim_get_current_win()
    if not is_special_win(win) then
      return win
    end
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_special_win(win) then
      return win
    end
  end
  return vim.api.nvim_get_current_win()
end

local function buf_display_name(root)
  return "cursor://" .. vim.fn.fnamemodify(root, ":t")
end

--- Épingle le buffer à gauche dans bufferline (groupe pinned).
---@param buf integer
local function pin_buffer(buf)
  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local ok, groups = pcall(require, "bufferline.groups")
    if not ok or not groups then
      return
    end
    local element = { id = buf }
    if groups._is_pinned(element) then
      return
    end
    groups.add_element("pinned", element)
    pcall(function()
      require("bufferline.ui").refresh()
    end)
  end)
end

---@param root string
---@param opts? { continue?: boolean, resume?: string, win?: integer }
---@return CursorAgentSession?
local function spawn(root, opts)
  opts = opts or {}
  local continue = opts.continue
  if continue == nil then
    continue = known_root(root)
  end

  local cmd = build_cmd({
    workspace = root,
    continue = continue and not opts.resume,
    resume = opts.resume,
  })
  if not cmd then
    return nil
  end

  local win = opts.win or target_win()
  -- jobstart({ term = true }) attache le pty au buffer de la fenêtre *courante*.
  vim.api.nvim_set_current_win(win)
  local buf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_win_set_buf(win, buf)

  local started = vim.uv.now()
  local job = vim.fn.jobstart(cmd, {
    term = true,
    cwd = root,
    env = {
      TERM_THEME = "dark",
      COLORFGBG = "15;0",
    },
    on_exit = function(_, code)
      vim.schedule(function()
        M._on_exit(root, code)
      end)
    end,
  })

  if job <= 0 then
    notify("Impossible de démarrer le CLI Cursor.", vim.log.levels.ERROR)
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return nil
  end

  -- Rename after any previous buffer with the same name is gone.
  pcall(vim.api.nvim_buf_set_name, buf, buf_display_name(root))
  vim.b[buf].cursor_agent_root = root
  setup_buffer(buf)
  apply_win_opts(buf)
  remember_root(root)

  local session = {
    buf = buf,
    job = job,
    started = started,
    root = root,
    continue = continue == true,
  }
  sessions[root] = session
  pin_buffer(buf)

  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      local s = sessions[root]
      if s and s.buf == buf then
        if vim.fn.jobwait({ s.job }, 0)[1] == -1 then
          pcall(vim.fn.jobstop, s.job)
        end
        sessions[root] = nil
      end
    end,
  })

  return session
end

--- Relance si le buffer existe encore et que le job a vécu assez longtemps.
function M._on_exit(root, code)
  local session = sessions[root]
  if not session then
    return
  end

  local old_buf = session.buf
  local alive = vim.api.nvim_buf_is_valid(old_buf)
  local age = vim.uv.now() - session.started

  -- Buffer wiped by the user: don't respawn.
  if not alive then
    sessions[root] = nil
    return
  end

  local wins = windows_showing(old_buf)

  if age < RESPAWN_GUARD_MS then
    notify(
      ("Cursor CLI s'est arrêté trop vite (code %s). Pas de relance automatique."):format(tostring(code)),
      vim.log.levels.ERROR
    )
    sessions[root] = nil
    return
  end

  -- Libérer le nom cursor://… avant de recreer, sinon le rename échoue.
  sessions[root] = nil
  local focus_win = wins[1]
  if not focus_win or not vim.api.nvim_win_is_valid(focus_win) then
    focus_win = target_win()
  end

  -- Buffer temporaire dans les fenêtres pour pouvoir wipe l'ancien terminal.
  local placeholder = vim.api.nvim_create_buf(false, true)
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) then
      pcall(vim.api.nvim_win_set_buf, win, placeholder)
    end
  end
  pcall(vim.api.nvim_buf_delete, old_buf, { force = true })

  local new_session = spawn(root, {
    continue = true,
    win = focus_win,
  })
  if not new_session then
    pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
    return
  end

  for _, win in ipairs(wins) do
    if vim.api.nvim_win_is_valid(win) and win ~= focus_win then
      pcall(vim.api.nvim_win_set_buf, win, new_session.buf)
    end
  end
  pcall(vim.api.nvim_buf_delete, placeholder, { force = true })
end

---@param root? string
---@return CursorAgentSession?
local function get_session(root)
  root = root or project_root()
  local session = sessions[root]
  if session and vim.api.nvim_buf_is_valid(session.buf) then
    if vim.fn.jobwait({ session.job }, 0)[1] == -1 then
      return session
    end
  end
  return nil
end

--- Ouvre ou focus le buffer Cursor pour la racine courante.
---@param opts? { root?: string, resume?: string, fresh?: boolean }
function M.open(opts)
  opts = opts or {}
  local root = opts.root or project_root()

  if opts.fresh then
    local existing = sessions[root]
    if existing then
      if vim.fn.jobwait({ existing.job }, 0)[1] == -1 then
        pcall(vim.fn.jobstop, existing.job)
      end
      local buf = existing.buf
      sessions[root] = nil
      if vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
    return spawn(root, { continue = false, resume = opts.resume })
  end

  local session = get_session(root)
  if session then
    local win = target_win()
    vim.api.nvim_win_set_buf(win, session.buf)
    vim.api.nvim_set_current_win(win)
    apply_win_opts(session.buf)
    pin_buffer(session.buf)
    return session
  end

  -- Dead leftover buffer for this root: wipe then spawn.
  local existing = sessions[root]
  if existing and vim.api.nvim_buf_is_valid(existing.buf) then
    pcall(vim.api.nvim_buf_delete, existing.buf, { force = true })
  end
  sessions[root] = nil

  return spawn(root, {
    continue = opts.resume == nil and known_root(root),
    resume = opts.resume,
  })
end

--- Nouveau chat : tue la session et relance sans --continue.
function M.new_chat()
  local root = project_root()
  local session = get_session(root)
  if session then
    root = session.root
  else
    for r, s in pairs(sessions) do
      if vim.api.nvim_buf_is_valid(s.buf) and vim.api.nvim_get_current_buf() == s.buf then
        root = r
        break
      end
    end
  end
  M.open({ root = root, fresh = true })
end

function M.interrupt()
  local root = project_root()
  local session = get_session(root)
  if not session then
    for _, s in pairs(sessions) do
      if vim.api.nvim_buf_is_valid(s.buf) and vim.api.nvim_get_current_buf() == s.buf then
        session = s
        break
      end
    end
  end
  if not session then
    notify("Aucune session Cursor active.", vim.log.levels.WARN)
    return
  end
  chan_send(session, "\3")
end

---@return integer, integer
local function selection_range()
  if vim.fn.mode():match("^[vV\22]") then
    local s = vim.fn.getpos("v")[2]
    local e = vim.fn.getpos(".")[2]
    if s > e then
      s, e = e, s
    end
    return s, e
  end
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return line, line
end

--- Envoie le fichier courant (ou la sélection) comme `@chemin:début-fin`.
function M.send_context()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" or vim.bo.filetype == "cursor_agent" then
    notify("Aucun fichier source dans ce buffer.", vim.log.levels.WARN)
    return
  end

  local visual = vim.fn.mode():match("^[vV\22]") ~= nil
  local first, last = selection_range()
  if visual then
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "n", false)
  end

  local root = project_root()
  local rel = path
  if path:sub(1, #root) == root then
    rel = path:sub(#root + 2)
  end

  local ref = visual and ("@%s:%d-%d "):format(rel, first, last) or ("@%s "):format(rel)

  local session = M.open({ root = root })
  if not session then
    return
  end
  send_when_ready(session, ref)
end

local function time_ago(ms)
  if not ms or ms <= 0 then
    return ""
  end
  local now = os.time()
  local then_s = math.floor(ms / 1000)
  local delta = math.max(0, now - then_s)
  if delta < 60 then
    return "à l'instant"
  elseif delta < 3600 then
    return ("%d min"):format(math.floor(delta / 60))
  elseif delta < 86400 then
    return ("%d h"):format(math.floor(delta / 3600))
  elseif delta < 86400 * 7 then
    return ("%d j"):format(math.floor(delta / 86400))
  end
  return os.date("%d/%m/%Y", then_s) --[[@as string]]
end

local function first_user_query(jsonl_path)
  local f = io.open(jsonl_path, "r")
  if not f then
    return nil, {}
  end
  local preview = {}
  local title
  for _ = 1, 40 do
    local line = f:read("*l")
    if not line then
      break
    end
    local ok, data = pcall(vim.json.decode, line)
    if ok and type(data) == "table" then
      local role = data.role
      local text
      local content = vim.tbl_get(data, "message", "content")
      if type(content) == "table" then
        for _, part in ipairs(content) do
          if type(part) == "table" and part.type == "text" and type(part.text) == "string" then
            text = part.text
            break
          end
        end
      elseif type(content) == "string" then
        text = content
      end
      if type(text) == "string" and text ~= "" then
        local query
        local s = text:find("<user_query>", 1, true)
        local e = text:find("</user_query>", 1, true)
        if s and e and e > s then
          query = text:sub(s + 12, e - 1)
        end
        local cleaned = (query or text):gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
        if not title and role == "user" and cleaned ~= "" then
          title = cleaned
        end
        local prefix = role == "assistant" and "AI: " or "You: "
        preview[#preview + 1] = prefix .. cleaned
      end
    end
  end
  f:close()
  if title and #title > 80 then
    title = title:sub(1, 77) .. "…"
  end
  return title, preview
end

---@return snacks.picker.finder.Item[]
local function collect_conversations()
  local max_items = 80
  ---@type { path: string, id: string, ts: number, kind: "transcript"|"meta" }[]
  local candidates = {}

  local transcripts = vim.fn.glob(vim.fn.expand("~/.cursor/projects") .. "/*/agent-transcripts/*/*.jsonl", false, true)
  for _, path in ipairs(transcripts) do
    local stat = vim.uv.fs_stat(path)
    candidates[#candidates + 1] = {
      path = path,
      id = vim.fn.fnamemodify(path, ":t:r"),
      ts = stat and (stat.mtime.sec * 1000) or 0,
      kind = "transcript",
    }
  end

  local metas = vim.fn.glob(vim.fn.expand("~/.cursor/chats") .. "/*/*/meta.json", false, true)
  for _, path in ipairs(metas) do
    local stat = vim.uv.fs_stat(path)
    candidates[#candidates + 1] = {
      path = path,
      id = vim.fn.fnamemodify(vim.fn.fnamemodify(path, ":h"), ":t"),
      ts = stat and (stat.mtime.sec * 1000) or 0,
      kind = "meta",
    }
  end

  table.sort(candidates, function(a, b)
    return a.ts > b.ts
  end)

  ---@type table<string, boolean>
  local seen = {}
  ---@type snacks.picker.finder.Item[]
  local items = {}

  for _, cand in ipairs(candidates) do
    if #items >= max_items then
      break
    end
    if not seen[cand.id] then
      seen[cand.id] = true
      local item
      if cand.kind == "transcript" then
        local project_dir = cand.path:match("projects/([^/]+)/agent%-transcripts")
        local title, preview = first_user_query(cand.path)
        item = {
          id = cand.id,
          title = title or cand.id:sub(1, 8),
          project = project_dir or "",
          ts = cand.ts,
          when = time_ago(cand.ts),
          preview_lines = preview,
          file = cand.path,
        }
      else
        local f = io.open(cand.path, "r")
        local meta
        if f then
          local raw = f:read("*a")
          f:close()
          local ok, decoded = pcall(vim.json.decode, raw)
          if ok then
            meta = decoded
          end
        end
        if type(meta) == "table" and (meta.hasConversation or (meta.title and meta.title ~= "")) then
          local ts = tonumber(meta.updatedAtMs) or tonumber(meta.createdAtMs) or cand.ts
          item = {
            id = cand.id,
            title = (meta.title and meta.title ~= "" and meta.title) or cand.id:sub(1, 8),
            project = "chats",
            ts = ts,
            when = time_ago(ts),
            preview_lines = { meta.title or cand.id },
            file = cand.path,
          }
        end
      end
      if item then
        item.text = table.concat({
          item.title or "",
          item.project or "",
          item.id,
          item.when or "",
        }, " ")
        items[#items + 1] = item
      end
    end
  end

  return items
end

function M.history()
  local items = collect_conversations()
  if #items == 0 then
    notify("Aucune conversation trouvée.", vim.log.levels.WARN)
    return
  end

  Snacks.picker.pick({
    title = "Conversations Cursor",
    items = items,
    layout = { preset = "default" },
    format = function(item)
      local a = Snacks.picker.util.align
      return {
        { a(item.title or item.id, 52, { truncate = true }), "SnacksPickerLabel" },
        { "  " },
        { a(item.project or "", 24, { truncate = true }), "Comment" },
        { "  " },
        { item.when or "", "Number" },
      }
    end,
    preview = function(ctx)
      ctx.preview:reset()
      ctx.preview:set_title(ctx.item.title or ctx.item.id)
      local lines = ctx.item.preview_lines
      if type(lines) ~= "table" or #lines == 0 then
        lines = { ctx.item.id }
      end
      ctx.preview:set_lines(lines)
    end,
    confirm = function(picker, item)
      picker:close()
      if not item then
        return
      end
      M.open({ resume = item.id, fresh = true })
    end,
  })
end

return M
