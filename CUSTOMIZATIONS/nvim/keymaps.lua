-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
-- Ctrl+Tab / Ctrl+Shift+Tab 切换缓冲区（文件）
vim.keymap.set({ "n", "i", "v" }, "<C-Tab>", "<Cmd>bnext<CR>", { desc = "Next buffer" })
vim.keymap.set({ "n", "i", "v" }, "<C-S-Tab>", "<Cmd>bprevious<CR>", { desc = "Previous buffer" })

vim.keymap.set("n", "<C-a>", "ggVG", { desc = "Select all" })
vim.keymap.set("i", "<C-a>", "<Esc>ggVG", { desc = "Select all" })
vim.keymap.set({ "x", "s" }, "<C-a>", "<Esc>ggVG", { desc = "Select all" })
vim.keymap.set("x", "<BS>", '"_d', { desc = "Delete selection" })
vim.keymap.set("s", "<BS>", '<C-g>"_d', { desc = "Delete selection" })
vim.keymap.set("x", "<Del>", '"_d', { desc = "Delete selection" })
vim.keymap.set("s", "<Del>", '<C-g>"_d', { desc = "Delete selection" })
vim.keymap.set({ "n", "i", "x", "s" }, "<C-S-s>", "<Cmd>SaveAs<CR>", { desc = "Save as" })
vim.keymap.set("n", "<leader>fS", "<Cmd>SaveAs<CR>", { desc = "Save as" })
-- 首界面（snacks dashboard）没有可关闭的文件：忽略 Ctrl-W，避免触发 :q 退出 Neovide
vim.keymap.set("n", "<C-w>", function()
  if vim.bo.filetype == "snacks_dashboard" then
    return "<Ignore>"
  end
  return "<Cmd>q<CR>"
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
