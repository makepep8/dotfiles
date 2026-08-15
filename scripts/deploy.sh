#!/usr/bin/env bash
#
# リポジトリ内の設定ファイルを $HOME に配置する。
#
#   Linux / macOS : シンボリックリンクを張る（編集がそのままリポジトリに反映される）
#   Windows       : コピーする
#                   Git Bash のシンボリックリンクは開発者モードか管理者権限が要る上に
#                   WezTerm 側が追えないことがあるため、素直にコピーする
#
# 既存ファイルは上書き前に .bak-YYYYMMDDHHMMSS を付けて退避する。
#
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAMP="$(date +%Y%m%d%H%M%S)"

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) MODE=copy ;;
  *)                        MODE=link ;;
esac

# リポジトリ内の相対パス = $HOME からの相対パス
FILES=(
  '.wezterm.lua'
  '.tmux.conf'
  '.config/starship.toml'
  '.config/wezterm/scanlines.png'
)

echo "==> リポジトリ: $REPO"
echo "==> 配置先:     $HOME"
echo "==> モード:     $MODE"
echo

for rel in "${FILES[@]}"; do
  src="$REPO/$rel"
  dst="$HOME/$rel"

  if [ ! -e "$src" ]; then
    echo "  skip  $rel (リポジトリに無い)"
    continue
  fi

  mkdir -p "$(dirname "$dst")"

  # 既に同じリンクが張ってあるなら何もしない
  if [ "$MODE" = link ] && [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "  ok    $rel (リンク済み)"
    continue
  fi

  # 既存の実体は退避
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mv "$dst" "$dst.bak-$STAMP"
    echo "  bak   $rel -> $rel.bak-$STAMP"
  fi

  if [ "$MODE" = link ]; then
    ln -s "$src" "$dst"
    echo "  link  $rel"
  else
    cp "$src" "$dst"
    echo "  copy  $rel"
  fi
done

echo
if [ "$MODE" = copy ]; then
  echo "コピーなので、設定を変えたらリポジトリ側にも反映させること:"
  for rel in "${FILES[@]}"; do
    echo "  cp \"\$HOME/$rel\" \"$REPO/$rel\""
  done
  echo
fi
echo "フォントがまだなら:  bash \"$REPO/scripts/install-fonts.sh\""
echo "その後 WezTerm を開き直せば反映されます。"
