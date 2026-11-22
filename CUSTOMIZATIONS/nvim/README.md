# nvim 侧配置（custom-neovide）

这里的文件是**用户 nvim 配置**的同步副本，不属于 Rust 工程，不参与编译，也不登记 `registry.md`（用户环境配置，不是程序逻辑自定义，见 `CUSTOMIZATIONS/README.md`「不纳入 registry 的内容」）。
本机已安装到 `%LOCALAPPDATA%\nvim\lua\config\`（`bufferline.lua` 除外，它安装到 `lua\plugins\`），并由 `init.lua` require：

```lua
require("config.neovide_menu")
require("config.neovide_welcome")
```

| 文件 | 作用 |
| ---- | ---- |
| `neovide_menu.lua` | 用 `:amenu` 定义原生菜单栏内容；菜单路径即菜单项 id，点击后由 `:emenu` 执行 |
| `neovide_shell_menu.lua` | 注册/注销 Windows 文件右键菜单「使用 neovim 打开」；图标和命令使用当前运行的 `neovide.exe` |
| `neovide_buffer_tabs.lua` | Neovide 顶部多行文件栏：按宽度换行、自动增高、选中高亮、修改标记、点击切换/关闭 |
| `bufferline.lua` | bufferline 插件 spec：保留 BufferLine 命令但隐藏单行外观，仅在 Neovide 启用自定义多行文件栏 |
| `neovide_welcome.lua` | 关闭最后一个文件缓冲区或在最后一个窗口 `:q` 时保留窗口并显示 snacks dashboard |
| `keymaps.lua` | 本机 `lua/config/keymaps.lua` 的同步副本；包含缓冲区切换/关闭、系统剪贴板和接近普通编辑器的选区删除行为 |

依赖：

- 菜单栏需要 `g:neovide_menubar = true`（默认关闭，本机写在 `lua/config/options.lua`）
- 关闭到系统托盘需要 `g:neovide_tray = true`（默认关闭，本机写在 `lua/config/options.lua`）；只影响窗口 X / Alt+F4，nvim 内 `:qa` 仍正常退出
- 「帮助.关于」的文本在 `neovide_menu.lua::M.about_text()` 组装，点击后经 `rpcnotify("neovide.about", text)` 由 Rust 侧弹出原生对话框
- 欢迎界面依赖 `snacks.nvim` 的 dashboard；缺失时只保留空窗口并输出 WARN
- 菜单里的快捷键提示要求对应键位真实存在（`<Space>ff`、`<Space>/` 等来自 LazyVim）

注意：

- 菜单名不能包含未转义的 `.`（`:amenu` 的层级分隔符）
- 分隔线用 `-sepN-` 占位，Neovide 侧会渲染成真正的分隔线
- 修改 `:amenu` 后执行 `:NeovideRefreshMenu`（或重启）让窗口菜单刷新
- 「常用.注册系统菜单」只写 `HKCU\Software\Classes\*\shell\Neovide`，无需管理员权限；打开命令带 `--reuse-instance`，「注销系统菜单」删除同一项，不影响文件关联和「打开方式」列表
- Neovim 原生 tabline 与 bufferline.nvim 都只支持单行；自定义多行文件栏使用顶部普通窗口实现，普通终端 Neovim 仍使用原 bufferline。原 bufferline 最右侧的 `1、2、3` 是原生 tabpage（工作区）编号，不是文件缓冲区序号；新文件栏不再显示这些编号
- 多行文件栏中单击文件名切换缓冲区，单击 `×`、右键或中键关闭；`:NeovideRefreshBufferTabs` 可手动刷新。文件过多时为编辑区保留空间，文件栏高度最多为 `vim.o.lines - 8`
- 插入模式下 `End → Shift+Home → Backspace/Delete` 只删除当前行文本、保留空行并留在插入模式；实现上避免把行尾后的换行符纳入 Select 选区
- `neovide_welcome.lua` 判断“最后一个窗口”时只统计非浮动窗口：noice/which-key/notify 的浮窗会让 `nvim_list_wins()` 失真
- `keymaps.lua` 的 `Ctrl-W` 在 `filetype == "snacks_dashboard"` 时必须返回 `<Ignore>`（不能用 `<Nop>`，它不会被 `nvim_replace_termcodes` 转换）；否则首界面按 `Ctrl-W` 会删除 dashboard 缓冲区
- `Ctrl-W` 必须走缓冲区删除（`Snacks.bufdelete`），不能映射成 `:q`：LazyVim 默认单窗口，`:q` 会触发 `neovide_welcome.lua` 的 QuitPre 钩子，删掉当前缓冲区并显示 dashboard——即使 bufferline 里还有其他文件
