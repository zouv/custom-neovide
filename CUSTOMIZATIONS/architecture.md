# 代码链路图谱 · custom-neovide

> **本文件的目的**：给 AI（及人类）一份「读这一份就能定位代码」的导航地图，
> 避免每次改动/排查都全量扫描源码，节省上下文与 token。
>
> **维护铁律**：改了代码结构（新增函数 / 移动逻辑 / 改数据流 / 改接口），必须同步更新本文件。
> **体量铁律**：超过 ~400 行即拆分——保留 §0 / §0.5 / §1，各模块细节拆到 `docs/arch/<module>.md`。
>
> **配套**：历史坑点见 [`docs/pitfalls.md`](./docs/pitfalls.md)；改动账本见 [`registry.md`](./registry.md)。

---

## 0. 一句话架构

Rust 单二进制 GUI（winit + Skia）。它不是编辑器，而是 Neovim 的 UI 客户端：启动/连接 `nvim` 进程，经 msgpack-RPC（nvim-rs + tokio）接收 `redraw` 事件，在独立线程把事件转成 `DrawCommand`，主线程用 Skia（D3D12/Metal/OpenGL）绘制。核心目录：

```
src/
  main.rs       入口：panic hook、日志、事件循环、Application 装配（含 200+ 行架构注释）
  bridge/       nvim 进程生命周期 + RPC（handler/session/setup/ui_commands/events）
  editor/       把 RedrawEvent 转成 DrawCommand（grid 字符网格、cursor、draw_command_batcher）
  renderer/     Skia 绘制（rendered_window 行级缓存、grid_renderer、fonts、cursor_renderer、vsync）
  window/       winit 事件循环、窗口管理、输入（application/window_wrapper/mouse_manager/keyboard_manager）
  settings/     设置系统（live 更新 g:neovide_*、config.toml 热重载）
  clipboard.rs  剪贴板抽象（各平台 provider）
  cmd_line.rs   CLI 参数解析（clap）
  ipc/          macOS 单实例复用（handoff，unix socket）
  profiling/    Tracy 埋点（feature 门控）
  utils/        通用工具（ring_buffer 等）
lua/init.lua    注入 nvim 的初始化脚本（neovide.* RPC 通知、设置同步）
wix/            Windows MSI 安装包
```

数据流（启动 → 绘制）：

```
nvim 进程 ──msgpack──▶ bridge(handler) ──RedrawEvent──▶ editor 线程 ──DrawCommand(batch)──▶
  window 事件循环(EventLoopProxy) ──▶ renderer(Skia) ──▶ 屏幕
window 输入 ──▶ bridge(ui_commands) ──UiCommand──▶ nvim
```

## 0.5 任务作用域路由（先定范围，避免污染上下文）

| 任务类型                       | 该读（仅限）                                                                                                    | 可忽略                          | 入口 |
| ------------------------------ | --------------------------------------------------------------------------------------------------------------- | ------------------------------- | ---- |
| CLI 参数 / 启动流程            | `src/main.rs`、`src/cmd_line.rs`                                                                                 | renderer、editor                | §2.1 |
| nvim 连接 / 重启 / 会话        | `src/bridge/mod.rs`、`src/bridge/session.rs`、`src/bridge/restart.rs`                                            | editor、window                  | §2.2 |
| RPC 事件解析（redraw）         | `src/bridge/events.rs`、`src/bridge/handler.rs`                                                                  | renderer                        | §2.3 |
| 发给 nvim 的命令               | `src/bridge/ui_commands.rs`、`src/bridge/command.rs`                                                             | renderer                        | §2.3 |
| 编辑器状态 / grid / 光标       | `src/editor/mod.rs`、`src/editor/grid.rs`、`src/editor/window.rs`、`src/editor/cursor.rs`                        | renderer、window 输入           | §2.4 |
| 文字整形 / 字体 / 连字         | `src/renderer/fonts/`（caching_shaper/font_loader/font_options/swash_font）                                      | window、bridge                  | §2.5 |
| 绘制 / 行缓存 / 平滑滚动       | `src/renderer/rendered_window.rs`、`src/renderer/grid_renderer.rs`、`src/renderer/mod.rs`、`src/renderer/rendered_layer.rs` | editor、window 输入        | §2.5 |
| GPU 后端 / vsync               | `src/renderer/{d3d,opengl,metal}.rs`、`src/renderer/vsync/`                                                      | editor                          | §2.5 |
| 窗口创建 / 帧调度 / 动画       | `src/window/application.rs`、`src/window/window_wrapper.rs`                                                      | bridge、editor                  | §2.6 |
| 鼠标 / 键盘输入                | `src/window/mouse_manager.rs`、`src/window/keyboard_manager.rs`                                                  | renderer                        | §2.7 |
| 设置项（新增/改默认）          | `src/settings/{mod,config,window_size,font,from_value}.rs` + `lua/init.lua` + 各 `*Settings` struct               | —                               | §2.8 |
| 剪贴板                         | `src/clipboard.rs`、`src/bridge/clipboard.rs`                                                                    | —                               | §2.9 |
| 单实例复用（macOS/Windows）    | `src/ipc/handoff.rs`、`src/main.rs::maybe_handoff`、`src/window/application.rs::prepare_open_files`              | —                               | §2.10 |
| Windows 原生菜单栏             | `src/window/menubar.rs`、`src/window/window_wrapper.rs`（菜单命令/显隐）、`src/window/about.rs`（帮助.关于）、`src/bridge/handler.rs`（set_menu/about）、`src/renderer/mod.rs`（渲染器选择）、`lua/init.lua`（refresh_menu/menu_command） | renderer 内部实现、editor | §2.12 |
| 系统托盘 / 关闭到托盘          | `src/window/tray.rs`、`src/window/application.rs`（CloseRequested 拦截/托盘生命周期）、`src/window/window_wrapper.rs`（hidden_to_tray/渲染暂停）、`src/window/settings.rs`（g:neovide_tray） | bridge、editor、renderer 内部实现 | §2.13 |
| 打包 / 发布                    | `wix/`（Windows）、`.github/workflows/`、`Cargo.toml`                                                            | 业务代码                        | §2.11 |

> 定位优先级：**函数名 grep > 本表**。表过期时以代码为准并顺手订正本表。

---

## 1. 重点链路

### 1.1 启动链路（慢启动排查必读）

`main::main` → `preflight`（CLI 解析、macOS handoff、disown）→ `setup`（注册 settings、watch config）→ `Application::new` → `run`（winit 事件循环）→ `resumed` → `window_wrapper.request_window_creation` → `runtime.launch`（启动 nvim + RPC 握手 + `ui_attach`）→ 收到首批 draw command 且 `should_show` → `try_create_window`（创建 OS 窗口 + GPU）→ 首帧后 `set_visible(true)`。

关键点：**窗口和 GPU 初始化排在 nvim 加载配置之后**（等 `should_show`/`UIReady`），因此 nvim 配置慢 → 整个启动慢。`settings::read_initial_values` 在 `ui_attach` 前对每个设置项串行 `get_var`/`set_var`，是 RPC 往返的大头。

### 1.2 单帧渲染链路

`application::about_to_wait` → `prepare_and_animate` → `window_wrapper.prepare_frame`（判是否需要 resize）→ `animate`（固定步长推进动画）→ `schedule_render` → `render` → `window_wrapper.draw_frame` → `renderer.draw_frame`（clear → root windows → floating layers → cursor → profiler → progress bar）→ `skia_renderer.flush` → `vsync.wait_for_vsync` → `swap_buffers`。

行级缓存：`rendered_window::prepare_lines` 只对失效行重新录制 Skia `Picture`（背景/前景/box-drawing 三张），每帧回放。

### 1.3 平滑滚动链路

nvim 发 `win_viewport` → editor 发 `DrawCommand::Window{Viewport{scroll_delta}}` → `rendered_window::handle_window_draw_command` 记录 delta → `flush` 旋转 `scrollback_lines`（2×高度环形缓冲）并设定弹簧动画目标 → `animate_frame` 推进 `scroll_animation.position` → `draw_frame` 用 `scroll_offset_pixels` 平移回放。

---

## 2. 模块索引（按任务）

### 2.1 CLI / 启动
- `src/cmd_line.rs`：`CmdLineSettings`（clap 派生），`handle_command_line_arguments`、`maybe_passthrough_to_neovim`
- `src/main.rs`：`preflight`、`setup`、`maybe_handoff`（macOS）、`maybe_disown`（unix）

### 2.2 bridge（nvim 生命周期）
- `src/bridge/mod.rs`：`NeovimRuntime`（tokio runtime 封装）、`launch`、`restart`、`run`、`create_neovim_session`
- `src/bridge/session.rs`：`NeovimSession`/`NeovimInstance`（embedded vs server）
- `src/bridge/restart.rs`：`:restart` 的地址传递
- `src/bridge/setup.rs`：`get_api_information`、`setup_neovide_specific_state`（注入 `lua/init.lua`）
- `src/bridge/command.rs`：构造 nvim 启动命令（wsl/login shell 处理）

### 2.3 bridge（RPC 事件与命令）
- `src/bridge/handler.rs`：`NeovimHandler`（`handle_notify`/`handle_request`）、clipboard RPC、`neovide.*` 通知
- `src/bridge/events.rs`：`parse_redraw_event` 及所有 `parse_*` 事件解析
- `src/bridge/ui_commands.rs`：`UiCommand`/`SerialCommand`/`ParallelCommand`、`send_ui`、`start_ui_command_handler`

### 2.4 editor（状态）
- `src/editor/mod.rs`：`Editor::handle_redraw_event`（大 match）、`start_editor_handler`（独立线程）
- `src/editor/grid.rs`：`CharacterGrid`（RingBuffer 行存储）、`scroll_region`
- `src/editor/window.rs`：`Window`（grid + viewport + `build_line_fragment`/`redraw_line`）
- `src/editor/cursor.rs`：光标模式/形状
- `src/editor/draw_command_batcher.rs`：按 flush 批量发 DrawCommand

### 2.5 renderer（绘制）
- `src/renderer/mod.rs`：`Renderer`、`DrawCommand`、`RendererSettings`、`draw_frame`
- `src/renderer/rendered_window.rs`：`RenderedWindow`（行 Picture 缓存、scrollback、动画）
- `src/renderer/rendered_layer.rs`：浮动窗口分层/阴影/模糊
- `src/renderer/grid_renderer.rs`：默认背景/文字绘制
- `src/renderer/fonts/`：`CachingShaper`（整形 LRU 缓存）、`FontLoader`（fallback）
- `src/renderer/cursor_renderer/`：光标动画 + VFX
- `src/renderer/box_drawing/`：box-drawing 字符绘制
- `src/renderer/{d3d,opengl,metal}.rs`、`src/renderer/vsync/`：GPU 后端与垂直同步

### 2.6 window（事件循环）
- `src/window/application.rs`：`Application`（`ApplicationHandler`）、`RenderState`、帧调度
- `src/window/window_wrapper.rs`：`WindowWrapper`（routes/多窗口）、窗口创建、`draw_frame`

### 2.7 输入
- `src/window/mouse_manager.rs`：鼠标事件 → grid 坐标 → nvim
- `src/window/keyboard_manager.rs`：键盘/IME

### 2.8 settings
- `src/settings/mod.rs`：`Settings`（TypeId 存储）、`SettingLocation`、`read_initial_values`
- `src/settings/config.rs`：config.toml 解析与热重载
- `lua/init.lua`：nvim 侧设置同步（autocmd 发 `setting_changed`）

### 2.9 剪贴板
- `src/clipboard.rs`：`Clipboard`/`ClipboardHandle`（多 provider）
- `src/bridge/clipboard.rs`：与 nvim 的 get/set 桥接

### 2.10 单实例复用（macOS/Windows）
- `src/ipc/handoff.rs`：回环 TCP / unix socket listener、`HandoffRequest`、`try_handoff`
- `src/main.rs::maybe_handoff`：客户端侧（`--reuse-instance`）
- `src/window/application.rs::prepare_open_files`：服务端处理 `UserEvent::OpenFiles`

### 2.11 打包
- `wix/main.wxs`：Windows MSI（含右键「Open with Neovide」注册表）
- `.github/workflows/`：CI 构建各平台产物

### 2.12 Windows 原生菜单栏（CUSTOM-20261025-001）
- 数据流：nvim `:amenu` → `lua/init.lua::M.refresh_menu`（VimEnter 自动 + `:NeovideRefreshMenu`）→ `rpcnotify("neovide.set_menu", tree)` → `src/bridge/handler.rs` → `WindowCommand::SetMenu` → `src/window/window_wrapper.rs::handle_set_menu` → `src/window/menubar.rs::Menubar`（muda）
- 点击：muda `MenuEvent` → `menubar::set_event_handler`（`Application::new` 注册）→ `UserEvent::MenuCommand` → `handle_menu_command` → `ParallelCommand::MenuCommand` → `lua::neovide.private.menu_command` → `:emenu <mode> <path>`
- 关键点：
  - 菜单树在窗口创建前到达时缓存在 `RouteCore::menu`，创建窗口时挂载；已存在窗口则 `Menubar::rebuild`
  - `g:neovide_menubar`（`WindowSettings::menubar`）控制显隐；全屏与 `--frame none` 自动隐藏
  - Alt 键由 `menubar.rs::alt_filter_proc` 窗口子类拦掉 `SC_KEYMENU`/`WM_SYSCHAR`（AltGr 除外）
  - **D3D 后端无法显示系统菜单栏**（`WS_EX_NOREDIRECTIONBITMAP`），启用菜单栏时 `build_window_config` 自动改用 OpenGL，且 `create_window` 必须同步跳过 `with_no_redirection_bitmap`，否则 GL 窗口全透明
  - 菜单分隔线：nvim 侧用 `-sepN-` 占位，`lua/init.lua` 转成 `{separator=true}`
  - 「帮助.关于」：菜单 RHS 执行 `neovide_menu.lua::actions.about` → `rpcnotify("neovide.about", text)`（文本由 `M.about_text()` 组装：Neovide/Neovim 版本、系统、配置目录）→ `src/bridge/handler.rs::neovide.about` → `UserEvent::ShowAbout` → `src/window/about.rs` 用 Win32 `MessageBoxW` 弹出原生对话框（owner 为当前窗口）

### 2.13 Windows 关闭到系统托盘（CUSTOM-20261029-001）
- 开关：`g:neovide_tray`（`WindowSettings::tray`，Windows，默认 false）；只影响窗口 X/Alt+F4，不影响 nvim 内 `:qa`
- 关闭拦截：`Application::window_event` 收到 `CloseRequested` → `try_hide_to_tray`：先 `tray::Tray::create`（失败则 warn 并回退上游 `handle_quit`）→ `WinitWindowWrapper::hide_window_to_tray`（`RouteState::hidden_to_tray = true` + `Window::set_visible(false)`）
- 托盘模块：`src/window/tray.rs`（tray-icon + muda）。左键 `TrayIconEvent::Click(Left, Up)` → `UserEvent::TrayActivate`；右键菜单 ID `neovide-tray-show` / `neovide-tray-quit` 复用 `menubar::set_event_handler`（`Application::new` 注册）安装的全局 `MenuEvent` 回调 → `UserEvent::MenuCommand` → `Application::user_event`
- 恢复：`Application::show_last_hidden_window` → `show_window_from_tray`（`set_visible(true)` + 取消最小化 + `focus_window`）；`sync_tray_visibility` 在 `schedule_next_event` 开头按 `has_hidden_window()` 自动销毁图标（图标只在隐藏期间存在）
- 退出：托盘「退出」→ `handle_tray_quit`：`show_all_windows_from_tray`（让确认框可见）→ 删除托盘 → 对每个 route 调 `handle_quit`（`ParallelCommand::Quit`，保留 `confirm_quit` 确认）
- 渲染暂停：隐藏窗口在 `prepare_frame` / `draw_frame` / `request_redraw_for_window` / `get_event_deadline` 中跳过；全部窗口隐藏时 `next_control_flow` 返回 `ControlFlow::Wait`，仅由 EventLoopProxy 事件唤醒
- nvim 侧退出（`:qa`、`neovide.quit`、崩溃）不经过托盘逻辑：`NeovimExited` → route 移除 → `Application::exiting` 显式 drop 托盘
