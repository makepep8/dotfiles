#!/usr/bin/env bash
#
# 配置先を解決する共通処理。
#
# 効かせたい相手がどこで動いているかで置き場所が変わる。
#
#   WezTerm は Windows アプリなので、WSL のシェルから見た $HOME (/home/xxx) ではなく
#   Windows 側の %USERPROFILE% (C:\Users\xxx) を読む。
#   リポジトリを WSL 側に clone して WSL のシェルで実行すると、
#   WezTerm が絶対に見ない場所に置かれて「何も変わらない」ことになる。
#
#   tmux と starship は現在のシェルの中で動くので、そのシェルの $HOME でよい。
#
# 解決結果:
#   WEZ_HOME   ... WezTerm が設定とフォントを読む場所
#   SHELL_HOME ... 現在のシェルの $HOME
#   PLATFORM   ... wsl | windows | unix

is_wsl() { grep -qi microsoft /proc/version 2>/dev/null; }

is_msys() {
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
    *) return 1 ;;
  esac
}

# WSL から Windows の %USERPROFILE% を WSL パスとして取り出す
windows_home_from_wsl() {
  local wp=''
  # cmd.exe は cwd が Linux 側だと UNC 警告を出すので Windows 側へ移ってから呼ぶ
  wp="$(cd /mnt/c 2>/dev/null && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r\n')"
  if [ -z "$wp" ]; then
    wp="$(powershell.exe -NoProfile -Command '$env:USERPROFILE' 2>/dev/null | tr -d '\r\n')"
  fi
  [ -n "$wp" ] || return 1
  wslpath -u "$wp" 2>/dev/null
}

resolve_homes() {
  SHELL_HOME="$HOME"

  if is_wsl; then
    PLATFORM=wsl
    WEZ_HOME="$(windows_home_from_wsl || true)"
    if [ -z "$WEZ_HOME" ] || [ ! -d "$WEZ_HOME" ]; then
      echo "エラー: WSL 上で Windows 側のホームを特定できませんでした。" >&2
      echo "       WezTerm が Windows で動いているなら、Git Bash から実行し直してください。" >&2
      return 1
    fi
  elif is_msys; then
    PLATFORM=windows
    WEZ_HOME="$HOME" # Git Bash の $HOME は既に C:\Users\xxx
  else
    PLATFORM=unix
    WEZ_HOME="$HOME"
  fi

  export SHELL_HOME WEZ_HOME PLATFORM
}

# 配置対象。 "リポジトリ内の相対パス|配置先の種別"
#   wez   ... WezTerm が読む場所へ
#   shell ... 現在のシェルの $HOME へ
DOTFILES=(
  '.wezterm.lua|wez'
  '.config/wezterm/scanlines.png|wez'
  '.config/starship.toml|shell'
  '.tmux.conf|shell'
)

target_home() {
  case "$1" in
    wez) printf '%s' "$WEZ_HOME" ;;
    shell) printf '%s' "$SHELL_HOME" ;;
    *)
      echo "不明な配置先種別: $1" >&2
      return 1
      ;;
  esac
}
