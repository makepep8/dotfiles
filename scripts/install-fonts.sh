#!/usr/bin/env bash
#
# WezTerm の CRT テーマが使うフォントを ~/.config/wezterm/fonts/ に取ってくる。
#
# システムのフォントとしてはインストールしない。.wezterm.lua の font_dirs が
# このディレクトリを直接読むので、フォルダごと消せば綺麗に元に戻る。
#
set -euo pipefail

DEST="${HOME}/.config/wezterm/fonts"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$DEST"

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "エラー: $1 が必要です" >&2; exit 1; }
}
need curl
need unzip

echo "==> 配置先: $DEST"

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
echo "WezTerm が認識しているか確認するには:"
echo "  wezterm ls-fonts --list-system | grep -Ei 'px437|vt323|departure'"
