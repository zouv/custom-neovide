---
current_upstream_version: '0.16.2'
current_upstream_commit: 'd2d6ebd4ee6b8b645c9b9a3b0d5d30923509b2c0'
custom_version: '0.16.2-custom.0'
last_merge_date: '2026-10-24'
last_release_version: ''
last_release_date: ''
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
| AGENTS.md、CLAUDE.md | new-file | 无标记（纯自定义） | — | 会话级规则入口（AGENTS.md 规则 + CLAUDE.md 指路） | keep-ours | active |
| .gitignore | config | CUSTOM-20261024-001 | CUSTOM-20261024-001 | 忽略 AI 工具会话级临时目录（.claude/.zcode/.codex/.agent） | merge-manual | active |

---

## 变更日志（按次）

> 时间倒序 append-only。格式见 `neovide-record-change` skill。历史条目永不删改。

### 2026-10-24 - 项目初始化

- **功能**：建立 custom-neovide 自定义开发框架（基于 neovide 0.16.2，参考 custom-marktext 机制）
- **改动文件**：`CUSTOMIZATIONS/`（README/registry/architecture/pitfalls/scripts）、`.agents/`（neovide-* skills）、`AGENTS.md`、`CLAUDE.md`、`.gitignore`
- **详细说明**：新增自定义开发机制目录与辅助脚本，无上游代码改动；分支模型 vendor/main（开发线）+ vendor/v0.16.x（0.16.2 版本线）+ custom/main
- **验证方式**：`sh CUSTOMIZATIONS/scripts/check-registry.sh` 全绿；`git log --oneline vendor/v0.16.x..HEAD` 可见初始化提交
- **基于上游版本**：0.16.2
