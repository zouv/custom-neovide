-- 关闭最后一个文件后保留 Neovide 窗口，并回到欢迎界面（snacks.nvim dashboard）。
--
-- 覆盖两条路径：
--   1. 删除最后一个文件缓冲区（bufferline 的 ×、<leader>bd、:bd 等）→ 显示 dashboard
--   2. 在最后一个窗口上 :q / :wq / :x → 打开一个备用窗口接住这次关闭，再显示 dashboard
--
-- :qa / :qa!（以及 Neovide 关闭按钮）不受影响，仍然正常退出。
--
-- 注意：noice 等插件会在 :q 时留下浮动窗口，所以窗口计数必须排除 floating window。

if not vim.g.neovide then
  return
end

local group = vim.api.nvim_create_augroup("NeovideWelcome", { clear = true })

local function is_dashboard(buf)
  return vim.bo[buf].filetype == "snacks_dashboard"
end

-- 终端、help、quickfix、neo-tree 等非文件缓冲区
local function is_special(buf)
  return is_dashboard(buf)
    or vim.bo[buf].buftype ~= ""
    or vim.bo[buf].filetype == "neo-tree"
    or vim.bo[buf].filetype == "oil"
end

local function normal_windows()
  return vim.tbl_filter(function(win)
    return vim.api.nvim_win_get_config(win).relative == ""
  end, vim.api.nvim_tabpage_list_wins(0))
end

local function current_normal_window()
  local wins = normal_windows()
  local current = vim.api.nvim_get_current_win()
  for _, win in ipairs(wins) do
    if win == current then
      return win
    end
  end
  return wins[1]
end

local function has_file_buffer()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.bo[buf].buflisted
      and not is_special(buf)
      and vim.api.nvim_buf_get_name(buf) ~= ""
    then
      return true
    end
  end
  return false
end

local function open_dashboard(win, buf)
  win = win or vim.api.nvim_get_current_win()
  buf = buf or vim.api.nvim_win_get_buf(win)
  local ok, snacks = pcall(require, "snacks")
  if ok and type(snacks.dashboard) == "table" and type(snacks.dashboard.open) == "function" then
    if pcall(snacks.dashboard.open, { buf = buf, win = win }) then
      return true
    end
  end
  return false
end

-- 路径 1：最后一个文件缓冲区被删除
vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
  group = group,
  callback = function(args)
    local deleted = args.buf
    if vim.api.nvim_buf_get_name(deleted) == "" or is_special(deleted) then
      return
    end

    vim.schedule(function()
      if has_file_buffer() then
        return
      end

      local win = current_normal_window()
      if not win then
        return
      end

      local buf = vim.api.nvim_win_get_buf(win)
      if is_special(buf) then
        return
      end
      if vim.api.nvim_buf_get_name(buf) ~= "" then
        vim.api.nvim_win_call(win, function()
          vim.cmd("enew")
        end)
      end
      open_dashboard(win, vim.api.nvim_win_get_buf(win))
    end)
  end,
})

-- 路径 2：在最后一个窗口上 :q 等
vim.api.nvim_create_autocmd("QuitPre", {
  group = group,
  callback = function()
    local wins = normal_windows()
    if #wins ~= 1 or #vim.api.nvim_list_tabpages() ~= 1 then
      return
    end

    local win = wins[1]
    local buf = vim.api.nvim_win_get_buf(win)

    -- 欢迎界面或特殊窗口上 :q：保持 nvim 原生行为
    if is_special(buf) or vim.bo[buf].modified then
      return
    end
    if vim.api.nvim_buf_get_name(buf) == "" then
      return
    end

    -- 打开一个不进入的备用窗口，让随后的 :q 只关闭当前窗口
    local spare = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_open_win(spare, false, { split = "right", win = win })

    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(buf) then
        pcall(vim.api.nvim_buf_delete, buf, { force = false })
      end

      local target = current_normal_window()
      if not target then
        return
      end
      local target_buf = vim.api.nvim_win_get_buf(target)
      if vim.api.nvim_buf_get_name(target_buf) == "" and not is_special(target_buf) then
        vim.api.nvim_set_current_win(target)
        open_dashboard(target, target_buf)
      end
    end)
  end,
})
