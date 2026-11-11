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
OS="$(uname -s)"
case "$OS" in
  Darwin) ;;
  *)
    warn "当前系统是 ${OS}，不是 macOS"
    say ""
    if [ -f /.dockerenv ] || [ -n "${CODESPACES:-}" ] || [ -n "${REMOTE_CONTAINERS:-}" ] \
       || [ -n "${KUBERNETES_SERVICE_HOST:-}" ]; then
      say "  看起来你正跑在一个容器里。"
      say ""
    fi
    say "  ${c_yellow}如果这是 AI 助手给你的沙箱环境，那它不是你自己的电脑。${c_reset}"
    say "  沙箱里装上了也看不到你机器上 WorkBuddy 的登录文件，切换无从谈起。"
    say ""
    say "  请打开你自己电脑的「终端 / Terminal」，粘这一行："
    say ""
    say "    ${c_dim}curl -fsSL $REPO_RAW/install.sh | bash${c_reset}"
    say ""
    say "  如果你本来就在 Linux 或 Windows 上，那确实不支持——"
    say "  凭证路径和加密方式都不一样，需要另行适配，不是加个判断就能跑。"
    say ""
    exit 1
    ;;
esac

# --- 确认拿到的是真实宿主环境 ---
# 沙箱里可能 uname 也报 Darwin，但看不到凭证目录，提前说清楚比装完才发现好
if [ ! -d "$HOME/Library/Application Support" ] && [ ! -d "$HOME/.workbuddy" ]; then
  warn "看不到 macOS 的用户目录（$HOME/Library/Application Support）"
  say ""
  say "  可能是在受限沙箱里执行。请在你自己的终端里重跑，"
  say "  或者先确认 WorkBuddy 已经在这台机器上登录过。"
  say ""
  exit 1
fi

# --- Python ---
# 依次找工作 python3、系统 python3、Homebrew、WorkBuddy 自带的那个
find_python() {
  local c
  for c in \
    "$(command -v python3 2>/dev/null)" \
    /usr/bin/python3 \
    /opt/homebrew/bin/python3 \
    /usr/local/bin/python3 \
    "$HOME"/.workbuddy/binaries/python/versions/*/bin/python3 \
    "$HOME"/.local/bin/python3
  do
    [ -n "$c" ] && [ -x "$c" ] || continue
    if "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' 2>/dev/null; then
      printf '%s' "$c"
      return 0
    fi
  done
  return 1
}

PY="$(find_python)" || true
if [ -z "$PY" ]; then
  warn "没找到 python3 ≥ 3.8"
  say ""
  say "  装一个再回来跑这条命令，任选其一："
  say "    ${c_dim}xcode-select --install${c_reset}      （系统自带，最省事）"
  say "    ${c_dim}brew install python${c_reset}          （有 Homebrew）"
  say ""
  say "  装了 WorkBuddy 的机器通常在 ~/.workbuddy/binaries/python 下自带一个，"
  say "  检查一下这个目录是否被清过。"
  exit 1
fi
ok "python3 $("$PY" -c 'import platform;print(platform.python_version())')  ${c_dim}$PY${c_reset}"

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

# PATH 里没有 python3 时，把 shebang 钉成刚找到的绝对路径，否则 wbs 跑不起来
if ! command -v python3 >/dev/null 2>&1; then
  "$PY" - "$TMP" "$PY" <<'PYEOF'
import sys
path, py = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()
if src.startswith("#!"):
    head, rest = src.split("\n", 1)
    src = f"#!{py}\n{rest}"
    open(path, "w", encoding="utf-8").write(src)
PYEOF
  ok "已把解释器钉到 $PY"
fi

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
