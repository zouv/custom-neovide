return {
  {
    "akinsho/bufferline.nvim",
    init = function()
      if vim.g.neovide then
        require("config.neovide_buffer_tabs").setup()
      end
    end,
    opts = function(_, opts)
      if not vim.g.neovide then
        return
      end
      -- 保留 BufferLine* 命令，但禁止插件重新显示单行 tabline。
      opts.options = opts.options or {}
      opts.options.always_show_bufferline = false
      opts.options.auto_toggle_bufferline = false
    end,
  },
}
