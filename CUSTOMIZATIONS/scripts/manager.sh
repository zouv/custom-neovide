#!/usr/bin/env bash
# =============================================================================
# manager.sh — neovide-custom 项目统一入口
# Windows 使用 Git Bash 执行：sh CUSTOMIZATIONS/scripts/manager.sh <command>
#
# 常用快捷写法（在仓库根目录）：
#   sh CUSTOMIZATIONS/scripts/manager.sh help
#   sh CUSTOMIZATIONS/scripts/manager.sh build
#   sh CUSTOMIZATIONS/scripts/manager.sh test
#   sh CUSTOMIZATIONS/scripts/manager.sh run
# =============================================================================
set -euo pipefail

# 项目根目录：脚本位于 <repo>/CUSTOMIZATIONS/scripts/ 下
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="${PROJECT_ROOT}/target"

log()  { printf "\033[1;34m[manager]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ ok  ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[warn ]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[err  ]\033[0m %s\n" "$*" >&2; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "缺少命令：$1"
    exit 1
  }
}

# 进入项目根目录执行所有命令，避免相对路径歧义
cd "${PROJECT_ROOT}"

# 结束可能驻留后台的 Neovide 实例，否则 Windows 下产物被占用会失败
kill_running_neovide() {
  log "结束正在运行的 Neovide 实例..."
  taskkill //F //IM "neovide.exe" >/dev/null 2>&1 || true
}

cmd_build() {
  require_cmd cargo
  log "构建 release（cargo build --release）"
  cargo build --release "$@"
  ok "构建完成（产物 target/release/）"
}

cmd_check() {
  require_cmd cargo
  log "cargo check（快速编译检查，不产出二进制）"
  cargo check "$@"
  ok "检查完成"
}

cmd_test() {
  require_cmd cargo
  log "运行测试（cargo test）"
  cargo test "$@"
  ok "测试完成"
}

cmd_fmt() {
  require_cmd cargo
  log "cargo fmt 代码格式化"
  cargo fmt
  ok "格式化完成"
}

cmd_lint() {
  require_cmd cargo
  log "cargo clippy 代码检查"
  cargo clippy --all-targets --all-features "$@"
  ok "clippy 检查完成"
}

cmd_run() {
  require_cmd cargo
  log "启动开发模式（cargo run）"
  cargo run "$@"
}

cmd_clean() {
  log "清理构建产物（target/）"
  rm -rf "${TARGET_DIR}"
  ok "清理完成"
}

cmd_artifacts() {
  local bin="${TARGET_DIR}/release/neovide"
  [[ -f "${bin}" ]] || bin="${TARGET_DIR}/release/neovide.exe"
  if [[ ! -f "${bin}" ]]; then
    warn "尚无 release 产物（${TARGET_DIR}/release/neovide[.exe] 不存在），先跑 build"
    return 0
  fi
  printf "  %s  (%s bytes)\n" "$(basename "$bin")" "$(stat -c %s "$bin" 2>/dev/null || wc -c < "$bin" | tr -d ' ')"
}

cmd_help() {
  cat <<'EOF'
neovide-custom — manager.sh

用法：
  sh CUSTOMIZATIONS/scripts/manager.sh <command> [args]

命令：
  build    [args]  构建 release（cargo build --release）
  check    [args]  快速编译检查（cargo check，不产出二进制）
  test     [args]  运行测试（cargo test）
  fmt              cargo fmt 格式化
  lint     [args]  cargo clippy（--all-targets --all-features）
  run      [args]  启动开发模式（cargo run）
  artifacts        列出当前 release 产物
  clean            清理 target/
  help             显示帮助

说明：
  - 首次 build 会通过 build.rs 下载 skia-safe 预编译二进制，需网络。
  - 正式发布（GitHub Release、版本号管理）请用 neovide-publish skill，
    本脚本只负责本地构建。
EOF
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "${cmd}" in
    build|release) cmd_build "$@" ;;
    check) cmd_check "$@" ;;
    test) cmd_test "$@" ;;
    fmt) cmd_fmt ;;
    lint|clippy) cmd_lint "$@" ;;
    run|dev) cmd_run "$@" ;;
    artifacts|ls) cmd_artifacts ;;
    clean) cmd_clean ;;
    help|-h|--help) cmd_help ;;
    *) err "未知命令：${cmd}"; cmd_help; exit 2 ;;
  esac
}

main "$@"
