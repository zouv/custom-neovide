---
name: 'neovide-publish'
description: 'Publish the custom neovide build to GitHub Releases (version bump, release notes, commit, tag, push, wait for CI, verify assets). Invoke when user asks to publish/upload a release to GitHub, cut a new version, or create a GitHub Release.'
---

# Neovide 发布到 GitHub Skill

把**已定好的版本**发布到 GitHub Releases。本 skill 覆盖「版本号 → release 上线」这一段。

## 与 neovide-release 的分工

| Skill                      | 职责                           | 起点 → 终点                                        |
| -------------------------- | ------------------------------ | -------------------------------------------------- |
| `neovide-release`          | 从源码到**本地二进制**         | 干净工作区 → `target/release/neovide[.exe]`        |
| **`neovide-publish`（本）**| 从版本号到 **GitHub Release**  | 版本号 + release notes → release 上线（全平台 CI） |

**默认不需要本地打包**：推 tag 后上游 CI（`.github/workflows/`）全平台构建（AppImage/deb/dmg/msi），本 skill 等它跑完并核验资产。

## 快速路径

```bash
# 0) 定版本号：读已有 tag 取最大序号 +1
git tag -l "*-custom.*" --sort=-v:refname | head -5

# 1) 改版本号（Cargo.toml 两处）+ 写 release notes + 改 registry frontmatter（见执行流程 1、2 步）

# 2) 提交 + 打 annotated tag + 推送
git add Cargo.toml Cargo.lock CUSTOMIZATIONS/registry.md \
        CUSTOMIZATIONS/release-notes/0.16.2-custom.N.md
git commit -m "chore(release): bump version to 0.16.2-custom.N"
git tag -a 0.16.2-custom.N -m "Release 0.16.2-custom.N

Based on upstream neovide 0.16.2"
git push origin custom/main
git push origin 0.16.2-custom.N        # ← 触发 CI 全平台构建

# 3) 等 CI 跑完 → 核验资产
gh release view 0.16.2-custom.N --repo zouv/custom-neovide
```

## 前置检查

```bash
git branch --show-current      # 必须是 custom/main
git status --porcelain         # 必须干净
cargo --version
```

## 执行流程

### 第一步：定版本号并更新

格式 `<上游版本>-custom.N`（无 `v` 前缀，与 neovide 上游 tag 风格一致），N 从已有 tag 的最大序号 +1。neovide 版本号在 **`Cargo.toml`** 两处：

```toml
[package]
version = "0.16.2-custom.N"

[package.metadata.bundle]
version = "0.16.2-custom.N"
```

改完后 `cargo check` 让 `Cargo.lock` 同步版本号（或手动 `cargo update -p neovide`）。

### 第二步：更新 registry frontmatter + 写 release notes

`CUSTOMIZATIONS/registry.md` 头部三个字段：

```yaml
custom_version: '0.16.2-custom.N'
last_release_version: '0.16.2-custom.N'
last_release_date: 'YYYY-MM-DD'
```

release notes 写到 `CUSTOMIZATIONS/release-notes/0.16.2-custom.N.md`。

### 第三步：发布前检查

```bash
cargo fmt --check
cargo check
cargo test
```

必须全绿才能继续。

### 第四步：提交 + 打 tag + 推送

```bash
git add -A
git commit -m "chore(release): bump version to 0.16.2-custom.N"
git tag -a 0.16.2-custom.N -m "Release 0.16.2-custom.N"
git push origin custom/main
git push origin 0.16.2-custom.N
```

### 第五步：等 CI 并核验

```bash
gh run list --repo zouv/custom-neovide --limit 5
gh release view 0.16.2-custom.N --repo zouv/custom-neovide
```

核验资产齐全（Windows msi、macOS dmg、Linux AppImage/deb），并把 release 正文整理为 release notes（若 CI 模板覆盖）。

## 重要约束

1. 版本号不带 `v` 前缀（与上游 neovide tag 一致）；tag 用 annotated tag
2. 发布前 `cargo test` 必须通过
3. 不删历史 release notes；`registry.md` 历史条目不改写
4. push / release 仅在用户明确发起发布请求时执行
