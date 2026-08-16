#!/usr/bin/env bash
#
# リポジトリ内の設定ファイルを配置する。
#
#   bash scripts/deploy.sh            配置する
#   bash scripts/deploy.sh --check    配置せず、現状を診断するだけ
#
# 配置先はファイルごとに違う (scripts/lib.sh の DOTFILES 参照)。
#   .wezterm.lua / scanlines.png  -> WezTerm が読むホーム
#                                    WSL から実行した場合は Windows 側の C:\Users\xxx
#   .tmux.conf / starship.toml    -> 現在のシェルの $HOME
#
# シンボリックリンクにするかコピーにするか:
#   unix    : リンク（編集がそのままリポジトリに反映される）
#   windows : コピー（Git Bash のリンクは開発者モードか管理者権限が要る）
#   wsl     : Windows 側はコピー / WSL 側はリンク
#             WSL のシンボリックリンクは Windows アプリから辿れないため
#
# 既存ファイルは上書き前に .bak-YYYYMMDDHHMMSS を付けて退避する。
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib.sh
. "$REPO/scripts/lib.sh"
resolve_homes

STAMP="$(date +%Y%m%d%H%M%S)"
CHECK_ONLY=0
[ "${1:-}" = '--check' ] && CHECK_ONLY=1

FONT_DIR="$WEZ_HOME/.config/wezterm/fonts"
FONTS=(Px437_IBM_VGA_8x16.ttf VT323-Regular.ttf DepartureMono-Regular.otf)

# 種別ごとの配置方法を決める
place_mode() {
  case "$PLATFORM:$1" in
    unix:*) echo link ;;
    windows:*) echo copy ;;
    wsl:wez) echo copy ;;
    wsl:shell) echo link ;;
  esac
}

echo "==> リポジトリ:            $REPO"
echo "==> 実行環境:              $PLATFORM"
echo "==> WezTerm が読むホーム:  $WEZ_HOME"
echo "==> シェルの \$HOME:        $SHELL_HOME"
if [ "$PLATFORM" = wsl ]; then
  echo "    WSL から実行中。WezTerm は Windows アプリなので、"
  echo "    .wezterm.lua とフォントは Windows 側のホームに置きます。"
fi
echo

# ---------------------------------------------------------------- 診断のみ
if [ "$CHECK_ONLY" = 1 ]; then
  rc=0

  echo "--- 設定ファイル ---"
  for entry in "${DOTFILES[@]}"; do
    rel="${entry%%|*}"
    kind="${entry##*|}"
    dst="$(target_home "$kind")/$rel"

    if [ ! -e "$dst" ]; then
      printf '  %-30s 未配置   %s\n' "$rel" "$dst"
      rc=1
    elif cmp -s "$REPO/$rel" "$dst"; then
      printf '  %-30s OK       %s\n' "$rel" "$dst"
    else
      printf '  %-30s 内容差異 %s\n' "$rel" "$dst"
      rc=1
    fi
  done

  echo
  echo "--- フォント ($FONT_DIR) ---"
  for f in "${FONTS[@]}"; do
    if [ -f "$FONT_DIR/$f" ]; then
      printf '  %-30s OK\n' "$f"
    else
      printf '  %-30s 未取得\n' "$f"
      rc=1
    fi
  done

  echo
  echo "--- WezTerm から見えているか ---"
  if command -v wezterm >/dev/null 2>&1; then
    seen="$(wezterm ls-fonts --list-system 2>/dev/null | tr -d '\000' \
      | grep -aoiE 'px437 ibm vga 8x16|vt323|departure mono' | sort -u | tr '\n' ' ')"
    if [ -n "$seen" ]; then
      echo "  認識: $seen"
    else
      echo "  認識: なし  <-- font_dirs が空か、場所が違う"
      rc=1
    fi
  else
    echo "  wezterm コマンドが PATH に無いので確認できません"
    echo "  (WSL から実行している場合は当然。Windows 側で確認してください)"
  fi

  echo
  if [ "$rc" = 0 ]; then
    echo "問題なし。反映されないなら WezTerm を開き直してください。"
  else
    echo "上の「未配置 / 未取得 / 内容差異」を直す:"
    echo "  bash \"$REPO/scripts/install-fonts.sh\""
    echo "  bash \"$REPO/scripts/deploy.sh\""
  fi
  exit "$rc"
fi

# ---------------------------------------------------------------- 配置
for entry in "${DOTFILES[@]}"; do
  rel="${entry%%|*}"
  kind="${entry##*|}"
  src="$REPO/$rel"
  dst="$(target_home "$kind")/$rel"
  mode="$(place_mode "$kind")"

  if [ ! -e "$src" ]; then
    printf '  skip  %-30s (リポジトリに無い)\n' "$rel"
    continue
  fi

  mkdir -p "$(dirname "$dst")"

  if [ "$mode" = link ] && [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    printf '  ok    %-30s (リンク済み)\n' "$rel"
    continue
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak-$STAMP"
    printf '  bak   %-30s -> %s\n' "$rel" "$(basename "$dst").bak-$STAMP"
  fi

  if [ "$mode" = link ]; then
    ln -s "$src" "$dst"
    printf '  link  %-30s %s\n' "$rel" "$dst"
  else
    cp "$src" "$dst"
    printf '  copy  %-30s %s\n' "$rel" "$dst"
  fi
done

echo
if [ ! -f "$FONT_DIR/Px437_IBM_VGA_8x16.ttf" ]; then
  echo "フォントがまだです:  bash \"$REPO/scripts/install-fonts.sh\""
  echo
fi
echo "確認:  bash \"$REPO/scripts/deploy.sh\" --check"
echo "そのあと WezTerm を開き直せば反映されます。"
