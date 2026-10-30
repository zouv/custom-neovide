# nvim 侧配置（custom-neovide）

这里的文件是**用户 nvim 配置**的同步副本，不属于 Rust 工程，不参与编译，也不登记 `registry.md`（用户环境配置，不是程序逻辑自定义，见 `CUSTOMIZATIONS/README.md`「不纳入 registry 的内容」）。
本机已安装到 `%LOCALAPPDATA%\nvim\lua\config\`，并由 `init.lua` require：

```lua
require("config.neovide_menu")
require("config.neovide_welcome")
```

| 文件 | 作用 |
| ---- | ---- |
| `neovide_menu.lua` | 用 `:amenu` 定义原生菜单栏内容；菜单路径即菜单项 id，点击后由 `:emenu` 执行 |
| `neovide_welcome.lua` | 关闭最后一个文件缓冲区或在最后一个窗口 `:q` 时保留窗口并显示 snacks dashboard |
| `keymaps.lua` | 本机 `lua/config/keymaps.lua` 的同步副本；将普通模式 `Ctrl-W` 映射为 `:q`（首界面 snacks dashboard 上忽略） |

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
- `neovide_welcome.lua` 判断“最后一个窗口”时只统计非浮动窗口：noice/which-key/notify 的浮窗会让 `nvim_list_wins()` 失真
- `keymaps.lua` 的 `Ctrl-W` 在 `filetype == "snacks_dashboard"` 时必须返回 `<Ignore>`（不能用 `<Nop>`，它不会被 `nvim_replace_termcodes` 转换）；否则首界面按 `Ctrl-W` 会执行 `:q` 关闭最后一个窗口并退出 Neovide
