# Development Rules

> 本文件分两部分：**第一部分**是本仓库（custom-neovide）的会话级硬约束与自定义开发规则，必须遵守；**第二部分**是上游 neovide 的架构与开发说明，随上游合并更新，**不要按自定义需求改写**。

---

# 第一部分：custom-neovide 自定义开发规则

## 项目概述

本项目是基于 neovide/neovide 的自定义二次开发版本（custom-neovide）。AI Agent 在本仓库工作时，必须严格遵循以下规则。

## 必读文件（开始任何任务前）

1. **CUSTOMIZATIONS/README.md**——自定义开发机制的完整规则（冲突策略、标记格式、frontmatter 职责）
2. **CUSTOMIZATIONS/registry.md**——自定义改动登记账本（开发前读「改动总览」节）
3. **本文件「第二部分」**——上游维护的架构说明（Rust 模块布局、构建注意事项；勿修改）

## 工作流（写代码 / 排查问题前）

1. **先读 `CUSTOMIZATIONS/architecture.md`**：按 §0.5 任务作用域路由表确定该读哪些文件、忽略哪些；按 §2 任务→代码位置表定位。图谱过期时以代码为准并顺手订正。
2. **排查 bug 前先扫 `CUSTOMIZATIONS/docs/pitfalls.md` 标题**：历史坑点避免重复踩；解决新坑后回写一条。
3. 上游文件改动区域必须用 `[CUSTOM-BEGIN]/[CUSTOM-END]` 标记包裹（注释语法随文件：`.rs` 用 `//`、`.lua` 用 `--`、`.toml`/`.sh`/`.ps1` 用 `#`、`.wxs` 用 `<!-- -->`）。

## 技术栈

- Rust（edition 2024）单 crate + `neovide-derive` 子 crate（workspace）
- GUI：winit + glutin + skia-safe（D3D12/Metal/OpenGL 后端）
- RPC：nvim-rs + tokio（连接 nvim 进程）
- 文本整形：swash；设置：serde + toml
- 测试：cargo test（内联 `#[cfg(test)]`）
- 协议：MIT

## 构建命令（全部在仓库根执行）

```bash
cargo build --release   # 构建（首次经 build.rs 下载 skia-safe 预编译二进制，需网络）
cargo check             # 快速编译检查
cargo test              # 单测
cargo fmt --check       # 格式检查
cargo clippy --all-targets --all-features   # lint
cargo run               # 开发模式
```

## Git 分支规则

| 分支             | 用途                                          | 谁可以写入                             |
| ---------------- | --------------------------------------------- | -------------------------------------- |
| `upstream/main`  | 跟踪上游 neovide/neovide（PR 合入 main）      | 只读（仅 fetch）                       |
| `vendor/main`    | 上游版本基线（开发线）                        | 只读（仅 merge-upstream skill 可更新） |
| `vendor/vX.Y.x`  | 上游版本线分支（锚定 tag 时用）               | 只读（同上）                           |
| `custom/main`    | 自定义开发主分支                              | AI Agent 开发合并                      |
| `feature/<name>` | 功能开发分支                                  | AI Agent 临时分支                      |

- **remote**：`origin` → https://github.com/zouv/custom-neovide；`upstream` → https://github.com/neovide/neovide
- **禁止操作**：
  - **禁止未经用户明确指示 commit / push**：完成改动后只汇报结果（改了什么、验证情况），由用户决定何时提交；用户明确说"提交"/"commit"/"push"时才执行
  - 禁止手动 `git merge` 合并 vendor 到 custom/main（必须通过 `neovide-merge-upstream` skill）
  - 禁止 `git rebase` 改写 custom/main 的历史
  - 禁止直接 push 到 vendor 分支

## 自定义代码规范（硬约束）

1. **代码隔离优先**：新功能尽量放在 `CUSTOMIZATIONS/src/` 下，通过独立模块挂载
2. **修改上游文件时必须加标记**：
   ```
   // [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - 描述
   ... 自定义代码 ...
   // [CUSTOM-END] CUSTOM-YYYYMMDD-NNN
   ```
3. **每次改动必须记录**：完成后调用 `neovide-record-change` skill 更新 CUSTOMIZATIONS/registry.md
4. **不要删除 registry.md 中的历史条目**（标记 deprecated 即可）
5. **合并冲突**：按 CUSTOMIZATIONS/README.md 的冲突策略速查处理
6. **合并上游完成后、发布前**必须运行 `cargo fmt --check && cargo check && cargo test`

## AI Skills 触发条件

Skill 定义位于 `.agents/skills/`（跨工具共享的工作区级标准路径）。

| Skill                     | 何时调用                                                                |
| ------------------------- | ----------------------------------------------------------------------- |
| `neovide-record-change`   | 完成任何自定义功能/修改后                                               |
| `neovide-merge-upstream`  | 用户要求合并上游/升级版本/同步原仓库时                                  |
| `neovide-release`         | 用户要求打包/build 时（本地构建二进制）                                 |
| `neovide-publish`         | 用户要求发布/上传 release/打 tag/推 release 到 GitHub 时                |

详细触发场景见各 skill 的 `.agents/skills/<name>/SKILL.md`。

## 项目结构速查

```
src/                        # 主 crate（bridge/editor/renderer/window/settings/clipboard/cmd_line/ipc/...）
lua/init.lua                # 注入 nvim 的初始化脚本（neovide.* RPC、设置同步）
neovide-derive/             # proc-macro 子 crate（SettingGroup 等 derive）
wix/                        # Windows MSI 安装包
CUSTOMIZATIONS/             # 自定义开发内容（规则、账本、代码地图、坑点库、代码、脚本）
├── README.md               # 机制与规则唯一完整版
├── architecture.md         # 代码链路图谱（AI 加速索引）
├── registry.md             # 改动登记账本
├── docs/pitfalls.md        # 历史坑点沉淀
├── release-notes/
├── src/ patches/ scripts/
.agents/skills/             # AI Agent 项目级 skills（4 个）
CLAUDE.md                   # 一行指路文件（@AGENTS.md），供 Claude Code 自动加载本文件
```

## 文档更新职责（改完代码必须同步）

| 改动类型                       | 更新哪里                                                            |
| ------------------------------ | ------------------------------------------------------------------- |
| 任何自定义功能/修改            | `CUSTOMIZATIONS/registry.md`（record-change skill）                 |
| 新增/移动函数、改数据流或接口  | `CUSTOMIZATIONS/architecture.md`（§0.5 路由表 / §1 链路 / §2 模块） |
| 解决了一个反复折腾才定位的问题 | `CUSTOMIZATIONS/docs/pitfalls.md`（现象→根因→解法→教训）            |
| 机制/规则变更                  | `CUSTOMIZATIONS/README.md`                                          |

## 代码风格

- 遵循现有代码风格（rustfmt.toml）；提交前 `cargo fmt --check`
- 自定义代码区的注释用中文，标记块注释除外（change-id 描述可用中文）

---

# 第二部分：上游架构与开发说明（neovide upstream）

## Project Overview

Neovide 是 Neovim 的图形前端（GUI），用 Rust 编写。它不实现编辑功能，而是启动/连接 `nvim` 进程作为 UI 客户端：经 msgpack-RPC 接收 redraw 事件，用 Skia 在 GPU 上绘制，并回传键盘/鼠标输入。

- **Version**: 见 `Cargo.toml`
- **License**: MIT
- **Repository**: <https://github.com/neovide/neovide>

## Tech Stack

| Layer         | Technology                                                    |
| ------------- | ------------------------------------------------------------- |
| Language      | Rust (edition 2024)                                           |
| Window/Event  | winit 0.30 + glutin 0.32                                      |
| Rendering     | skia-safe（D3D12 / Metal / OpenGL 后端）                      |
| Text shaping  | swash                                                         |
| RPC           | nvim-rs + tokio（msgpack）                                    |
| Settings      | serde + toml（config.toml）+ neovim 全局变量（g:neovide_*）   |

## Directory Structure

```
src/
  main.rs      入口：panic hook、日志、事件循环装配（含 200+ 行架构注释）
  bridge/      nvim 生命周期 + RPC（handler/session/setup/ui_commands/events）
  editor/      RedrawEvent → DrawCommand（grid/cursor/draw_command_batcher）
  renderer/    Skia 绘制（rendered_window 行缓存、fonts、cursor_renderer、vsync）
  window/      winit 事件循环、窗口、输入（application/window_wrapper/mouse/keyboard）
  settings/    设置系统（live 更新、config.toml 热重载）
  clipboard.rs 剪贴板抽象
  cmd_line.rs  CLI 参数（clap）
  ipc/         macOS 单实例复用（handoff）
  profiling/   Tracy 埋点（feature 门控）
  utils/       通用工具
lua/init.lua   注入 nvim 的初始化脚本
neovide-derive/ proc-macro 子 crate
wix/           Windows MSI
```

详细代码地图见 `CUSTOMIZATIONS/architecture.md`。
