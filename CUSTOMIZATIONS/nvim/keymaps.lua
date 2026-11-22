-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Ctrl+Tab / Ctrl+Shift+Tab 切换缓冲区（文件）
vim.keymap.set({ "n", "i", "v" }, "<C-Tab>", "<Cmd>bnext<CR>", { desc = "Next buffer" })
vim.keymap.set({ "n", "i", "v" }, "<C-S-Tab>", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })

vim.keymap.set("n", "<C-a>", "ggVG", { desc = "Select all" })
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", { desc = "Select all" })
vim.keymap.set({ "x", "s" }, "<C-a>", "<Esc>ggVG", { desc = "Select all" })
-- 插入模式下 End 位于最后一个字符之后，默认 Shift+Home 会把换行符也纳入 Select 选区。
-- 先回到普通模式再建立选区，使 End → Shift+Home 只选择当前行文本。
local function select_to_line_start()
  return "<Esc>v0<C-g>"
end

-- Select 模式用 c 删除选区并留在插入模式；d 会在上述场景把后一行并上来。
local function delete_selection()
  -- 空行的可视选区不代表换行符，删除它应当是无操作，而不是合并两行。
  if vim.fn.line("v") == vim.fn.line(".") and vim.api.nvim_get_current_line() == "" then
    return "<Esc>i"
  end
  return '<C-g>"_c'
end

vim.keymap.set("i", "<S-Home>", select_to_line_start, {
  expr = true,
  replace_keycodes = true,
  desc = "Select to line start without newline",
})
vim.keymap.set("x", "<BS>", '"_d', { desc = "Delete selection" })
vim.keymap.set("s", "<BS>", delete_selection, {
  expr = true,
  replace_keycodes = true,
  desc = "Delete selection",
})
vim.keymap.set("x", "<Del>", '"_d', { desc = "Delete selection" })
vim.keymap.set("s", "<Del>", delete_selection, {
  expr = true,
  replace_keycodes = true,
  desc = "Delete selection",
})
vim.keymap.set({ "n", "i", "x", "s" }, "<C-S-s>", "<Cmd>SaveAs<CR>", { desc = "Save as" })
vim.keymap.set("n", "<leader>fS", "<Cmd>SaveAs<CR>", { desc = "Save as" })
-- 首界面（snacks dashboard）没有可关闭的文件：忽略 Ctrl-W
-- 其余情况删除当前文件缓冲区（与 bufferline 的 ×、<leader>bd 一致）：
-- 还有其他文件时切到最近使用的那个；最后一个文件时由 neovide_welcome.lua 显示 dashboard
vim.keymap.set("n", "<C-w>", function()
  if vim.bo.filetype == "snacks_dashboard" then
    return "<Ignore>"
  end
  return "<Cmd>lua Snacks.bufdelete()<CR>"
end, { expr = true, replace_keycodes = true, desc = "Close current buffer" })

if vim.g.neovide then
  local function paste_over_selection()
    local text = vim.fn.getreg("+")
    local regtype = vim.fn.getregtype("+")

    vim.cmd([[normal! "_d]])
    vim.fn.setreg("+", text, regtype)
    vim.cmd([[normal! "+P]])
  end

  vim.keymap.set("x", "<C-c>", '"+y', { desc = "Copy to system clipboard" })
  vim.keymap.set("s", "<C-c>", '<C-g>"+y<Cmd>startinsert<CR>', { desc = "Copy to system clipboard" })
  vim.keymap.set("n", "<C-v>", '"+p', { desc = "Paste from system clipboard" })
  vim.keymap.set("x", "<C-v>", paste_over_selection, { desc = "Paste from system clipboard" })
  vim.keymap.set("s", "<C-v>", "<C-r>_x<BS><C-r>+", { desc = "Paste from system clipboard" })
  vim.keymap.set({ "i", "c" }, "<C-v>", "<C-r>+", { desc = "Paste from system clipboard" })
end
