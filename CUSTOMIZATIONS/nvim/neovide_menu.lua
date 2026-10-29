-- Neovide 原生菜单栏的内容定义（仅 Windows 的 custom-neovide 生效）。
--
-- 菜单项通过 `:amenu` 定义，Neovide 启动后读取 `vim.fn.menu_get("")` 并渲染成
-- Win32 菜单；点击时 Neovide 回传菜单路径，再用 `:emenu` 执行对应的映射。
-- 因此这里写的菜单路径（如 `文件.保存`）就是菜单项的稳定 id。
--
-- 注意：菜单名里不能包含未转义的 "."（它是层级分隔符）。
-- hints 只是显示用的文本，请只填写真实存在的键位。

if not vim.g.neovide then
  return
end

local M = {}

local function close_buffer()
  local ok, snacks = pcall(require, "snacks")
  if ok and type(snacks.bufdelete) == "function" then
    snacks.bufdelete()
  else
    vim.cmd("bdelete")
  end
end

local function toggle_fullscreen()
  vim.g.neovide_fullscreen = not vim.g.neovide_fullscreen
end

local function scale_by(factor)
  local current = tonumber(vim.g.neovide_scale_factor) or 1.0
  vim.g.neovide_scale_factor = math.max(0.5, math.min(3.0, current * factor))
end

local function save_as()
  vim.ui.input(
    { prompt = "另存为: ", default = vim.fn.expand("%:p"), completion = "file" },
    function(path)
      if path and path ~= "" then
        vim.cmd("saveas " .. vim.fn.fnameescape(path))
      end
    end
  )
end

local function replace_all()
  vim.ui.input({ prompt = "查找: " }, function(pattern)
    if not pattern or pattern == "" then
      return
    end
    vim.ui.input({ prompt = "替换为: " }, function(replacement)
      if replacement == nil then
        return
      end
      local cmd = ("%%s/%s/%s/g"):format(vim.fn.escape(pattern, "/"), vim.fn.escape(replacement, "/"))
      local ok, err = pcall(vim.cmd, cmd)
      if not ok then
        vim.notify(err, vim.log.levels.ERROR)
      end
    end)
  end)
end

local function picker(method)
  return function()
    local ok, snacks = pcall(require, "snacks")
    if not ok or type(snacks.picker) ~= "table" or type(snacks.picker[method]) ~= "function" then
      vim.notify("snacks.nvim 的 picker." .. method .. " 不可用", vim.log.levels.WARN)
      return
    end
    snacks.picker[method]()
  end
end

local function format_buffer()
  local ok, conform = pcall(require, "conform")
  if ok then
    conform.format({ async = true, lsp_format = "fallback" })
  else
    vim.lsp.buf.format({ async = true })
  end
end

local function show_keymaps()
  local ok, which_key = pcall(require, "which-key")
  if ok and type(which_key.show) == "function" then
    which_key.show()
  else
    vim.cmd("map")
  end
end

local function notify(method, ...)
  local channel = vim.g.neovide_channel_id
  if not channel then
    return
  end
  local ok, err = pcall(vim.rpcnotify, channel, method, ...)
  if not ok then
    vim.notify("Neovide RPC 失败：" .. tostring(err), vim.log.levels.WARN)
  end
end

function M.about_text()
  local version = vim.g.neovide_version or "unknown"
  local v = vim.version()
  local uname = (vim.uv or vim.loop).os_uname()
  return table.concat({
    ("Neovide %s"):format(version),
    ("Neovim %d.%d.%d"):format(v.major, v.minor, v.patch),
    ("系统 %s %s (%s)"):format(uname.sysname, uname.release, uname.machine),
    ("配置目录 %s"):format(vim.fn.stdpath("config")),
    "",
    "custom-neovide：基于 neovide 的自定义版本",
  }, "\n")
end

M.actions = {
  new_file = function()
    vim.cmd("enew")
  end,
  find_files = picker("files"),
  live_grep = picker("grep"),
  recent_files = picker("oldfiles"),
  explorer = function()
    local ok, snacks = pcall(require, "snacks")
    if ok and type(snacks.explorer) == "function" then
      snacks.explorer()
    else
      vim.cmd("Neotree toggle")
    end
  end,
  close_buffer = close_buffer,
  save_as = save_as,
  replace_all = replace_all,
  toggle_fullscreen = toggle_fullscreen,
  scale_up = function()
    scale_by(1.1)
  end,
  scale_down = function()
    scale_by(1 / 1.1)
  end,
  reset_scale = function()
    vim.g.neovide_scale_factor = 1.0
  end,
  toggle_wrap = function()
    vim.wo.wrap = not vim.wo.wrap
  end,
  toggle_numbers = function()
    vim.wo.number = not vim.wo.number
    vim.wo.relativenumber = false
  end,
  terminal = function()
    vim.cmd("terminal")
  end,
  code_action = function()
    vim.lsp.buf.code_action()
  end,
  format_buffer = format_buffer,
  show_keymaps = show_keymaps,
  config = function()
    vim.cmd("NeovideConfig")
  end,
  about = function()
    notify("neovide.about", M.about_text())
  end,
}

-- 只显示真实存在的快捷键
M.hints = {
  ["文件.打开文件"] = "<Space>ff",
  ["文件.保存"] = "<C-s>",
  ["编辑.查找"] = "<Space>/",
  ["常用.文件浏览器"] = "<Space>e",
  ["常用.全局搜索"] = "<Space>/",
  ["常用.最近文件"] = "<Space>fr",
  ["常用.代码操作"] = "<Space>ca",
  ["常用.格式化文件"] = "<Space>cf",
}

-- 分隔线：用 -sepN- 作为占位名，Neovide 侧会渲染成真正的分隔线
local function action(name)
  return ("<Cmd>lua require('config.neovide_menu').actions.%s()<CR>"):format(name)
end

local menudefs = {
  -- 文件
  { "10.10", "文件.新建", action("new_file") },
  { "10.20", "文件.打开文件", action("find_files") },
  { "10.30", "文件.保存", "<Cmd>w<CR>" },
  { "10.40", "文件.另存为", action("save_as") },
  { "10.50", "文件.-sep1-", "<Nop>" },
  { "10.60", "文件.关闭文件", action("close_buffer") },
  { "10.70", "文件.退出", "<Cmd>qa<CR>" },

  -- 编辑
  { "20.10", "编辑.撤销", "<Cmd>undo<CR>" },
  { "20.20", "编辑.重做", "<Cmd>redo<CR>" },
  { "20.30", "编辑.-sep1-", "<Nop>" },
  { "20.40", "编辑.剪切", [[<Cmd>normal! "+dd<CR>]] },
  { "20.50", "编辑.复制", [[<Cmd>normal! "+yy<CR>]] },
  { "20.60", "编辑.粘贴", [[<Cmd>normal! "+p<CR>]] },
  { "20.70", "编辑.全选", "<Cmd>normal! ggVG<CR>" },
  { "20.80", "编辑.-sep2-", "<Nop>" },
  { "20.90", "编辑.查找", action("live_grep") },
  { "20.100", "编辑.替换", action("replace_all") },

  -- 视图
  { "30.10", "视图.全屏", action("toggle_fullscreen") },
  { "30.20", "视图.放大", action("scale_up") },
  { "30.30", "视图.缩小", action("scale_down") },
  { "30.40", "视图.重置缩放", action("reset_scale") },
  { "30.50", "视图.-sep1-", "<Nop>" },
  { "30.60", "视图.自动换行", action("toggle_wrap") },
  { "30.70", "视图.行号", action("toggle_numbers") },

  -- 常用
  { "40.10", "常用.文件浏览器", action("explorer") },
  { "40.20", "常用.全局搜索", action("live_grep") },
  { "40.30", "常用.最近文件", action("recent_files") },
  { "40.40", "常用.-sep1-", "<Nop>" },
  { "40.50", "常用.终端", action("terminal") },
  { "40.60", "常用.代码操作", action("code_action") },
  { "40.70", "常用.格式化文件", action("format_buffer") },

  -- 帮助
  { "50.10", "帮助.快捷键", action("show_keymaps") },
  { "50.20", "帮助.设置", action("config") },
  { "50.25", "帮助.-sep1-", "<Nop>" },
  { "50.30", "帮助.关于", action("about") },
}

for _, item in ipairs(menudefs) do
  local priority, path, rhs = item[1], item[2], item[3]
  local ok, err = pcall(vim.cmd, ("amenu %s %s %s"):format(priority, path, rhs))
  if not ok then
    vim.notify(("菜单项定义失败：%s\n%s"):format(path, err), vim.log.levels.WARN)
  end
end

vim.g.neovide_menu_hints = M.hints

return M
