#!/usr/bin/env bash
#
# リポジトリ内の設定ファイルを配置する。
#
#   bash scripts/deploy.sh            配置する
#   bash scripts/deploy.sh --check    配置せず、現状を診断するだけ
#
# 配置先はファイルごとに違う (scripts/lib.sh の DOTFILES 参照)。
#   .wezterm.lua / 背景画像 (*.png)  -> WezTerm が読むホーム
#                                       WSL から実行した場合は Windows 側の C:\Users\xxx
#   .tmux.conf / starship.toml       -> 現在のシェルの $HOME
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
  # 診断中は「見つからない」が正常な結果なので errexit を切る。
  # grep はマッチ0件で終了コード1を返すため、pipefail と組み合わさると
  # 診断結果を表示する前にスクリプトが黙って落ちる。
  set +e +o pipefail
  rc=0

  # C:\Users\x と /c/Users/x と /mnt/c/Users/x を比較できる形にそろえる
  norm_path() {
    printf '%s' "$1" | tr 'A-Z\\' 'a-z/' \
      | sed 's|^\([a-z]\):|/\1|; s|^/mnt/\([a-z]\)/|/\1/|; s|//*|/|g; s|/$||'
  }

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
  echo "--- 設定ファイルの優先順位 ---"
  echo "  WezTerm は上から順に探して、最初に見つかったものだけを読みます。"
  found_first=0
  first_cand=''
  while IFS= read -r cand; do
    if [ -f "$cand" ]; then
      if [ "$found_first" = 0 ]; then
        echo "    [本来これが読まれる] $cand"
        first_cand="$cand"
        found_first=1
      else
        echo "    [隠れている]         $cand"
      fi
    else
      echo "    [無し]               $cand"
    fi
  done <<EOF
$(wezterm_config_candidates)
EOF
  if [ "$found_first" = 0 ]; then
    echo "  ★ 候補が1つも存在しません。WezTerm は既定設定で動いています。"
    rc=1
  fi

  # WEZTERM_CONFIG_FILE は探索順を完全に無視して勝つ（実測で確認済み）。
  # ただし WezTerm は自分が起動したペインにこの変数を必ず出力するので、
  # 「値が入っていること」自体は上書きの証拠にならない。
  # 本来読まれるはずの候補と食い違っている場合だけが、本物の上書き。
  if [ -n "${WEZTERM_CONFIG_FILE:-}" ] && [ -n "$first_cand" ]; then
    if [ "$(norm_path "$WEZTERM_CONFIG_FILE")" != "$(norm_path "$first_cand")" ]; then
      echo
      echo "  ★ WEZTERM_CONFIG_FILE で上書きされています。"
      echo "       本来読まれるはず: $first_cand"
      echo "       実際に読んでいる: $WEZTERM_CONFIG_FILE"
      echo "     この環境変数は探索順を無視して優先されます。"
      echo "     どこで設定されているか (Windows のユーザー環境変数 / シェルの rc /"
      echo "     WezTerm のショートカットの --config-file) を確認して外してください。"
      rc=1
    fi
  fi

  echo
  echo "--- WezTerm 本体が見ている場所 ---"

  # WezTerm は自分が起動したペインの環境変数に、読み込んだ設定ファイルを入れる
  if [ -n "${WEZTERM_CONFIG_FILE:-}" ]; then
    echo "  読み込んでいる設定ファイル: $WEZTERM_CONFIG_FILE"
    want="$(norm_path "$WEZ_HOME/.wezterm.lua")"
    got="$(norm_path "$WEZTERM_CONFIG_FILE")"
    if [ "$want" = "$got" ]; then
      echo "    -> スクリプトの配置先と一致"
    else
      echo "    -> ★ズレています。スクリプトはここに置いています:"
      echo "         $WEZ_HOME/.wezterm.lua"
      echo "       WezTerm が読んでいるのは上の設定ファイルなので、そちらに置く必要があります。"
      rc=1
    fi
  else
    echo "  WEZTERM_CONFIG_FILE が空です。"
    echo "  = WezTerm のペインの中で実行していないか、WezTerm が設定を1つも読めていません。"
    echo "  WezTerm のウィンドウの中で実行し直すと、読み込んでいる設定ファイルが分かります。"
  fi

  # 設定ファイルの場所によらず、WezTerm が home をどこだと思っているかを直接聞く
  if command -v wezterm >/dev/null 2>&1; then
    probe="$(mktemp -t wezprobe.XXXXXX.lua 2>/dev/null || echo "${TMPDIR:-/tmp}/wezprobe.lua")"
    printf "local w = require 'wezterm'\nerror('WEZPROBE_HOME=' .. tostring(w.home_dir))\n" >"$probe"
    ph="$(wezterm --config-file "$probe" ls-fonts --codepoints 41 2>&1 | tr -d '\000' \
      | grep -ao 'WEZPROBE_HOME=[^"'"'"']*' | head -1 | sed 's/WEZPROBE_HOME=//')"
    rm -f "$probe"
    if [ -n "$ph" ]; then
      echo "  WezTerm が思っている home: $ph"
      if [ "$(norm_path "$ph")" != "$(norm_path "$WEZ_HOME")" ]; then
        echo "    -> ★スクリプトが使っているホームとズレています: $WEZ_HOME"
        rc=1
      fi
    fi
  fi

  echo
  echo "--- WezTerm から見えているか ---"
  if command -v wezterm >/dev/null 2>&1; then
    wez_out="$(wezterm ls-fonts --list-system 2>&1 | tr -d '\000')"

    if printf '%s' "$wez_out" | grep -qa '^ *Error\|error:'; then
      echo "  wezterm がエラーを返しました。設定ファイルが壊れている可能性があります:"
      printf '%s\n' "$wez_out" | grep -a -m5 'Error\|error:' | sed 's/^/    /'
      rc=1
    fi

    seen="$(printf '%s' "$wez_out" \
      | grep -aoiE 'px437 ibm vga 8x16|vt323|departure mono' | sort -u | tr '\n' ' ')"

    if [ -n "$seen" ]; then
      echo "  認識: $seen"
    else
      echo "  認識: なし"
      rc=1
      echo
      echo "  WezTerm が実際に見に行った font_dirs:"
      wez_dirs="$(printf '%s' "$wez_out" | grep -a 'FontDirs' \
        | sed 's/.*-- //; s/[\\/][^\\/]*, FontDirs.*//' | sort -u)"
      if [ -n "$wez_dirs" ]; then
        printf '%s\n' "$wez_dirs" | sed 's/^/    /'
      else
        echo "    (1つも無い = font_dirs が空か、指定先が存在しない)"
      fi
      echo
      echo "  スクリプトがフォントを置いた場所:"
      echo "    $FONT_DIR"
      if [ -d "$FONT_DIR" ]; then
        ls -1 "$FONT_DIR" 2>/dev/null | sed 's/^/      /' || echo "      (空)"
      else
        echo "      (ディレクトリが存在しない)"
      fi
      echo
      echo "  この2つが食い違っているなら、WezTerm の home_dir と"
      echo "  スクリプトの \$HOME がズレています。上の font_dirs 側へ"
      echo "  フォントを置き直してください。"
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
shadowed="$(shadowed_wezterm_config)"
if [ -n "$shadowed" ]; then
  cat <<MSG
注意: 既存の設定ファイルが読まれなくなります。

  $shadowed

  WezTerm は ~/.wezterm.lua を優先するため、いま置いた設定が使われ、
  上のファイルは読まれなくなります（消してはいません）。
  そちらに残したい設定があるなら、.wezterm.lua 側に移してください。

MSG
fi

if [ ! -f "$FONT_DIR/Px437_IBM_VGA_8x16.ttf" ]; then
  echo "フォントがまだです:  bash \"$REPO/scripts/install-fonts.sh\""
  echo
fi
echo "確認:  bash \"$REPO/scripts/deploy.sh\" --check"
echo "そのあと WezTerm を開き直せば反映されます。"
