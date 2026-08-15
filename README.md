# dotfiles

$HOME をそのままミラーした構成。リポジトリ内の相対パスが、そのまま `$HOME` からの相対パスになる。

```
.wezterm.lua                   -> ~/.wezterm.lua
.tmux.conf                     -> ~/.tmux.conf
.config/starship.toml          -> ~/.config/starship.toml
.config/wezterm/scanlines.png  -> ~/.config/wezterm/scanlines.png
scripts/install-fonts.sh          CRT フォントを ~/.config/wezterm/fonts/ に取得
scripts/deploy.sh                 上記を $HOME に配置
```

## セットアップ

```sh
git clone git@github.com:makepep8/dotfiles.git
cd dotfiles

bash scripts/install-fonts.sh   # フォント取得（ネット接続が要る、初回のみ）
bash scripts/deploy.sh          # $HOME に配置
```

`deploy.sh` は Linux/macOS ではシンボリックリンク、Windows (Git Bash) ではコピーで配置する。
既存ファイルは `*.bak-YYYYMMDDHHMMSS` に退避してから上書きするので、消える心配はない。

そのあと WezTerm を開き直せば反映される（WezTerm は設定ファイルを自動リロードする）。

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
