---
current_upstream_version: '0.16.2'
current_upstream_commit: 'd2d6ebd4ee6b8b645c9b9a3b0d5d30923509b2c0'
custom_version: '0.16.2-custom.1'
last_merge_date: '2026-10-24'
last_release_version: '0.16.2-custom.1'
last_release_date: '2026-10-24'
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
| Cargo.toml | dependency | CUSTOM-20261024-002 | CUSTOM-20261024-002 | windows 依赖增加 Win32_UI_WindowsAndMessaging（AllowSetForegroundWindow） | merge-manual | active |
| src/ipc/handoff.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 单实例复用传输层（回环 TCP + PID endpoint 文件 + 前台授权） | merge-manual | active |
| src/main.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 启用 ipc 模块与 maybe_handoff | merge-manual | active |
| src/bridge/mod.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 导出 file-drop 队列并在 ui_attach 后标记就绪 | merge-manual | active |
| src/bridge/ui_commands.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 复用 file-drop 排队/就绪机制 | merge-manual | active |
| src/window/mod.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 启用 OpenFiles 事件 | merge-manual | active |
| src/window/application.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 处理 OpenFiles 事件（激活窗口 + 转发文件） | merge-manual | active |
| src/window/window_wrapper.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 新增 activate_and_focus_window（恢复最小化 + 抢前台） | merge-manual | active |
| src/utils/mod.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 复用 resolved_cwd / resolve_relative_path | merge-manual | active |
| src/cmd_line.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 启用 --reuse-instance / --new-window 参数 + argv_chdir | merge-manual | active |
| src/version.rs | modified-upstream | CUSTOM-20261024-002 | CUSTOM-20261024-002 | Windows 复用 release_channel | merge-manual | active |
| wix/main.wxs | config | CUSTOM-20261024-002 | CUSTOM-20261024-002 | 右键/双击打开默认加 --reuse-instance | merge-manual | active |

---

## 变更日志（按次）

> 时间倒序 append-only。格式见 `neovide-record-change` skill。历史条目永不删改。

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
