#!/usr/bin/env bash
# wbs auth — 一键安装
#
#   curl -fsSL https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh | bash
#
# 也支持本地安装：
#   ./install.sh
#
# 环境变量：
#   WBS_AUTH_RAW   自定义 raw 源（镜像 / 内网）
#   WBS_AUTH_DIR   安装目录，默认 ~/.local/bin
#   WBS_NO_INIT    设为 1 则安装后不做环境检查

set -euo pipefail

REPO_RAW="${WBS_AUTH_RAW:-https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main}"
BIN_DIR="${WBS_AUTH_DIR:-$HOME/.local/bin}"
TARGET="$BIN_DIR/wbs"

c_reset=$'\033[0m'; c_dim=$'\033[2m'; c_green=$'\033[32m'; c_red=$'\033[31m'; c_yellow=$'\033[33m'

say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$c_green" "$c_reset" "$*"; }
warn() { printf '%s!%s %s\n' "$c_yellow" "$c_reset" "$*"; }
die()  { printf '%s✗%s %s\n' "$c_red" "$c_reset" "$*" >&2; exit 1; }

say ""
say "wbs auth · 安装"
say "${c_dim}────────────────────────────────────────${c_reset}"

# --- 平台 ---
case "$(uname -s)" in
  Darwin) ;;
  *) die "目前只支持 macOS。Linux / Windows 还没适配凭证路径。" ;;
esac

# --- Python ---
PY=""
for cand in python3 /usr/bin/python3 /opt/homebrew/bin/python3; do
  if command -v "$cand" >/dev/null 2>&1; then
    if "$cand" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
      PY="$cand"; break
    fi
  fi
done
[ -n "$PY" ] || die "需要 python3 ≥ 3.8。装一下：brew install python"
ok "python3 $("$PY" -c 'import platform;print(platform.python_version())')"

# --- 取脚本 ---
mkdir -p "$BIN_DIR"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

SELF_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
  SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fi

if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/wbs" ]; then
  cp "$SELF_DIR/wbs" "$TMP"
  ok "使用本地 wbs"
else
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$REPO_RAW/wbs" -o "$TMP" || die "下载失败：$REPO_RAW/wbs"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$TMP" "$REPO_RAW/wbs" || die "下载失败：$REPO_RAW/wbs"
  else
    die "没有 curl 也没有 wget"
  fi
  ok "已下载 wbs"
fi

# --- 语法自检，别装个坏文件进去 ---
"$PY" -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$TMP" \
  || die "下载到的 wbs 语法有问题，可能被改坏了"

# --- 安装 ---
if [ -f "$TARGET" ] && ! head -30 "$TARGET" 2>/dev/null | grep -q "wbs"; then
  warn "$TARGET 已存在且不是本工具，已备份为 wbs.bak"
  mv "$TARGET" "$TARGET.bak"
fi

install -m 755 "$TMP" "$TARGET"
ok "装到 $TARGET"

# 别名 wbs-auth
ln -sf "$TARGET" "$BIN_DIR/wbs-auth"
ok "别名 wbs-auth"

# --- PATH ---
on_path() {
  case ":$PATH:" in *":$1:"*) return 0;; *) return 1;; esac
}
if ! on_path "$BIN_DIR"; then
  RC="$HOME/.zshrc"
  LINE="export PATH=\"$BIN_DIR:\$PATH\""
  if ! grep -qsF "$LINE" "$RC" 2>/dev/null; then
    printf '\n# wbs auth\n%s\n' "$LINE" >> "$RC"
    ok "已把 $BIN_DIR 写进 ~/.zshrc"
  fi
  export PATH="$BIN_DIR:$PATH"
  warn "当前终端还没生效，执行 source ~/.zshrc 或开个新窗口"
else
  ok "$BIN_DIR 已在 PATH"
fi

# --- 环境检查 ---
say ""
if [ "${WBS_NO_INIT:-0}" = "1" ]; then
  say "跳过环境检查。之后可以跑 ${c_dim}wbs init${c_reset}"
else
  "$PY" "$TARGET" init || true
fi

say "${c_dim}────────────────────────────────────────${c_reset}"
ok "装完了。敲 ${c_dim}wbs${c_reset} 看用法，${c_dim}wbs h${c_reset} 看详细说明"
say ""
