-- =====================================================================
--  WezTerm — "MU/TH/UR 6000" / Nostromo CRT
--  緑蛍光管 (P1 phosphor) 風テーマ
-- =====================================================================
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

local is_windows = wezterm.target_triple:find 'windows' ~= nil

-- パスは決め打ちにしない（dotfiles として使い回すため）。
-- home_dir は環境によっては設定ファイルの実際の置き場所とズレることがある
-- （Git Bash の $HOME がネットワークドライブを指している場合など）ので、
-- config_dir 起点の候補も並べておく。config_dir は実際に読み込まれた
-- 設定ファイルのあるディレクトリなので、これだけは絶対にズレない。
local HOME = wezterm.home_dir:gsub('\\', '/')
local CDIR = wezterm.config_dir:gsub('\\', '/')

local ASSET_DIRS = {
  CDIR .. '/.config/wezterm', -- 設定が ~/.wezterm.lua のとき
  CDIR, -- 設定が ~/.config/wezterm/wezterm.lua のとき
  HOME .. '/.config/wezterm', -- 従来の決め打ち
}

-- 画像アセットを候補ディレクトリから探す。見つからなければ第1候補を返す
-- （WezTerm は存在しない背景画像を黙って無視するので、それで実害は無い）。
local function asset(name)
  for _, d in ipairs(ASSET_DIRS) do
    local p = d .. '/' .. name
    local fh = io.open(p, 'r')
    if fh then
      fh:close()
      return p
    end
  end
  return ASSET_DIRS[1] .. '/' .. name
end

-- ---------------------------------------------------------------------
-- フォント
-- ---------------------------------------------------------------------
-- fonts/ から直接読む（システムへのインストール不要）。
-- 存在しないディレクトリを並べても WezTerm は黙って無視するので、
-- 候補を全部渡してどれかに当たればよい方式にしている。
config.font_dirs = {}
for _, d in ipairs(ASSET_DIRS) do
  table.insert(config.font_dirs, d .. '/fonts')
end

-- Px437 IBM VGA 8x16 は font_size 12.0 のとき ASCII が実測 8px。
-- MS Gothic は同サイズで全角 16px = ちょうど 2 セルに一致するので、
-- 日本語の桁ズレが起きない。サイズを変えるならこの比率を崩さないこと。
config.font = wezterm.font_with_fallback {
  { family = 'Px437 IBM VGA 8x16' }, -- 本体: VGA ビットマップ (CP437)
  -- Nerd Font のアイコンは正方形なので、素だと 16px 角 = 横 2 セル分を占めて
  -- 隣に食い込む。セルが 8x16（横 1 : 縦 2）である以上、横幅を 1 セルに
  -- 収める倍率は 0.5 しか無く、その結果アイコンは縦 8px = セルの半分になる。
  -- これは調整で消せる問題ではないので、アイコンに頼らないのが正解。
  -- starship 側は CP437 の文字だけで組んであり、この fallback は
  -- 他ツール (eza / lazygit 等) が吐くグリフの保険として残している。
  { family = 'Symbols Nerd Font Mono', scale = 0.5 },
  { family = 'Cascadia Mono' }, -- CP437 に無いラテン系記号 (… → 等)
  { family = 'MS Gothic' }, -- 日本語: ビットマップ内蔵、全角=2セル
  { family = 'BIZ UDGothic' }, -- 日本語の保険
}
config.font_size = 12.0
config.line_height = 1.0
config.cell_width = 1.0

-- ドット感を殺さないようリガチャ無効 + シャープに描く
config.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
config.freetype_load_target = 'Mono'
config.freetype_render_target = 'Mono'
config.warn_about_missing_glyphs = false

-- ---------------------------------------------------------------------
-- 配色: モノクロ緑蛍光管
--
--   本物の単色 CRT は色を出せないので、ANSI 16 色は
--   「元の色の知覚輝度」に対応する緑の階調へ写像している。
--   (青 0.11 < 赤 0.30 < 紫 0.41 < 緑 0.59 < 水 0.70 < 黄 0.89 < 白 1.0)
--
--   色相は 125°（黄緑寄り）。P1 蛍光体のピークは 525nm 付近で、
--   シアン寄りのミントグリーンにはならない。
--
--   輝度の割り当てには下限を設けてある。知覚輝度をそのまま 0 から使うと
--   青が背景に対して 1.9:1 まで沈み、ls のディレクトリ名や git diff が
--   読めなくなる。順序関係は保ったまま、床だけ 3.2:1 まで持ち上げている。
--   （黒だけは前景ではなく背景として使われる色なので、この床の対象外）
-- ---------------------------------------------------------------------
config.colors = {
  foreground = '#49F257',
  background = '#030B04',

  cursor_bg = '#79F283',
  cursor_fg = '#030B04',
  cursor_border = '#79F283',
  -- IME 変換中のカーソル。use_ime = true なので明示しておく
  compose_cursor = '#C9FFCE',

  selection_fg = '#C9FFCE',
  selection_bg = '#1D8025',

  scrollbar_thumb = '#155C1B',
  split = '#1B7A23',

  ansi = {
    '#071808', -- black
    '#1D8C26', -- red
    '#2CB837', -- green
    '#42E550', -- yellow
    '#17701E', -- blue
    '#229D2C', -- magenta
    '#33C83F', -- cyan
    '#4DF55B', -- white
  },
  brights = {
    '#0F3412', -- bright black
    '#2DAC37', -- bright red
    '#39CF45', -- bright green
    '#79F283', -- bright yellow
    '#279630', -- bright blue
    '#30B93C', -- bright magenta
    '#43DC50', -- bright cyan
    '#C9FFCE', -- bright white  ← 焼き付き気味の白緑
  },

  visual_bell = '#39CF45',

  -- copy-mode / quick-select は既定だと黄や青の実色を出してきて
  -- 単色管の嘘が破れるので、ここも緑に寄せておく
  copy_mode_active_highlight_bg = { Color = '#1D8025' },
  copy_mode_active_highlight_fg = { Color = '#C9FFCE' },
  copy_mode_inactive_highlight_bg = { Color = '#0F3412' },
  copy_mode_inactive_highlight_fg = { Color = '#42E550' },

  quick_select_label_bg = { Color = '#79F283' },
  quick_select_label_fg = { Color = '#030B04' },
  quick_select_match_bg = { Color = '#1D8025' },
  quick_select_match_fg = { Color = '#C9FFCE' },

  tab_bar = {
    background = '#030B04',
    active_tab = { bg_color = '#17701E', fg_color = '#79F283', intensity = 'Bold' },
    inactive_tab = { bg_color = '#071808', fg_color = '#1D8C26' },
    inactive_tab_hover = { bg_color = '#0F3412', fg_color = '#2CB837' },
    new_tab = { bg_color = '#071808', fg_color = '#1D8C26' },
    new_tab_hover = { bg_color = '#0F3412', fg_color = '#39CF45' },
  },
}

config.command_palette_bg_color = '#071808'
config.command_palette_fg_color = '#49F257'
config.char_select_bg_color = '#071808'
config.char_select_fg_color = '#49F257'

-- ---------------------------------------------------------------------
-- 画面レイヤ: 黒 → 中央がにじむ放射グラデーション → 走査線 → ビネット
-- ---------------------------------------------------------------------
config.background = {
  -- 1. 素の黒
  {
    source = { Color = '#030B04' },
    width = '100%',
    height = '100%',
  },
  -- 2. 管の中央がほのかに光るムラ + ノイズ（粒状感）
  --    このレイヤは不透明なので、画面中央では 1 の素の黒を完全に上書きする。
  --    つまり内側の色がそのまま「画面中央の実効背景」になる。
  --    ここを明るくすると ansi パレットの床（blue 3.2:1）をそのまま食う。
  --    内側 G=46 だと中央で blue が 2.39:1 まで落ちたので G=20 に下げた。
  --    素の黒に対してはまだ 2 倍あり、中央が光るムラとしては十分見える。
  --
  --    なお本物の CRT らしさは「文字の周りのブルーム」であって画面全体の
  --    持ち上がりではない。WezTerm はシェーダを持たずブルームを出せないので
  --    これは代用でしかなく、効果の形が違う。コントラストを払いすぎないこと。
  {
    source = {
      Gradient = {
        colors = { '#051406', '#030B04' },
        orientation = { Radial = { cx = 0.5, cy = 0.45, radius = 1.15 } },
        noise = 96,
      },
    },
    width = '100%',
    height = '100%',
  },
  -- 3. 走査線
  --    セル高は 16px なので、タイルの高さは 16 の約数でなければならない。
  --    3px だと割り切れず、行ごとに走査線の位相がずれて、
  --    グリフの横棒に暗線が乗る行と乗らない行が混ざる。4px なら 1 セル
  --    ちょうど 4 本で、全行が同じ見え方になる。
  --    タイルの濃度 (平均 alpha 70 / 最大 150) は 3px 版と同じなので、
  --    周期だけが変わって画面全体の明るさは変わらない。
  {
    source = { File = asset 'scanlines.png' },
    width = '100%',
    height = '4px',
    repeat_x = 'Repeat',
    repeat_y = 'Repeat',
    opacity = 0.55,
  },
  -- 4. ビネット（管の隅が落ちる + ブラウン管の角丸）
  --    WezTerm はシェーダを持たないので樽型歪みは再現できない。
  --    「隅が暗い」だけでも CRT らしさはかなり出る。
  --    強度は文字が読める範囲に抑えてある（中央 0 / 辺の中央 0.55 /
  --    隅 0.72、最も濃い縁の帯は window_padding の内側に収まる幅）。
  {
    source = { File = asset 'vignette.png' },
    width = '100%',
    height = '100%',
    repeat_x = 'NoRepeat',
    repeat_y = 'NoRepeat',
  },
}

-- ---------------------------------------------------------------------
-- カーソル: 蛍光体の残光っぽく明滅させる
-- ---------------------------------------------------------------------
config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 600
config.cursor_blink_ease_in = 'EaseOut'
config.cursor_blink_ease_out = 'EaseIn'
config.animation_fps = 60

-- ベル: 音は消して画面を緑に一瞬フラッシュ
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_function = 'EaseIn',
  fade_in_duration_ms = 75,
  fade_out_function = 'EaseOut',
  fade_out_duration_ms = 150,
}

-- ---------------------------------------------------------------------
-- ウィンドウ
-- ---------------------------------------------------------------------
config.window_padding = { left = 24, right = 24, top = 20, bottom = 20 }
config.window_decorations = 'RESIZE'
config.enable_scroll_bar = false
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true

-- 非アクティブ pane の落とし方。
-- 単一蛍光体の管は灰色を出せないので、彩度を下げるとグレーが混じって
-- 「緑しか出ない管」という嘘が破れる。彩度は 1.0 のまま、輝度だけで落とす。
config.inactive_pane_hsb = { saturation = 1.0, brightness = 0.55 }

-- ---------------------------------------------------------------------
-- シェル (既存設定を維持)
-- ---------------------------------------------------------------------
config.use_ime = true

-- Windows でだけ Git Bash を既定シェルにする。
-- 他 OS では WezTerm 既定のログインシェルに任せる。
if is_windows then
  local git_bash = 'C:\\Program Files\\Git\\bin\\bash.exe'

  config.default_prog = {
    git_bash,
    '-l', -- login shell（重要）
  }
  config.launch_menu = {
    {
      label = 'Git Bash',
      args = { git_bash, '-l' },
    },
    {
      label = 'PowerShell',
      args = { 'powershell.exe', '-NoLogo' },
    },
    {
      label = 'Command Prompt',
      args = { 'cmd.exe' },
    },
  }
end

return config
