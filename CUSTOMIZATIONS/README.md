# CUSTOMIZATIONS —— 自定义开发机制说明

本目录是本仓库（custom-neovide）所有自定义开发内容的唯一家园。规则以本文档为唯一完整版（single source of truth），根目录 `AGENTS.md` 只保留会话级硬约束摘要。

## 目录结构

```
CUSTOMIZATIONS/
├── README.md        # 本文件：机制与规则完整版（唯一规则源）
├── architecture.md  # 代码链路图谱：文件职责 / 任务→代码位置 / 重点链路（面向 AI 的加速索引）
├── registry.md      # 账本：frontmatter 元数据 + 改动总览（按文件）+ 变更日志（按次）
├── docs/
│   └── pitfalls.md  # 历史坑点沉淀：现象→根因→解法→教训（动手前先扫标题）
├── nvim/            # 本机 nvim 配置同步副本（不登记 registry）
├── release-notes/   # 各自定义版本的发布说明归档
├── src/             # 新增的自定义源码（独立模块，通过入口挂载）
├── patches/         # 对上游文件的补丁
└── scripts/         # init-repo / sync-vendor / list-custom / check-registry 等
```

核心约定：**一处规则（README.md）、一处账本（registry.md）、一份代码地图（architecture.md）、一份坑点库（docs/pitfalls.md）**。规则改动只改本文件；改动登记只写 registry.md；代码结构变化同步 architecture.md；踩坑沉淀进 docs/pitfalls.md；自定义代码优先放 src/。本机 nvim 配置（`%LOCALAPPDATA%\nvim\` 及其 `CUSTOMIZATIONS/nvim/` 同步副本）不登记 registry，见「不纳入 registry 的内容」。

## registry.md 的两层结构

| 层           | 组织方式                           | 回答什么                           | 更新方式                            |
| ------------ | ---------------------------------- | ---------------------------------- | ----------------------------------- |
| **改动总览** | 按文件（一文件一节，多轮演进合并） | "这个文件现在改了什么？冲突策略？" | 已有该文件就更新该节，演进链追加 id |
| **变更日志** | 按次（时间倒序 append-only）       | "何时/为何/怎么验证"               | 顶部追加，永不改写历史              |

总览与代码 `[CUSTOM-BEGIN]` 标记一一对应（同一文件的"当前状态"镜像），`sh CUSTOMIZATIONS/scripts/check-registry.sh` 做双向一致性自检——**每次登记后必须跑到全绿**。

## 必须遵守的铁律

1. **开发前先读 `registry.md` 的改动总览**（不必通读变更日志）：了解相关文件已有什么改动、合并时怎么处理。
2. **程序逻辑改动后必须登记**：调用 `neovide-record-change` skill（总览按文件合并更新 + 日志按次追加 + check-registry 全绿）；本机 nvim 配置除外（见下节）。
3. **变更日志只增不改**；总览条目整体废弃时标 `deprecated` 而非删除。
4. **禁止手动 git merge/rebase**：跨上游合并必须走 `neovide-merge-upstream` skill；禁止 rebase 改写 custom/main 历史。
5. **写代码前先读 `architecture.md`**：按 §0.5 任务路由只读相关文件，省上下文；改了代码结构后同步该文件。
6. **排查问题前先扫 `docs/pitfalls.md`**：新踩的坑解决后回写一条（现象→根因→解法→教训）。

## 不纳入 registry 的内容

以下内容属于用户环境配置，不是对 Neovide 程序逻辑的自定义，修改后无需 change-id，也不登记 `registry.md`：

- `%LOCALAPPDATA%\nvim\` 下的本机 nvim 配置（`init.lua`、`lua/config/*`、插件配置等）
- `CUSTOMIZATIONS/nvim/` 下的同步副本（`neovide_menu.lua`、`neovide_welcome.lua`、`keymaps.lua` 等）

这些文件的用途、依赖与注意事项记录在 `CUSTOMIZATIONS/nvim/README.md`。若改动同时涉及程序逻辑（例如 `lua/init.lua` 的 RPC、Neovide 设置名、菜单命令协议），程序逻辑部分仍按正常规则登记。

## change-id 与代码标记

每个逻辑改动分配唯一 id：`CUSTOM-YYYYMMDD-NNN`（日期+序号），不可复用（同一标记块内追加修改除外）。

修改上游文件时，改动区域必须用标记包裹，注释语法随文件语言：

```
// [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - <简要描述>   （Rust .rs / build.rs）
-- [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - <简要描述>   （Lua .lua）
# [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - <简要描述>    （TOML/YAML/Shell/PowerShell）
<!-- [CUSTOM-BEGIN] CUSTOM-YYYYMMDD-NNN - <简要描述> -->   （XML/WXS）
... 自定义代码 ...
// [CUSTOM-END] CUSTOM-YYYYMMDD-NNN
```

合并上游时：标记外的区域优先使用上游版本；`[CUSTOM-BEGIN]...[CUSTOM-END]` 块必须保留，上游重构导致位置漂移时按函数/模块名找新位置。

## 冲突策略速查

合并上游时，对冲突文件按以下策略处理（按优先级从高到低）：

| 优先级 | 条件                                    | 策略                                     |
| ------ | --------------------------------------- | ---------------------------------------- |
| 1      | 文件在 `CUSTOMIZATIONS/src/` 目录下     | `keep-ours`（保留我们的）                |
| 2      | 文件在 `CUSTOMIZATIONS/patches/` 目录下 | `keep-ours`                              |
| 3      | registry.md 条目标记 `keep-ours`        | `keep-ours`                              |
| 4      | registry.md 条目标记 `keep-theirs`      | `keep-theirs`（使用上游的）              |
| 5      | 文件是 `Cargo.lock`                     | 接受上游版本后 `cargo build` 重新生成    |
| 6      | 文件包含 `[CUSTOM-BEGIN]` 标记          | `merge-manual`（按标记块保留自定义代码） |
| 7      | 其他文件                                | `merge-manual`（AI 分析后合并）          |

- `keep-ours`：始终保留自定义版本，上游改动放弃
- `keep-theirs`：始终使用上游版本，自定义改动放弃
- `merge-manual`：需要 AI 逐块分析合并（默认）

`registry.md` 自身冲突必须人工决策后手动合并，并检查 frontmatter 合法性。本文件（README.md）策略为 `keep-ours`。

## 条目类型与状态字典

改动总览以文件为单位，不使用独立的 type 字段；纯自定义路径（`CUSTOMIZATIONS/`、`.agents/`、`AGENTS.md` 等）按 keep-ours 处理，上游文件按标记逐块合并。变更日志中的 type 字段（new-file / modified-upstream / config / asset / dependency / script）作为历史数据保留，含义不变。

状态（status）字段：

- `active`：当前生效中
- `deprecated`：已废弃/被替代
- `merged-upstream`：已被上游原生支持，无需保留
- `needs-migration`：跨大版本升级时需要适配迁移

## registry.md frontmatter 字段职责

| 字段                                                   | 更新时机                 | 负责方                  |
| ------------------------------------------------------ | ------------------------ | ----------------------- |
| `current_upstream_version` / `current_upstream_commit` | 上游合并后               | neovide-merge-upstream  |
| `vendor_branch`                                        | 上游合并后（跨版本线时） | neovide-merge-upstream  |
| `last_merge_date`                                      | 上游合并后               | neovide-merge-upstream  |
| `last_release_version` / `last_release_date`           | 发布后                   | neovide-publish         |
| `custom_version`                                       | 发布后                   | neovide-publish         |
| `upstream_remote`                                      | 首次 clone 初始化        | init-repo.ps1           |

## 辅助脚本

```bash
# 统一入口（build/check/test/run/clean/artifacts）
sh ./CUSTOMIZATIONS/scripts/manager.sh help

# 初始化仓库（首次 clone 后；仓库已初始化过则跳过）
pwsh ./CUSTOMIZATIONS/scripts/init-repo.ps1 -BaseRef upstream/main

# 查看当前自定义改动（读 registry.md 的 vendor_branch 定位基线）
pwsh ./CUSTOMIZATIONS/scripts/list-custom.ps1

# 同步 vendor 分支到指定上游 ref（tag 或 upstream/main）
pwsh ./CUSTOMIZATIONS/scripts/sync-vendor.ps1 -Ref 0.16.2 -Push

# 登记一致性自检（每次 record-change 后必须全绿）
sh ./CUSTOMIZATIONS/scripts/check-registry.sh
```

构建要点（适配 neovide 单 crate 项目）：

- 构建产物由 `cargo build --release` 产出 `target/release/neovide[.exe]`；
- Windows 安装包见 `wix/`（MSI），配合 CI（`.github/workflows/`）出 AppImage/deb/dmg/msi；
- `cargo build` 首次会通过 `build.rs` 下载 skia-safe 预编译二进制，需网络。

## 本仓库的分支模型

neovide 上游开发在 **`main`** 分支（PR 目标分支即 main，无 develop）。发布走 tag（如 `0.16.2`）。

| 分支             | 用途                            | 对应上游              |
| ---------------- | ------------------------------- | --------------------- |
| `vendor/main`    | 跟踪上游 main（开发线基线）     | upstream/main         |
| `vendor/vX.Y.x`  | 跟踪上游版本线（锚定 tag 时用） | tag（如 0.16.2）      |
| `custom/main`    | 自定义开发主分支                | 基于 vendor 分支演进  |

基线采用 **tag 锚定**（当前基线 `0.16.2`，对应 vendor 分支 `vendor/v0.16.x`），registry.md 的 `current_upstream_version` 记录 tag，`current_upstream_commit` 记录 tag 解引用后的 commit 短哈希。
