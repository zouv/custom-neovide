---
name: 'neovide-merge-upstream'
description: 'Merge upstream neovide/neovide updates into the custom repository. Invoke when user asks to sync/merge/update from upstream, upgrade to a new version, or pull upstream changes.'
---

# Neovide 上游合并 Skill

本 Skill 用于将 neovide/neovide 上游仓库的更新合并到自定义仓库中。**所有跨上游/自定义分支的合并操作必须通过本 Skill 执行，禁止手动 git merge。**

## 触发条件

- 用户说"合并上游"、"更新到最新版本"、"升级到 0.16.x"、"sync upstream"
- 需要将上游的 bugfix/新功能合入自定义版本
- 用户要求"同步原仓库"

## neovide 上游分支模型（先理解）

- 上游开发分支是 **`main`**（PR 合入目标即 main，无 develop）
- 发布走 tag（如 `0.16.2`，无 `v` 前缀）
- 本仓库对应：`vendor/main`（开发线基线，跟踪 main）与 `vendor/vX.Y.x`（锚定 tag 时可选）

## 参数收集

开始前确认以下信息（从用户输入或通过询问获取）：

1. **目标版本**：
   - `upstream/main` 最新（**默认**，跟随开发线）
   - tag（如 `0.16.2`）→ 精确版本
   - 指定 commit hash
   - 如果用户未指定，默认取 upstream/main 最新并展示待合并提交数

2. **是否需要构建验证**：默认需要，除非用户明确跳过

## 前置检查

### 1. 确认仓库状态

```bash
git branch --show-current        # 必须在 custom/main 上
git status --porcelain           # 必须干净

# 不干净时先处理（stash/commit），或：
git stash push -m "auto-stash before upstream merge $(date -Iseconds)"
```

**如果工作区不干净且无法自动 stash，必须暂停并告知用户。**

### 2. 确认 remote 配置

```bash
git remote -v
# 必须有 upstream → https://github.com/neovide/neovide
```

### 3. 读取 CUSTOMIZATIONS/registry.md

通读所有 `active` 状态的改动总览条目，特别是「冲突策略」列（完整优先级表见 `CUSTOMIZATIONS/README.md`）。这是冲突解决的依据。

### 4. 获取上游最新信息

```bash
git fetch upstream --tags
git log --oneline vendor/main..upstream/main | head -30   # 待合并提交
```

展示给用户确认规模。

---

## 流程：合并（update 型）

适用：vendor 分支同线推进（vendor/main → upstream/main 新 HEAD，或 vendor/vX.Y.x → 新 tag）。

### 1. 预检查报告

```
=== 上游合并预检查 ===
当前自定义基线：<registry.md 的 current_upstream_version>
目标上游版本：<target>
预计改动文件数：<git diff --stat vendor/<baseline> <target> 估算>
自定义改动条目数：<registry.md 总览 active 条目数>
已知冲突风险文件：<总览 modified-upstream 文件 ∩ 上游变更文件>
```

### 2. 更新 vendor 分支

```bash
git checkout vendor/main
git merge --no-edit upstream/main   # 或 <tag>
git push origin vendor/main
```

**首次锚定某版本线**（如合并 0.16.2 正式 tag 时）：`git checkout -b vendor/v0.16.x 0.16.2 && git push -u origin vendor/v0.16.x`

### 3. 合并到 custom/main

```bash
git checkout custom/main
git checkout -b merge/upstream-<version>-$(date +%Y%m%d)
git merge --no-edit vendor/main
```

### 4. 处理冲突（AI 最关键的步骤）

```bash
git diff --name-only --diff-filter=U    # 列出冲突文件
```

对每个冲突文件，按 `CUSTOMIZATIONS/README.md` 优先级表处理：

**阶段 1（自动解析）**：

- registry.md 总览条目标 `keep-ours` → `git checkout --ours <file> && git add <file>`
- 标 `keep-theirs` → `git checkout --theirs <file> && git add <file>`
- `CUSTOMIZATIONS/`、`.agents/`、`AGENTS.md` 下的纯自定义文件 → 必然 keep-ours
- 其余（含 `[CUSTOM-BEGIN]` 标记的上游文件）→ 阶段 2

**阶段 2（智能手动合并）**：

1. 读取冲突文件完整内容
2. `[CUSTOM-BEGIN]...[CUSTOM-END]` 块必须保留；标记外区域优先采用上游版本
3. 上游重构导致标记位置漂移时，按函数/模块名找新位置重放标记块
4. 用编辑工具精确清除 `<<<<<<< / ======= / >>>>>>>` 标记
5. `Cargo.lock` 冲突：接受上游版本 → `cargo build` 重新生成，**不要手编 lock**

**阶段 3（无法自动处理 → 暂停并向用户报告）**：

- 上游完全重构了被大量自定义修改的模块（标记找不到落点）
- `Cargo.toml` 复杂依赖冲突（如 skia-safe 版本线变动）
- `CUSTOMIZATIONS/registry.md` 自身冲突（人工决策）

报告格式：文件 / 原因 / 建议（两方关键差异）/ 上游改动概要 / 我们的改动概要。

### 5. 合并后验证

```bash
git diff --name-only --diff-filter=U   # 必须为空

cargo fmt --check      # 格式
cargo check            # 快速编译检查
cargo test             # 单测
```

check/test 失败必须修复（参考 registry.md 判断哪些是自定义代码需适配）。首次 build 会经 build.rs 下载 skia-safe 预编译二进制，需网络。

### 6. 更新 registry.md 并完成合并

- frontmatter：`current_upstream_version` / `current_upstream_commit` / `last_merge_date`（合并 tag 时同时更新 `vendor_branch`）
- 失效条目状态改 `needs-migration` 或 `deprecated`；已上游原生支持的改 `merged-upstream`

```bash
git add -A
git commit -m "merge(upstream): merge upstream <version> into custom/main

- Upstream version: <version>
- Merge date: <date>
- Conflicts resolved: <list>
- Custom changes preserved: <change-ids>"

git checkout custom/main
git merge --no-ff merge/upstream-<version>-<date> -m "merge(upstream): integrate upstream <version>"
git branch -d merge/upstream-<version>-<date>
git push origin custom/main vendor/main
```

---

## 跨大版本升级（结构性升级）

上游发生仓库结构重构时，merge 可能整体不可行：

1. 评估：`git diff --stat vendor/<old> <new-target>` 差异过大且总览条目多为 merge-manual 时，向用户建议 **cherry-pick 重建**：
   - 基于新 vendor 分支创建 `custom/main-v<new>`
   - `git log --oneline --reverse vendor/<old>..custom/main` 逐个 cherry-pick 自定义提交，冲突按标记块处理
   - 旧 `custom/main` 重命名为 `custom/main-v<old>-archive`，新分支顶替为 `custom/main`
2. 每个适配修复更新 registry.md 对应条目
3. 推送 `--force-with-lease`

---

## 合并后收尾

1. 输出合并报告：目标版本 / 冲突文件数 / 自动·手动解决数 / 需人工决策数 / 构建验证结果 / active 条目保留数 / 推送状态
2. 运行测试：`cargo test`
3. 若 custom 版本已发布过，提醒用户本次合并后需要 bump 自定义版本号发布

## 紧急回滚

```bash
git reflog show custom/main     # 找合并前 commit
git reset --hard <commit-before-merge>
git push origin custom/main --force-with-lease
```

## 重要约束

1. **永远不要在 custom/main 上直接 merge**：必须经临时 `merge/upstream-*` 分支
2. **永远不要用 rebase 处理上游合并**：会改写自定义历史，破坏 CUSTOMIZATIONS/registry.md 的追踪
3. **vendor 分支上不做任何自定义修改**：只接受来自 upstream 的 merge
4. **Cargo.lock 冲突**：接受上游后重新 `cargo build`，不手编
5. **不删除 CUSTOMIZATIONS/registry.md 中的任何历史条目**：跨版本升级时需要参考所有历史改动
6. **本 skill 各步骤中的 commit / push 仅在用户明确发起合并请求时执行**——合并流程本身就是用户触发的操作，流程内按步骤提交推送是预期行为；但流程中止（冲突需要人工决策、验证失败）时停在未提交状态，先报告再等指示
