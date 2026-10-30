---
current_upstream_version: '0.16.2'
current_upstream_commit: 'd2d6ebd4ee6b8b645c9b9a3b0d5d30923509b2c0'
custom_version: '0.16.2-custom.3'
last_merge_date: '2026-10-24'
last_release_version: '0.16.2-custom.3'
last_release_date: '2026-10-29'
vendor_branch: 'vendor/v0.16.x'
upstream_remote: 'https://github.com/neovide/neovide.git'
---

# Neovide 自定义改动登记

> **本文件是改动登记账本（纯数据）**。机制与规则（冲突策略、标记格式、类型/状态字典、frontmatter 字段职责）见 [`CUSTOMIZATIONS/README.md`](./README.md)。
>
> **两层结构（怎么用）**：
>
> - **改动总览（按文件）**——查"某个文件现在改了什么、上游合并时怎么处理"：**只读这一节**，每个文件一条，多轮演进已合并为当前状态，无需读历史轮次。
> - **变更日志（按次）**——查"某次改动何时发生、为什么、怎么验证"：按时间倒序的 append-only 流水，只增不改（历史是事实）。
>
> **AI Agent 注意**：
>
> 1. 开发前读**改动总览**定位相关文件与冲突策略（不必通读变更日志）
> 2. 完成改动后调用 `neovide-record-change` skill：**总览里已有该文件就更新那一节**（合并描述、追加演进链 id），没有就新增一节；变更日志追加一轮记录
> 3. 合并上游时按总览的冲突策略列处理
> 4. 不要删除历史（总览条目整体废弃时标 deprecated，变更日志永不删改）
> 5. 一致性自检：`sh CUSTOMIZATIONS/scripts/check-registry.sh`（代码标记 ↔ 总览表双向比对）

---

## 仓库信息

- **上游仓库**：https://github.com/neovide/neovide
- **当前基于上游版本**：{{current_upstream_version}}
- **当前基于上游 Commit**：{{current_upstream_commit}}
- **当前 Vendor 分支**：{{vendor_branch}}
- **最近一次上游合并**：{{last_merge_date}}
- **最近一次发布版本**：{{last_release_version}} ({{last_release_date}})

---

## 改动总览（按文件）

> **每个文件一条**：该文件当前生效的全部自定义改动（多轮演进已合并）；「标记」列为代码中 `[CUSTOM-BEGIN]` 的 change-id（即该文件自定义区的当前真相），演进链标注历轮 id。代码位置速查见 [`architecture.md`](./architecture.md) §1。
>
> **状态字典**：`active`（生效中）/ `deprecated`（已废弃）/ `merged-upstream`（上游已原生支持）。**冲突策略**字典见 README.md。

| 文件 | 改动类型 | 标记（change-id） | 演进链 | 当前效果（一句话） | 冲突策略 | 状态 |
| ---- | -------- | ----------------- | ------ | ------------------ | -------- | ---- |
| CUSTOMIZATIONS/（README.md、architecture.md、registry.md、docs/pitfalls.md、scripts/、src/、patches/、release-notes/） | new-file | 无标记（纯自定义） | — | 自定义开发机制完整目录（规则/账本/代码地图/坑点库/脚本） | keep-ours | active |
| .agents/（skills/neovide-record-change、neovide-merge-upstream、neovide-publish、neovide-release） | new-file | 无标记（纯自定义） | — | AI Agent 项目级 skills（4 个） | keep-ours | active |
| AGENTS.md、CLAUDE.md、.gitattributes | new-file | 无标记（纯自定义） | — | 会话级规则入口 + 行尾规范化（.bat CRLF / .sh LF） | keep-ours | active |
| .gitignore | config | CUSTOM-20261024-001、CUSTOM-20261024-003 | CUSTOM-20261024-001→003 | 忽略 AI 工具会话级临时目录 + 本地打包产物 dist/ | merge-manual | active |
| Cargo.toml | dependency | CUSTOM-20261024-002、CUSTOM-20261025-001、CUSTOM-20261029-001 | CUSTOM-20261024-002→20261025-001→20261029-001 | windows 依赖增加 Win32_UI_WindowsAndMessaging（AllowSetForegroundWindow）、Win32_UI_Shell / KeyboardAndMouse（菜单栏子类化），引入 muda 与 tray-icon | merge-manual | active |
| src/ipc/handoff.rs | modified-upstream | CUSTOM-20261024-002、CUSTOM-20261029-005 | CUSTOM-20261024-002→20261029-005 | Windows 单实例复用传输层（回环 TCP + PID endpoint 文件 + 前台授权）；空请求也转发用于恢复隐藏窗口；客户端校验服务端版本 | merge-manual | active |
| src/main.rs | modified-upstream | CUSTOM-20261024-002、CUSTOM-20261029-005 | CUSTOM-20261024-002→20261029-005 | Windows 启用 ipc 模块与 maybe_handoff；默认尝试单例 handoff，失败仅告警并继续启动，`--new-instance` 可跳过 | merge-manual | active |
| src/bridge/mod.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 导出 file-drop 队列并在 ui_attach 后标记就绪 | merge-manual | active |
| src/bridge/ui_commands.rs | modified-upstream | CUSTOM-20261024-002、CUSTOM-20261025-001 | CUSTOM-20261024-002→20261025-001 | Windows 复用 file-drop 排队/就绪机制；新增 MenuCommand 执行 `:emenu` | merge-manual | active |
| src/bridge/handler.rs | modified-upstream | CUSTOM-20261025-001、CUSTOM-20261029-003 | CUSTOM-20261025-001→20261029-003 | 接收 `neovide.set_menu` 通知，解析菜单树并下发 SetMenu 窗口命令；接收 `neovide.about` 通知并转发 ShowAbout | merge-manual | active |
| src/window/mod.rs | modified-upstream | CUSTOM-20261024-002、CUSTOM-20261025-001、CUSTOM-20261029-001、CUSTOM-20261029-003 | CUSTOM-20261024-002→20261025-001→20261029-001→20261029-003 | Windows 启用 OpenFiles 事件；新增 menubar / tray / about 模块、WindowCommand::SetMenu、UserEvent::MenuCommand / TrayActivate / ShowAbout；菜单栏启用时跳过 NOREDIRECTIONBITMAP | merge-manual | active |
| src/window/application.rs | modified-upstream | CUSTOM-20261024-002、CUSTOM-20261025-001、CUSTOM-20261029-001、CUSTOM-20261029-003、CUSTOM-20261029-005 | CUSTOM-20261024-002→20261025-001→20261029-001→20261029-003→20261029-005 | Windows 处理 OpenFiles 事件（激活窗口 + 转发文件）；注册 muda 全局菜单事件处理器；CloseRequested 隐藏到托盘、托盘图标生命周期与托盘退出；ShowAbout 弹出原生关于对话框；单例唤醒恢复最近隐藏窗口 | merge-manual | active |
| src/window/window_wrapper.rs | modified-upstream | CUSTOM-20261024-002、CUSTOM-20261025-001、CUSTOM-20261029-001 | CUSTOM-20261024-002→20261025-001→20261029-001 | Windows 新增 activate_and_focus_window（恢复最小化 + 抢前台）；菜单栏挂载/重建/显隐/主题与点击转发；托盘隐藏状态、恢复/全部恢复、隐藏窗口跳过渲染调度 | merge-manual | active |
| src/window/menubar.rs | new-file | CUSTOM-20261025-001 | CUSTOM-20261025-001 | Windows 原生菜单栏（muda 菜单树、Alt 键过滤子类、主题） | keep-ours | active |
| src/window/tray.rs | new-file | CUSTOM-20261029-001 | CUSTOM-20261029-001 | Windows 系统托盘（tray-icon：图标、右键菜单、左键恢复事件；与菜单栏共用 muda 事件） | keep-ours | active |
| src/window/about.rs | new-file | CUSTOM-20261029-003 | CUSTOM-20261029-003 | Windows 原生「关于 Neovide」对话框（Win32 MessageBoxW，内容由 nvim 侧组装） | keep-ours | active |
| src/window/settings.rs | modified-upstream | CUSTOM-20261025-001、CUSTOM-20261029-001 | CUSTOM-20261025-001→20261029-001 | 新增 g:neovide_menubar（Windows，默认 false）、g:neovide_tray（Windows，默认 false） | merge-manual | active |
| src/renderer/mod.rs | modified-upstream | CUSTOM-20261025-001 | CUSTOM-20261025-001 | Windows 启用菜单栏时强制走 OpenGL（D3D 的 NOREDIRECTIONBITMAP 让原生菜单栏不可见） | merge-manual | active |
| lua/init.lua | modified-upstream | CUSTOM-20261025-001 | CUSTOM-20261025-001 | 菜单树采集/发送（neovide.refresh_menu）、点击执行（:emenu）、启动后自动刷新 | merge-manual | active |
| src/utils/mod.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 复用 resolved_cwd / resolve_relative_path | merge-manual | active |
| src/cmd_line.rs | modified-upstream | CUSTOM-20261024-002、CUSTOM-20261029-005 | CUSTOM-20261024-002→20261029-005 | Windows 启用 --reuse-instance / --new-window 参数 + argv_chdir；新增 --new-instance/--no-single-instance，--new-window 不再要求 --reuse-instance | merge-manual | active |
| src/version.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 复用 release_channel | merge-manual | active |
| wix/main.wxs | config | CUSTOM-20261024-002 | CUSTOM-20261024-002 | 右键/双击打开默认加 --reuse-instance | merge-manual | active |

---

## 变更日志（按次）

> 时间倒序 append-only。格式见 `neovide-record-change` skill。历史条目永不删改。

### 2026-10-29 - CUSTOM-20261029-005

- **功能**：默认单例运行——再次启动 Neovide 时复用已有进程并恢复窗口（含托盘隐藏状态）
- **改动文件**：`src/main.rs`、`src/ipc/handoff.rs`、`src/cmd_line.rs`、`src/window/application.rs`
- **详细说明**：`maybe_handoff` 不再要求 `--reuse-instance`，每次启动都尝试 handoff；`--new-instance`（别名 `--no-single-instance`）可显式启动独立进程，`--server`/`--wsl` 自动跳过。`handle_request` 对空请求也转发 `UserEvent::OpenFiles`，服务端 `prepare_open_files` 在无文件时调用 `activate_focused_route`，恢复托盘隐藏窗口或把已有窗口切到前台。`activate_focused_route` 在选择窗口时增加 `last_hidden_window()` 兜底，覆盖多窗口全部隐藏的情况。客户端通过响应中的 `BUILD_VERSION` 识别旧版本服务端：纯激活请求遇到版本不一致时启动新实例（旧服务端不会恢复窗口，静默退出不可接受）；带文件/`--new-window` 的请求仍交给已有实例。handoff 被拒绝或失败不再阻止启动，只记录 warn。`--new-window` 不再要求 `--reuse-instance`。
- **验证方式**：`cargo fmt --check`/`check`/`test`（171 passed，含 Windows 上新增的 CLI 用例）；GUI 实测：A 隐藏到托盘后启动 B（无参数）→ B 退出、A 窗口恢复且托盘移除；C 加 `--new-instance` → 独立进程存活；D 带文件启动 → D 退出、A 标题变为该文件；E 在 clean 版 `0.16.2-custom.3` 实例运行时启动 `0.16.2-custom.3-dirty` 调试版 → 版本不一致检测生效，E 正常新开实例而非静默退出。测试期间临时移走 IPC endpoint 并在结束后按原内容恢复（`{"port":64955,"pid":35368}`）。
- **基于上游版本**：0.16.2

### 2026-10-29 - CUSTOM-20261029-003

- **功能**：菜单栏「帮助」新增「关于」，点击弹出原生对话框显示当前版本等应用信息
- **改动文件**：`src/window/about.rs`（新增）、`src/window/mod.rs`、`src/window/application.rs`、`src/bridge/handler.rs`、`CUSTOMIZATIONS/nvim/neovide_menu.lua`（本机同步到 `%LOCALAPPDATA%\nvim\lua\config\`）
- **详细说明**：nvim 侧 `neovide_menu.lua` 增加「帮助.关于」菜单项和 `about` action；`M.about_text()` 组装 Neovide 版本、Neovim 版本、系统与配置目录，点击后通过 `rpcnotify(neovide_channel_id, "neovide.about", text)` 发给 Neovide。Rust 侧 `bridge/handler.rs` 新增 `neovide.about` 通知分支 → `UserEvent::ShowAbout` → `src/window/about.rs` 用 Win32 `MessageBoxW` 弹出原生对话框（owner 为当前窗口）。信息由 nvim 侧组装，Neovim 版本天然准确；Neovide 版本取自 `vim.g.neovide_version`（Rust `BUILD_VERSION`，含 git describe，工作区未提交时带 `-dirty`）。
- **验证方式**：`cargo fmt --check`/`check`/`test`（167 passed）；headless nvim 验证 `menu_get('帮助')` 含「关于」且 `about_text()` 输出 `Neovide 0.16.2-custom.2 / Neovim 0.12.2 / Windows_NT 10.0.19045 (x86_64) / 配置目录`；GUI 实测用 Win32 `WM_COMMAND` 触发菜单项（id 1034），出现 `#32770` 对话框「关于 Neovide」，正文含版本与 Neovim 信息，`WM_CLOSE` 可关闭。测试期间本机已有 Neovide 会话，新实例检测到现有 IPC listener 后跳过监听，未覆盖 endpoint。
- **基于上游版本**：0.16.2

### 2026-10-29 - CUSTOM-20261029-001

- **功能**：Windows 关闭窗口后隐藏到系统托盘（可选，默认关闭）
- **改动文件**：`src/window/tray.rs`（新增）、`src/window/application.rs`、`src/window/window_wrapper.rs`、`src/window/mod.rs`、`src/window/settings.rs`、`Cargo.toml`
- **详细说明**：新增 `g:neovide_tray`（Windows，默认 false）。启用后点击窗口 X / Alt+F4 时先惰性创建 tray-icon 托盘（0.26.1，与现有 muda 0.21 共用菜单事件），**创建成功才隐藏窗口**（`RouteState::hidden_to_tray` + `set_visible(false)`），nvim/Route/VSync 全部保留；托盘左键或右键菜单「显示窗口」恢复窗口并销毁图标（图标只在隐藏期间存在）；右键「退出 Neovide」先恢复所有窗口（保证 nvim 未保存确认框可见）再对每个 route 发送 `ParallelCommand::Quit`。隐藏窗口在 `prepare_frame`/`draw_frame`/`request_redraw_for_window`/deadline 计算中全部跳过，全部隐藏时 `ControlFlow::Wait`，避免事件循环空转。托盘创建失败时回退为上游正常关闭退出，避免窗口隐藏后无法恢复。`g:neovide_tray` 默认 false 保证升级后行为不变；`:qa`/`:qa!`、`neovide.quit` 与 nvim 崩溃仍按原链路退出，退出时显式 drop 托盘。
- **验证方式**：`cargo fmt --check`、`cargo check`、`cargo clippy --all-targets --all-features`、`cargo test`（167 passed）；GUI 实测（PowerShell 驱动 Win32 API，按类名 `Window Class` 定位主窗口）：默认关闭时 X 正常退出；启用后 X 隐藏且进程存活、`tray_icon_app` 托盘窗口存在、隐藏 4 秒 CPU 增量 0.000 秒；模拟托盘左键窗口恢复且托盘移除；模拟托盘菜单 Show/Quit 均生效（Quit 后进程退出）；隐藏时结束 nvim 子进程，应用正确退出。
- **基于上游版本**：0.16.2

### 2026-10-26 - CUSTOM-20261026-001

- **功能**：修复菜单栏启用后窗口全透明、以及「最后一个窗口上 `:q` 仍直接退出」两个问题
- **改动文件**：`src/window/mod.rs`、`CUSTOMIZATIONS/nvim/neovide_welcome.lua`（本机同步到 `%LOCALAPPDATA%\nvim\lua\config\`）
- **详细说明**：① 菜单栏启用时渲染器切到 OpenGL，但 `create_window` 仍按 `!cmd_line.opengl` 给窗口加 `WS_EX_NOREDIRECTIONBITMAP`，窗口没有 GDI 重定向表面 → OpenGL 画面无处落地、整窗透明；改为菜单栏启用时同样跳过该标志。② `QuitPre` 守卫用 `nvim_list_wins()` 判断“最后一个窗口”，noice 的命令行/通知浮窗让计数变成 3 而放行；改为只统计当前 tabpage 的非浮动窗口，删除缓冲区路径也改用 `current_normal_window()` 定位目标窗口。
- **验证方式**：GUI 实测 `:q` 后窗口保留并显示 LazyVim dashboard、菜单复制正常；无界面回归 `:q` 保持存活（124）、`:qa` 退出（0）、删最后一个 buffer 后 filetype=snacks_dashboard；`cargo fmt --check`/`check`/`clippy`/`test`（167 passed）通过
- **基于上游版本**：0.16.2

### 2026-10-25 - CUSTOM-20261025-001

- **功能**：Windows 原生菜单栏——Neovide 渲染菜单，内容与行为全部由 nvim `:amenu` 定义
- **改动文件**：`src/window/menubar.rs`（新增）、`src/window/mod.rs`、`src/window/window_wrapper.rs`、`src/window/settings.rs`、`src/window/application.rs`、`src/bridge/handler.rs`、`src/bridge/ui_commands.rs`、`src/renderer/mod.rs`、`lua/init.lua`、`Cargo.toml`
- **详细说明**：`lua/init.lua` 在 VimEnter 后调用 `menu_get("")` 并 rpcnotify `neovide.set_menu`；Rust 侧解析成 `MenuEntry` 树，用 muda `init_for_hwnd_with_theme` 挂到窗口（每个 RouteWindow 一个 Menubar）；点击菜单项经 `MenuEvent` → winit proxy → `ParallelCommand::MenuCommand` → `:emenu <当前模式> <路径>`。新增 `g:neovide_menubar`（Windows，默认 false）；全屏、`--frame none` 时自动隐藏；主题跟随窗口。用自定义窗口子类屏蔽 `SC_KEYMENU` 与 Alt 组合键的 mnemonic，确保 Alt 键全部交给 nvim（AltGr 例外）。**D3D 渲染器使用 `CreateSwapChainForComposition` + `WS_EX_NOREDIRECTIONBITMAP`，窗口没有 GDI 重定向表面，系统菜单栏不可见，因此启用菜单栏时自动改用 OpenGL 渲染器，并在 `create_window` 中同步跳过 `with_no_redirection_bitmap`（否则 OpenGL 窗口会全透明）。**
- **验证方式**：`cargo fmt --check`、`cargo check`、`cargo clippy --all-targets --all-features` 通过；nvim 侧 `emenu` 实测；GUI 实测待补
- **基于上游版本**：0.16.2

### 2026-10-24 - CUSTOM-20261024-004

- **功能**：新增文件关联注册脚本（双击运行，换路径后快速重注册）
- **改动文件**：`CUSTOMIZATIONS/scripts/register-file-assoc.bat`、`CUSTOMIZATIONS/scripts/build-unpacked.bat`、`.gitattributes`
- **详细说明**：新增 `register-file-assoc.bat`——把脚本同目录的 neovide.exe 注册为打开命令（带 `--reuse-instance`），注册前检测旧关联并提示是否替换；`build-unpacked.bat` 打包时把它一并拷贝到 `dist/win-unpacked/`；新增 `.gitattributes` 规范行尾（.bat/.ps1 CRLF、.sh LF），并把三个 .bat 转为 CRLF（否则 cmd 解析报错）。
- **验证方式**：双击路径实测——检测旧关联/取消/替换三条路径均正常；`reg query` 确认注册值正确
- **基于上游版本**：0.16.2

### 2026-10-24 - CUSTOM-20261024-003

- **功能**：新增 Windows bat 打包脚本（unpacked 便携包 + MSI 安装包）
- **改动文件**：`CUSTOMIZATIONS/scripts/build-unpacked.bat`、`CUSTOMIZATIONS/scripts/build-setup.bat`、`CUSTOMIZATIONS/scripts/manager.sh`
- **详细说明**：参考 custom-marktext 脚本结构，适配 neovide（cargo build --release + cargo wix）。unpacked 拷贝 `target/release/neovide.exe` 到 `dist/win-unpacked/`；setup 用 `cargo wix` 打 `neovide-<版本>.msi` 并拷贝到 `dist/`；均含杀软锁文件 15s 退避重试。manager.sh 新增 `unpacked`/`setup` 命令。
- **验证方式**：`sh CUSTOMIZATIONS/scripts/manager.sh unpacked` 产出 `dist/win-unpacked/neovide.exe`；`sh CUSTOMIZATIONS/scripts/manager.sh help` 显示新命令
- **基于上游版本**：0.16.2

### 2026-10-24 - CUSTOM-20261024-002

- **功能**：Windows 支持 `--reuse-instance`（双击文件在已运行的同一 GUI 实例中打开）
- **改动文件**：`src/ipc/handoff.rs`、`src/main.rs`、`src/bridge/mod.rs`、`src/bridge/ui_commands.rs`、`src/window/mod.rs`、`src/window/application.rs`、`src/window/window_wrapper.rs`、`src/utils/mod.rs`、`src/cmd_line.rs`、`src/version.rs`、`Cargo.toml`、`wix/main.wxs`
- **详细说明**：把 macOS 已有的单实例复用机制移植到 Windows——传输层用回环 TCP（127.0.0.1 随机端口 + endpoint 文件记录端口与 PID）替代 unix socket；双击的客户端进程读 endpoint 文件后 `AllowSetForegroundWindow(服务端 PID)` 授权服务端抢回前台；`wix` 文件关联命令默认加 `--reuse-instance`。macOS/Linux 行为不变。
- **验证方式**：`cargo fmt --check` 通过；`cargo check`（见构建日志）；`sh CUSTOMIZATIONS/scripts/check-registry.sh` 全绿
- **基于上游版本**：0.16.2

### 2026-10-24 - 项目初始化

- **功能**：建立 custom-neovide 自定义开发框架（基于 neovide 0.16.2，参考 custom-marktext 机制）
- **改动文件**：`CUSTOMIZATIONS/`（README/registry/architecture/pitfalls/scripts）、`.agents/`（neovide-* skills）、`AGENTS.md`、`CLAUDE.md`、`.gitignore`
- **详细说明**：新增自定义开发机制目录与辅助脚本，无上游代码改动；分支模型 vendor/main（开发线）+ vendor/v0.16.x（0.16.2 版本线）+ custom/main
- **验证方式**：`sh CUSTOMIZATIONS/scripts/check-registry.sh` 全绿；`git log --oneline vendor/v0.16.x..HEAD` 可见初始化提交
- **基于上游版本**：0.16.2
