#!/usr/bin/env bash
# wbs auth — 一键安装
#
#   curl -fL --retry 3 -o /tmp/wbs-install.sh \
#     https://raw.githubusercontent.com/xianzhen2008-dotcom/wbs-auth/main/install.sh \
#     && tail -3 /tmp/wbs-install.sh | grep -q WBS_AUTH_INSTALLER \
#     && bash /tmp/wbs-install.sh
#
# 文件最后一行是个完整性标记（WBS_AUTH 开头、END 结尾的那条注释）。网络断掉
# 时下载会缺一截，校验不到它就不执行，免得把半截脚本喂给 bash（那会报
# syntax error 并且装出个残缺文件）。复制粘贴时也把它带上，别掐掉。
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
    say "  ${c_yellow}如果这是 AI 助手给你的执行环境，那它不是你自己的电脑。${c_reset}"
    say "  它和你机器是两套文件系统，装上了也看不到 WorkBuddy 的登录文件。"
    say ""
    say "  请打开你自己电脑的「终端 / Terminal」，粘这一行："
    say ""
    say "    ${c_dim}curl -fL --retry 3 -o /tmp/wbs-install.sh $REPO_RAW/install.sh${c_reset}"
    say "    ${c_dim}tail -3 /tmp/wbs-install.sh | grep -q WBS_AUTH_INSTALLER_END && bash /tmp/wbs-install.sh${c_reset}"
    say ""
    say "  如果你本来就在 Linux 或 Windows 上，那确实不支持——"
    say "  凭证路径和加密方式都不一样，需要另行适配，不是加个判断就能跑。"
    say ""
    exit 1
    ;;
esac

# --- 确认拿到的是真实宿主环境 ---
# 有些隔离环境 uname 也报 Darwin，但看不到凭证目录，提前说清楚比装完才发现好
if [ ! -d "$HOME/Library/Application Support" ] && [ ! -d "$HOME/.workbuddy" ]; then
  warn "看不到 macOS 的用户目录（$HOME/Library/Application Support）"
  say ""
  say "  说明当前执行环境和你自己的机器不是同一套文件系统"
  say "  （Linux 容器、远程执行环境之类）。请在你自己的终端里重跑。"
  say ""
  exit 1
fi

# --- Python ---
# /usr/bin/python3 在没装 Xcode 命令行工具的 Mac 上只是个 shim：
# 文件存在、可执行，但真跑起来会弹「安装开发者工具」对话框然后失败。
# 所以不能只看 -x，得先确认 CLT 装了没有。
clt_installed() {
  xcode-select -p >/dev/null 2>&1
}

# 某个路径的 python 是不是那个要 CLT 的 shim
is_clt_shim() {
  case "$1" in
    /usr/bin/python3) return 0 ;;
  esac
  # 也挡住软链到它的（如 /usr/local/bin/python3 -> /usr/bin/python3）
  local real
  real="$(readlink -f "$1" 2>/dev/null || true)"
  [ "$real" = "/usr/bin/python3" ]
}

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
    # 没有 CLT 就别去碰那个 shim，一执行就弹窗
    if is_clt_shim "$c" && ! clt_installed; then
      continue
    fi
    if "$c" -c 'import sys; sys.exit(0 if sys.version_info >= (3, 8) else 1)' >/dev/null 2>&1; then
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
  # raw.githubusercontent.com 在国内经常超时，准备几个源逐个试
  SOURCES="$REPO_RAW"
  if [ -z "${WBS_AUTH_RAW:-}" ]; then
    SOURCES="$SOURCES
https://cdn.jsdelivr.net/gh/xianzhen2008-dotcom/wbs-auth@main
https://raw.gitmirror.com/xianzhen2008-dotcom/wbs-auth/main"
  fi

  GOT=0
  while IFS= read -r src || [ -n "$src" ]; do
    [ -n "$src" ] || continue
    say "${c_dim}  下载 $src/wbs${c_reset}"
    if command -v curl >/dev/null 2>&1; then
      if curl -fsSL --retry 3 --retry-delay 2 --connect-timeout 15 \
              "$src/wbs" -o "$TMP" 2>/dev/null && [ -s "$TMP" ]; then
        GOT=1
      fi
    elif command -v wget >/dev/null 2>&1; then
      if wget -q --tries=3 --timeout=15 -O "$TMP" "$src/wbs" 2>/dev/null && [ -s "$TMP" ]; then
        GOT=1
      fi
    else
      die "没有 curl 也没有 wget"
    fi
    if [ "$GOT" = "1" ]; then
      break
    fi
    warn "这个源不通，换下一个"
  done <<EOF
$SOURCES
EOF

  [ "$GOT" = "1" ] || die "所有下载源都失败了。检查网络，或用 WBS_AUTH_RAW 指定镜像。"
  ok "已下载 wbs"
fi

# --- 校验，别把半截文件或别的什么东西装进去 ---
grep -q "wbs auth" "$TMP" 2>/dev/null && grep -q "__version__" "$TMP" 2>/dev/null \
  || die "下载到的内容不完整（可能网络中断）。重跑一次试试。"

"$PY" -c "import ast,sys; ast.parse(open(sys.argv[1]).read())" "$TMP" \
  || die "下载到的 wbs 语法有问题，可能被改坏了"

# --- shebang ---
# `command -v python3` 在有 CLT shim 的机器上永远成功，拿它判断等于没判断。
# 真正要问的是：PATH 里那个 python3 敲下去能不能跑起来。
path_python_usable() {
  local p
  p="$(command -v python3 2>/dev/null || true)"
  [ -n "$p" ] || return 1
  if is_clt_shim "$p" && ! clt_installed; then
    return 1
  fi
  "$p" -c 'pass' >/dev/null 2>&1
}

if [ "${WBS_FORCE_PIN_SHEBANG:-0}" = "1" ] || ! path_python_usable; then
  "$PY" - "$TMP" "$PY" <<'PYEOF'
import sys
path, py = sys.argv[1], sys.argv[2]
src = open(path, encoding="utf-8").read()
if src.startswith("#!"):
    _, rest = src.split("\n", 1)
    open(path, "w", encoding="utf-8").write(f"#!{py}\n{rest}")
PYEOF
  ok "已把解释器钉到 ${PY}"
else
  ok "PATH 里的 python3 可用，保持便携写法"
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

# WBS_AUTH_INSTALLER_END
