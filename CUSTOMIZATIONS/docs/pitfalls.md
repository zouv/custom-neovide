# 坑点库（pitfalls）

> 排查问题前先扫标题；解决新坑后回写一条（现象 → 根因 → 解法 → 教训）。
> 每条一个 `### 标题`，按时间倒序追加，永不删改历史。

### noice 等插件让 `:q` 守卫失效

- **现象**：`neovide_welcome.lua` 的 `QuitPre` 守卫在无界面测试里能拦住 `:q`，但在 Neovide + LazyVim 里按 `:q` 仍然直接关窗。日志显示 `QuitPre wins=3 floats=2`。
- **根因**：noice.nvim 的命令行/通知浮窗在 `QuitPre` 触发时仍存在，`#nvim_list_wins()` 是 3；守卫要求窗口数等于 1，于是直接放行。
- **解法**：窗口计数必须排除 floating window（`nvim_win_get_config(win).relative == ""`），只对当前 tabpage 的普通窗口计数；`BufDelete` 路径同理，改用 `current_normal_window()` 定位目标窗口。
- **教训**：在 Neovide/GUI 环境里做“最后一个窗口”判断时，永远不要用 `nvim_list_wins()` 的裸数量；浮窗、noice、which-key、notify 都会让计数失真。

### 原生菜单栏在 D3D 下不可见

- **现象**：Win32 菜单 API（`SetMenu` / muda `init_for_hwnd`）返回成功，`GetMenu` 能读到完整菜单树，`WM_COMMAND` 也能触发，但窗口上完全看不到菜单栏；换成 `--opengl` 就正常显示。
- **根因**：Neovide 的 D3D 后端用 `CreateSwapChainForComposition` + DirectComposition，并且给窗口加了 `WS_EX_NOREDIRECTIONBITMAP`。这种窗口没有 GDI 重定向表面，系统绘制的非客户区（菜单栏）没有地方落地；同时合成 visual 覆盖了菜单区域。
- **解法**：
  1. `src/renderer/mod.rs::build_window_config` 中，Windows 上如果 `g:neovide_menubar` 为 true 就改用 OpenGL 渲染器（OpenGL 走普通 HWND 交换链，系统菜单栏正常）。
  2. 只切渲染器还不够：`src/window/mod.rs::create_window` 里 `with_no_redirection_bitmap(true)` 原本只在 `!opengl` 时跳过，菜单栏触发 OpenGL 时 `cmd_line.opengl` 仍是 false，窗口依然带 `WS_EX_NOREDIRECTIONBITMAP` → OpenGL 画面没有落地表面，整个窗口全透明。启用菜单栏时也必须跳过该标志。
- **教训**：在 Windows 上给 Neovide 加“系统绘制”的元素（菜单、系统菜单、非客户区装饰）前，先确认当前渲染后端的呈现方式；D3D/composition 路径会让 GDI 非客户区失效。渲染后端的“窗口属性”和“渲染器选择”必须由同一个条件决定，不能只改其一。

（首次踩坑解决后在此追加第一条。）
