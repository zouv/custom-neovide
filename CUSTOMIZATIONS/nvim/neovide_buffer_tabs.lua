-- Neovide 多行文件栏：用顶部普通窗口突破 Neovim tabline 的单行限制。
-- bufferline.nvim 仍保留其命令和快捷键，只由本模块取代单行外观。

local M = {}
local api = vim.api
local ns = api.nvim_create_namespace("neovide_buffer_tabs")

local state = {
  panels = {},
  setup_done = false,
  refresh_pending = false,
  refreshing = false,
}

local function truncate(text, max_width)
  if vim.fn.strdisplaywidth(text) <= max_width then
    return text
  end
  local result = ""
  for _, char in ipairs(vim.fn.split(text, "\\zs")) do
    if vim.fn.strdisplaywidth(result .. char .. "…") > max_width then
      break
    end
    result = result .. char
  end
  return result .. "…"
end

local function buffer_items()
  local devicons_ok, devicons = pcall(require, "nvim-web-devicons")
  local buffers = {}
  local name_counts = {}

  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local bufnr = info.bufnr
    if api.nvim_buf_is_valid(bufnr) and vim.bo[bufnr].buflisted and vim.bo[bufnr].buftype == "" then
      local path = api.nvim_buf_get_name(bufnr)
      local name = path == "" and "[No Name]" or vim.fn.fnamemodify(path, ":t")
      name_counts[name] = (name_counts[name] or 0) + 1
      table.insert(buffers, { bufnr = bufnr, path = path, name = name })
    end
  end
  table.sort(buffers, function(a, b)
    return a.bufnr < b.bufnr
  end)

  for _, item in ipairs(buffers) do
    local display_name = item.name
    if name_counts[item.name] > 1 and item.path ~= "" then
      display_name = vim.fn.fnamemodify(item.path, ":h:t") .. "/" .. item.name
    end
    display_name = truncate(display_name, 24)

    local icon = ""
    if devicons_ok and item.name ~= "[No Name]" then
      icon = devicons.get_icon(item.name, vim.fn.fnamemodify(item.name, ":e"), { default = true }) or ""
    end
    local prefix = " " .. (icon ~= "" and icon .. " " or "")
    local modified = vim.bo[item.bufnr].modified and " ●" or ""
    item.label = prefix .. display_name .. modified .. " × "
  end

  return buffers
end

-- 纯布局函数同时供窗口渲染和无界面测试使用；列坐标均为显示单元格（从 1 开始）。
local function build_layout(items, window_width)
  local lines, regions = {}, {}
  local line, line_regions = "", {}
  local line_width = 0

  local function finish_line()
    if line == "" then
      return
    end
    table.insert(lines, line)
    table.insert(regions, line_regions)
    line, line_regions, line_width = "", {}, 0
  end

  for _, item in ipairs(items) do
    local label = item.label
    local label_width = vim.fn.strdisplaywidth(label)
    if label_width > window_width then
      label = truncate(label, window_width)
      label_width = vim.fn.strdisplaywidth(label)
    end
    if line ~= "" and line_width + label_width > window_width then
      finish_line()
    end

    local byte_start = #line
    local first_col = line_width + 1
    line = line .. label
    line_width = line_width + label_width
    table.insert(line_regions, {
      bufnr = item.bufnr,
      byte_start = byte_start,
      byte_end = #line,
      first_col = first_col,
      last_col = line_width,
      close_col = math.max(first_col, line_width - 2),
    })
  end
  finish_line()
  return lines, regions
end

local function set_highlights()
  api.nvim_set_hl(0, "NeovideBufferTabs", { link = "BufferLineBuffer", default = true })
  api.nvim_set_hl(0, "NeovideBufferTabsSelected", { link = "BufferLineBufferSelected", default = true })
  api.nvim_set_hl(0, "NeovideBufferTabsFill", { link = "BufferLineFill", default = true })
end

local function panel_for_window(win)
  for tab, panel in pairs(state.panels) do
    if panel.win == win then
      return tab, panel
    end
  end
end

local function is_panel_buffer(buf)
  for _, panel in pairs(state.panels) do
    if panel.buf == buf then
      return true
    end
  end
  return false
end

local function find_editor_window(tab, preferred)
  if preferred and api.nvim_win_is_valid(preferred) and api.nvim_win_get_tabpage(preferred) == tab then
    local _, panel = panel_for_window(preferred)
    if not panel and api.nvim_win_get_config(preferred).relative == "" then
      return preferred
    end
  end
  for _, win in ipairs(api.nvim_tabpage_list_wins(tab)) do
    local _, panel = panel_for_window(win)
    if not panel and api.nvim_win_get_config(win).relative == "" then
      return win
    end
  end
end

local function focus_editor(tab, panel)
  local editor = find_editor_window(tab, panel and panel.editor or nil)
  if editor then
    if panel then
      panel.editor = editor
    end
    api.nvim_set_current_win(editor)
    return editor
  end
end

local function configure_panel_buffer(buf, win)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].buflisted = false
  vim.bo[buf].swapfile = false
  vim.bo[buf].undofile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "neovide_buffer_tabs"

  local opts = { buffer = buf, silent = true, nowait = true }
  vim.keymap.set("n", "<C-w>", "<Nop>", opts)
  vim.keymap.set("n", "<LeftMouse>", function()
    local mouse = vim.fn.getmousepos()
    M._click_at(mouse.winid, mouse.winline, mouse.wincol, "left")
  end, opts)
  vim.keymap.set("n", "<RightMouse>", function()
    local mouse = vim.fn.getmousepos()
    M._click_at(mouse.winid, mouse.winline, mouse.wincol, "right")
  end, opts)
  vim.keymap.set("n", "<MiddleMouse>", function()
    local mouse = vim.fn.getmousepos()
    M._click_at(mouse.winid, mouse.winline, mouse.wincol, "middle")
  end, opts)

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].cursorline = false
  vim.wo[win].cursorcolumn = false
  vim.wo[win].wrap = false
  vim.wo[win].list = false
  vim.wo[win].spell = false
  vim.wo[win].statuscolumn = ""
  vim.wo[win].winfixheight = true
  vim.wo[win].winhighlight = "Normal:NeovideBufferTabsFill,NormalNC:NeovideBufferTabsFill,EndOfBuffer:NeovideBufferTabsFill"
end

local function create_panel(tab, editor)
  api.nvim_set_current_win(editor)
  vim.cmd("topleft 1split")
  local win = api.nvim_get_current_win()
  local buf = api.nvim_create_buf(false, true)
  api.nvim_win_set_buf(win, buf)
  local panel = { win = win, buf = buf, editor = editor, regions = {} }
  state.panels[tab] = panel
  configure_panel_buffer(buf, win)
  api.nvim_set_current_win(editor)
  return panel
end

local function close_panel(tab, panel)
  if panel.win and api.nvim_win_is_valid(panel.win) then
    if api.nvim_get_current_win() == panel.win then
      focus_editor(tab, panel)
    end
    pcall(api.nvim_win_close, panel.win, true)
  end
  if panel.buf and api.nvim_buf_is_valid(panel.buf) then
    pcall(api.nvim_buf_delete, panel.buf, { force = true })
  end
  state.panels[tab] = nil
end

local function render_panel(panel, items)
  local width = math.max(1, api.nvim_win_get_width(panel.win))
  local lines, regions = build_layout(items, width)
  panel.regions = regions

  vim.bo[panel.buf].modifiable = true
  api.nvim_buf_set_lines(panel.buf, 0, -1, false, lines)
  vim.bo[panel.buf].modifiable = false
  api.nvim_buf_clear_namespace(panel.buf, ns, 0, -1)

  local current_buf = api.nvim_win_get_buf(panel.editor)
  for row, line in ipairs(lines) do
    api.nvim_buf_set_extmark(panel.buf, ns, row - 1, 0, {
      end_col = #line,
      hl_group = "NeovideBufferTabsFill",
      hl_eol = true,
      priority = 90,
    })
    for _, region in ipairs(regions[row]) do
      api.nvim_buf_set_extmark(panel.buf, ns, row - 1, region.byte_start, {
        end_col = region.byte_end,
        hl_group = region.bufnr == current_buf and "NeovideBufferTabsSelected" or "NeovideBufferTabs",
        priority = 100,
      })
    end
  end

  local max_height = math.max(1, vim.o.lines - 8)
  api.nvim_win_set_height(panel.win, math.min(math.max(1, #lines), max_height))
end

local function close_buffer(bufnr)
  local ok, snacks = pcall(require, "snacks")
  if ok and type(snacks.bufdelete) == "function" then
    snacks.bufdelete(bufnr)
  else
    local deleted, err = pcall(vim.cmd, "bdelete " .. bufnr)
    if not deleted then
      vim.notify(tostring(err), vim.log.levels.WARN)
    end
  end
end

function M._click_at(win, line, col, button)
  local tab, panel = panel_for_window(win)
  if not panel then
    return
  end
  for _, region in ipairs((panel.regions or {})[line] or {}) do
    if col >= region.first_col and col <= region.last_col then
      local editor = focus_editor(tab, panel)
      if not editor then
        return
      end
      if button ~= "left" or col >= region.close_col then
        close_buffer(region.bufnr)
        M.refresh()
      else
        api.nvim_win_set_buf(editor, region.bufnr)
        api.nvim_set_current_win(editor)
      end
      return
    end
  end
  focus_editor(tab, panel)
end

function M.refresh()
  if state.refreshing then
    return
  end
  state.refreshing = true
  local current_tab = api.nvim_get_current_tabpage()
  local current_win = api.nvim_get_current_win()
  local _, current_panel = panel_for_window(current_win)
  if current_panel then
    focus_editor(current_tab, current_panel)
  end

  for tab, panel in pairs(state.panels) do
    if not api.nvim_tabpage_is_valid(tab) or not api.nvim_win_is_valid(panel.win) then
      close_panel(tab, panel)
    end
  end

  local items = buffer_items()
  if #items == 0 then
    for tab, panel in pairs(state.panels) do
      close_panel(tab, panel)
    end
  else
    local panel = state.panels[current_tab]
    if not panel then
      local editor = find_editor_window(current_tab, api.nvim_get_current_win())
      if editor then
        panel = create_panel(current_tab, editor)
      end
    else
      panel.editor = find_editor_window(current_tab, panel.editor)
    end

    for tab, existing in pairs(state.panels) do
      if api.nvim_tabpage_is_valid(tab) and api.nvim_win_is_valid(existing.win) and existing.editor then
        render_panel(existing, items)
      end
    end
  end

  vim.o.showtabline = 0
  state.refreshing = false
end

local function schedule_refresh()
  if state.refresh_pending then
    return
  end
  state.refresh_pending = true
  vim.schedule(function()
    state.refresh_pending = false
    M.refresh()
  end)
end

function M.setup()
  if not vim.g.neovide then
    return
  end
  vim.o.showtabline = 0
  if state.setup_done then
    return
  end
  state.setup_done = true
  set_highlights()

  local group = api.nvim_create_augroup("NeovideBufferTabs", { clear = true })
  api.nvim_create_autocmd({
    "BufAdd",
    "BufDelete",
    "BufEnter",
    "BufFilePost",
    "BufModifiedSet",
    "BufReadPost",
    "BufWritePost",
    "SessionLoadPost",
    "TabEnter",
    "TabClosed",
    "VimResized",
  }, {
    group = group,
    callback = function(args)
      if not is_panel_buffer(args.buf) then
        schedule_refresh()
      end
    end,
  })
  api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = function()
      set_highlights()
      schedule_refresh()
    end,
  })
  api.nvim_create_autocmd({ "VimEnter", "UIEnter" }, {
    group = group,
    callback = schedule_refresh,
  })
  api.nvim_create_autocmd("User", {
    group = group,
    pattern = "VeryLazy",
    callback = function()
      vim.o.showtabline = 0
      schedule_refresh()
    end,
  })

  api.nvim_create_user_command("NeovideRefreshBufferTabs", M.refresh, {})
  schedule_refresh()
end

-- 测试与插件 spec 使用的内部接口。
M._build_layout = build_layout
M._panels = state.panels

return M
