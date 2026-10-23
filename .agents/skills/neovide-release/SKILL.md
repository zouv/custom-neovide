---
name: 'neovide-release'
description: 'Build the custom neovide locally from source (cargo build --release) and produce the local binary. Invoke when user asks to build, package, or produce a local release artifact.'
---

# Neovide 本地构建 Skill

从源码构建自定义 neovide 的本地二进制产物。本 skill 只负责「源码 → 本地二进制」，不碰 GitHub Release（发布走 `neovide-publish`）。

## 触发条件

- 用户说"构建"、"打包"、"出一个本地版本"
- 验证某次改动能通过 release 构建

## 与 neovide-publish 的分工

| Skill                      | 职责                         | 起点 → 终点                                    |
| -------------------------- | ---------------------------- | ---------------------------------------------- |
| **`neovide-release`（本）**| 从源码到本地二进制           | 干净工作区 → `target/release/neovide[.exe]`    |
| `neovide-publish`          | 从版本号到 GitHub Release    | 版本号 + release notes → release 上线          |

## 执行流程

### 1. 前置检查

```bash
git status --porcelain          # 建议干净（构建产物进 target/，不影响提交）
cargo --version                 # 需已安装 Rust 工具链
rustup show                     # 确认 toolchain
```

Windows 还需 MSVC 工具链（`link.exe`）与 DirectX SDK（skia-safe 需要）。

### 2. 构建

```bash
cargo build --release
```

- 首次构建会经 `build.rs` 下载 skia-safe 预编译二进制，需网络
- 产物在 `target/release/neovide.exe`（Windows）/ `neovide`（Unix）

### 3. 验证

```bash
cargo test --release
```

可选：直接运行产物冒烟验证 `target/release/neovide.exe --version`。

### 4. 汇报

报告产物路径、大小、构建/测试结果。**不主动提交或打 tag**（发布走 `neovide-publish`，由用户决定）。

## 重要约束

1. 本 skill 只产出本地二进制，不管理版本号、不打 tag、不推送
2. 构建失败时按错误信息定位（常见：skia-safe 下载失败、MSVC 工具链缺失、DirectX SDK 缺失）
3. Windows 下产物被运行中的 neovide.exe 占用会导致链接失败，先 `taskkill //F //IM neovide.exe`
