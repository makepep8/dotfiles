# dotfiles

$HOME をミラーした構成。リポジトリ内の相対パスが、そのまま配置先の相対パスになる。

```
.wezterm.lua                   -> WezTerm が読むホーム
.config/wezterm/scanlines.png  -> WezTerm が読むホーム
.config/wezterm/vignette.png   -> WezTerm が読むホーム
.tmux.conf                     -> 現在のシェルの $HOME
.config/starship.toml          -> 現在のシェルの $HOME
scripts/lib.sh                    配置先を解決する共通処理
scripts/install-fonts.sh          CRT フォントを取得
scripts/deploy.sh                 上記を配置 / --check で診断
scripts/gen-theme.py              パレットと背景画像を生成（配置には不要）
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
| Symbols Nerd Font Mono | 他ツール (eza / lazygit 等) のアイコン用 | 別フォントに落ちて字形が変わる（動作はする）。starship は CP437 だけで組んであるので不要 |
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

Nerd Font のアイコンは正方形なので、素だと 16px 角 = 横 2 セル分を占めて隣に食い込む。
セルが 8x16（横 1 : 縦 2）である以上、横幅を 1 セルに収める倍率は `scale = 0.5` しか無く、
その結果アイコンは縦 8px = セルの半分になる。**これは調整で消せる問題ではない**ので、
アイコンに頼らないのが正解。starship 側は CP437 の文字だけで組んであり、
この fallback は他ツールが吐くグリフの保険として残している。

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
主役は `#39CF45`、背景 `#030B04`。

**色相は 125°（黄緑寄り）。** P1 蛍光体のピークは 525nm 付近で、シアン寄りのミント
グリーンにはならない。

**輝度の割り当てには下限がある。** 知覚輝度をそのまま 0 から使うと青が背景に対して
1.9:1 まで沈み、`ls` のディレクトリ名や git diff が読めなくなる。順序関係は保ったまま
床だけ 3.2:1 に持ち上げてある。黒だけは前景ではなく背景として使う色なので対象外。

パレットは手で書かず `scripts/gen-theme.py` が生成している。色相・床・彩度カーブを
いじったら再実行して、出力を `.wezterm.lua` / `.tmux.conf` / `.config/starship.toml`
の 3 つに貼り直すこと。スクリプトは生成後に自己検査もする（全前景色が 3:1 以上か、
同じ色の normal と bright が区別できるか、16 色に重複が無いか）。

```sh
python3 scripts/gen-theme.py            # 検査 + 画像生成
python3 scripts/gen-theme.py --dry-run  # 表示だけ
```

`.tmux.conf` と `.config/starship.toml` も同じパレットに合わせてある。色で成否を
区別できないため、プロンプト記号は成功 = 中間の緑 / エラー = 白緑（明るい方が警告）と
明度で出し分けている。

**テーマプラグインは使わない。** 外部テーマ（catppuccin 等）は truecolor の hex を
そのまま吐き、WezTerm 側の ANSI パレットを一切経由しない。端末をどれだけ単色に
作り込んでも、ステータスラインだけ素の色が出てそこで嘘が破れる。

**記号は CP437 の範囲だけで組む。** Nerd Font のアイコンは正方形なので、セル 8x16 の
横 1 セルに収めると縦が半分になって浮く。starship の powerline セパレータは
CP437 の半ブロック `▐` に、プロンプト記号は `►` に置き換えてある。

### 画面効果

背景は 4 層:

1. 素の黒
2. 中央がほのかに光る放射グラデーション + `noise = 96`（粒状感）
3. 走査線 — `.config/wezterm/scanlines.png` (2x4px) を敷き詰め
4. ビネット — `.config/wezterm/vignette.png` を全面に 1 枚

**レイヤ 2 は不透明なので、画面中央では 1 の素の黒を完全に上書きする。**
つまりグラデーションの内側の色が、そのまま「画面中央の実効背景」になる。
ここを明るくすると配色の床をそのまま食う（内側を `#0C2E0F` にしていたときは
画面中央で blue が 2.39:1 まで落ちていた）。コントラストを測るときは素の
`background` ではなくこの色を基準にすること。`gen-theme.py` は両方で検査する。

背景をもっと黒くしたい場合、いじるのは `background` ではなくここ。
`background` 自体は `#000000` にしてもコントラストの改善は 5% で知覚できず、
わずかな緑の色味を失うぶん「消灯中の蛍光体」に見えなくなるので損。

**走査線タイルの高さは 16 の約数でなければならない。** セル高が 16px なので、
以前の 3px では割り切れず、行ごとに走査線の位相がずれてグリフの横棒に暗線が乗る行と
乗らない行が混ざっていた。4px なら 1 セルちょうど 4 本で全行が同じ見え方になる。

ビネットは「隅が暗い」だけの効果だが、CRT らしさへの寄与は走査線より大きい。強度は
文字が読める範囲に抑えてある（中心 0 / 辺の中央 0.55 / 隅 0.72。最も濃い縁の帯は
`window_padding` の内側に収まる幅）。

カーソルは `EaseOut` / `EaseIn` でブロック明滅させて蛍光体の残光を模している。
ベルは音を切って画面の緑フラッシュに。非アクティブ pane は彩度を落とさず輝度だけで
暗くする（単一蛍光体の管は灰色を出せないため、彩度を下げるとグレーが混じって嘘が破れる）。

走査線がうるさければ背景レイヤ 3 の `opacity = 0.55` を下げるか、ブロックごと消す。
ビネットも同様にレイヤ 4 を消せば無くなる。

### 限界

- **WezTerm はカスタムシェーダに対応していない。** 本物のブルーム（滲む発光）・
  画面の樽型湾曲・フリッカーは出せない。そこまで要るなら Ghostty や Rio など
  shader を持つターミナルに移る必要がある。
  ノストロモ号の画面があの見え方をするのは、実際には**文字の周りのブルーム**
  （CRT を撮影したときのハレーション）であって、背景全体が持ち上がっている
  からではない。管面そのものは劇中でもほぼ黒に沈んでいる。背景レイヤ 2 の
  グラデーションはその代用だが**効果の形が違う**（文字の周りではなく画面全体を
  一様に持ち上げる）ので、そこにコントラストを払いすぎないこと。
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

### `WEZTERM_CONFIG_FILE` による上書き

この環境変数が設定されていると、**上の探索順を完全に無視して**そのファイルが読まれる
（実測で確認済み。コマンドラインの `--config-file` はさらにそれより強い）。

ハマりどころとして、**WezTerm は自分が起動したペインにこの変数を必ず出力する**。
そのためペインの中で値が入っていること自体は上書きの証拠にならない。
本来読まれるはずの候補と食い違っている場合だけが本物の上書きで、
`deploy.sh --check` はその判定をしてくれる。

永続設定されていないかを直接見るなら PowerShell で:

```powershell
[Environment]::GetEnvironmentVariable('WEZTERM_CONFIG_FILE','User')
[Environment]::GetEnvironmentVariable('WEZTERM_CONFIG_FILE','Machine')
```

WezTerm のショートカットに `--config-file` が付いていないかも確認する。
