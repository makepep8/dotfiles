#!/usr/bin/env bash
#
# WezTerm の CRT テーマが使うフォントを取ってくる。
#
# 置き場所は「WezTerm が読むホーム」= WEZ_HOME。
# WSL から実行した場合は Windows 側の C:\Users\xxx\.config\wezterm\fonts に入る。
# WSL の $HOME に入れても WezTerm (Windows アプリ) からは見えないため。
#
# システムのフォントとしてはインストールしない。.wezterm.lua の font_dirs が
# このディレクトリを直接読むので、フォルダごと消せば綺麗に元に戻る。
#
set -euo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
resolve_homes

DEST="${WEZ_HOME}/.config/wezterm/fonts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "エラー: $1 が必要です" >&2
    exit 1
  }
}
need curl
need unzip

mkdir -p "$DEST"

echo "==> 実行環境: $PLATFORM"
echo "==> 配置先:   $DEST"
if [ "$PLATFORM" = wsl ]; then
  echo "    (WSL から実行しているので Windows 側のホームに入れます)"
fi
echo

# --- Px437 IBM VGA 8x16 (既定で使うフォント) -------------------------------
# The Ultimate Oldschool PC Font Pack v2.2 / CC BY-SA 4.0 / VileR (int10h.org)
# パック全体で 14MB ほどあるが、必要な 1 ファイルだけ取り出して残りは捨てる。
if [ -f "$DEST/Px437_IBM_VGA_8x16.ttf" ]; then
  echo "==> Px437 IBM VGA 8x16: 既にあるのでスキップ"
else
  echo "==> Px437 IBM VGA 8x16 を取得中 (14MB ほどダウンロードします)..."
  curl -fsSL -o "$TMP/oldschool.zip" \
    'https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_win.zip'
  unzip -j -o "$TMP/oldschool.zip" \
    'ttf - Px (pixel outline)/Px437_IBM_VGA_8x16.ttf' -d "$DEST" >/dev/null
fi

# --- VT323 (差し替え候補) ---------------------------------------------------
# SIL Open Font License 1.1 / Peter Hull (Google Fonts)
if [ -f "$DEST/VT323-Regular.ttf" ]; then
  echo "==> VT323: 既にあるのでスキップ"
else
  echo "==> VT323 を取得中..."
  curl -fsSL -o "$DEST/VT323-Regular.ttf" \
    'https://github.com/google/fonts/raw/main/ofl/vt323/VT323-Regular.ttf'
fi

# --- Departure Mono (差し替え候補) -----------------------------------------
# SIL Open Font License 1.1 / Helena Zhang (departuremono.com)
if [ -f "$DEST/DepartureMono-Regular.otf" ]; then
  echo "==> Departure Mono: 既にあるのでスキップ"
else
  echo "==> Departure Mono を取得中..."
  curl -fsSL -o "$TMP/dm.zip" 'https://departuremono.com/assets/DepartureMono-1.500.zip'
  unzip -j -o "$TMP/dm.zip" 'DepartureMono-1.500/DepartureMono-Regular.otf' -d "$DEST" >/dev/null
fi

echo
echo "完了。以下が入りました:"
ls -1 "$DEST"
echo
echo "WezTerm が認識しているか確認するには (WezTerm のある環境で):"
echo "  wezterm ls-fonts --list-system | grep -Ei 'px437|vt323|departure'"
