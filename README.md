# dotfiles

$HOME をミラーした構成。リポジトリ内の相対パスが、そのまま配置先の相対パスになる。

```
.wezterm.lua                   -> WezTerm が読むホーム
.config/wezterm/scanlines.png  -> WezTerm が読むホーム
.tmux.conf                     -> 現在のシェルの $HOME
.config/starship.toml          -> 現在のシェルの $HOME
scripts/lib.sh                    配置先を解決する共通処理
scripts/install-fonts.sh          CRT フォントを取得
scripts/deploy.sh                 上記を配置 / --check で診断
```

## セットアップ

```sh
git clone git@github.com:makepep8/dotfiles.git
cd dotfiles

bash scripts/install-fonts.sh   # フォント取得（ネット接続が要る、初回のみ）
bash scripts/deploy.sh          # 配置
bash scripts/deploy.sh --check  # ちゃんと入ったか診断
```

そのあと WezTerm を開き直せば反映される（WezTerm は設定ファイルを自動リロードする）。

### 反映されないとき

まず `bash scripts/deploy.sh --check` を実行する。どこに何が入っていて何が欠けているかが出る。

### WSL を使っている場合の注意（重要）

**WezTerm は Windows アプリなので、WSL のシェルの `$HOME` (`/home/xxx`) ではなく
Windows 側の `%USERPROFILE%` (`C:\Users\xxx`) を読む。**

リポジトリを WSL 側に clone して WSL のシェルで実行しても問題ない。
`deploy.sh` と `install-fonts.sh` は WSL 上での実行を検出して、
WezTerm 関連だけ自動的に Windows 側のホームへ置く。

```
WSL から実行した場合の行き先:
  .wezterm.lua / scanlines.png / フォント  -> /mnt/c/Users/xxx/...   (Windows 側)
  .tmux.conf / starship.toml               -> /home/xxx/...          (WSL 側)
```

tmux は WSL の中で動くので WSL 側、WezTerm は Windows 側、と使う場所に合わせて振り分けている。
**WSL を使っているなら WSL のシェルから 1 回実行すれば両方とも正しい場所に入る。**

配置方法は環境ごとに変えている。WSL のシンボリックリンクは Windows アプリから辿れず、
Git Bash のシンボリックリンクは開発者モードか管理者権限が要るため:

| 実行環境 | WezTerm 関連 | シェル関連 |
|---|---|---|
| Linux / macOS | シンボリックリンク | シンボリックリンク |
| WSL | コピー（Windows 側へ） | シンボリックリンク |
| Git Bash (Windows) | コピー | コピー |

既存ファイルは `*.bak-YYYYMMDDHHMMSS` に退避してから上書きするので、消える心配はない。
コピーで配置された環境では、設定をいじったらリポジトリ側にも反映させること。

### 前提

| | 用途 | 無いとどうなる |
|---|---|---|
| [WezTerm](https://wezterm.org/) | 本体 | — |
| [starship](https://starship.rs/) | プロンプト | `.config/starship.toml` が使われないだけ |
| Symbols Nerd Font Mono | starship の  ❯ 用 | 別フォントに落ちて字形が変わる（動作はする） |
| MS Gothic / BIZ UDGothic | 日本語 | 日本語が可変幅フォントに落ちて桁がズレる（後述） |

日本語フォントは Windows なら標準で入っている。Linux では `BIZ UDGothic` などを入れるか、
`.wezterm.lua` のフォールバックに手元の等幅日本語フォントを足すこと。

---

## WezTerm テーマ: "MU/TH/UR 6000"

映画『エイリアン』(1979) のノストロモ号の緑蛍光管ディスプレイ風。

### フォント構成

システムのフォントとしてはインストールせず、`font_dirs` で
`~/.config/wezterm/fonts/` を直接読ませている。フォルダごと消せば元に戻る。

本体は **Px437 IBM VGA 8x16**。`font_size = 12.0` のとき実測で **ASCII = 8px / 全角 = 16px**
とちょうど 1:2 になり、日本語の桁ズレが起きない。**サイズを変えるならこの比率を必ず測り直すこと。**

```sh
wezterm ls-fonts --codepoints 41   # ASCII  -> x_adv=8  cells=1
wezterm ls-fonts --codepoints 3042 # あ     -> x_adv=16 cells=2
```

全角が 2 セル分ちょうどでないと、シェル (readline) が思っているカーソル位置と
実際の描画位置がずれ、**行を再描画するたびに入力した日本語が消える。**

Nerd Font のグリフは素だと 16px = 2 セル分あって隣に食い込むので `scale = 0.5` で潰してある。

フォントの差し替えは `.wezterm.lua` の 1 行:

```lua
{ family = 'Px437 IBM VGA 8x16' },  -- 既定: 角ばった VGA ドット
{ family = 'VT323' },               -- 細くて縦長、DEC 端末寄り
{ family = 'Departure Mono' },      -- モダンなピクセルフォント、可読性高め
```

差し替えたら ASCII 幅が変わるので、上のコマンドで測り直して
日本語フォント側に `scale` を足して 1:2 に合わせること。

### 配色

単色 CRT は原理的に色を出せないので、ANSI 16 色を「元の色の知覚輝度」に対応する
緑の階調へ写像している（青 0.11 < 赤 0.30 < 紫 0.41 < 緑 0.59 < 水 0.70 < 黄 0.89 < 白 1.0）。
主役は `#4AF676`、背景 `#030B05`。

`.config/starship.toml` も同じパレットに合わせてある。色で成否を区別できないため、
プロンプト記号は成功 = 中間の緑 / エラー = 白緑（明るい方が警告）と明度で出し分けている。

### 画面効果

背景は 3 層:

1. 素の黒
2. 中央がほのかに光る放射グラデーション + `noise = 96`（粒状感）
3. 走査線 — `.config/wezterm/scanlines.png` (2x3px) を敷き詰め

カーソルは `EaseOut` / `EaseIn` でブロック明滅させて蛍光体の残光を模している。
ベルは音を切って画面の緑フラッシュに。

走査線がうるさければ背景レイヤ 3 の `opacity = 0.55` を下げるか、ブロックごと消す。

### 限界

- **WezTerm はカスタムシェーダに対応していない。** 本物のブルーム（滲む発光）・
  画面の樽型湾曲・フリッカーは出せない。そこまで要るなら Ghostty や Rio など
  shader を持つターミナルに移る必要がある。
- **走査線は文字の「後ろ」にしか描けない。** WezTerm の背景レイヤはテキストより下なので、
  本物のように文字の上を横切らない。行間の隙間で効く控えめな効果。

---

## フォントのライセンス

`scripts/install-fonts.sh` が取得するもの（リポジトリにはバイナリを含めていない）:

| フォント | 作者 | ライセンス |
|---|---|---|
| [Px437 IBM VGA 8x16](https://int10h.org/oldschool-pc-fonts/) | VileR | CC BY-SA 4.0 |
| [VT323](https://fonts.google.com/specimen/VT323) | Peter Hull | SIL Open Font License 1.1 |
| [Departure Mono](https://departuremono.com/) | Helena Zhang | SIL Open Font License 1.1 |

## 設定ファイルの優先順位（ハマりどころ）

WezTerm は次の順に探して、**最初に見つかったものだけ**を読む。実測で確認済み。

1. `$WEZTERM_CONFIG_FILE`（環境変数で明示された場合）
2. `~/.wezterm.lua`  ← このリポジトリが置く場所
3. `~/.config/wezterm/wezterm.lua`（`$XDG_CONFIG_HOME` があればそちら）

つまり **`~/.config/wezterm/wezterm.lua` を既に持っている環境では、
`deploy.sh` が置いた `~/.wezterm.lua` の方が優先され、既存の設定が読まれなくなる。**
`deploy.sh` はこれを検出して警告する（既存ファイルは消さない）。
残したい設定があるなら `.wezterm.lua` 側へ移すこと。

逆に「配置したのに何も変わらない」場合は、`~/.wezterm.lua` が
WezTerm の見ているホームに届いていない。WezTerm のウィンドウの中で

```sh
echo "$WEZTERM_CONFIG_FILE"
```

を実行すると、実際に読み込まれている設定ファイルの絶対パスが分かる。
`deploy.sh --check` はこれを含めて自動で突き合わせる。
