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

-- 最初に見つかったものを返す（無ければ第1候補）
local function first_existing(paths)
  for _, p in ipairs(paths) do
    local fh = io.open(p, 'r')
    if fh then
      fh:close()
      return p
    end
  end
  return paths[1]
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
  -- Nerd Font のグリフは素だと 16px = 2セル分あり隣に食い込むので半分に縮める
  { family = 'Symbols Nerd Font Mono', scale = 0.5 }, -- starship の  ❯ など
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
--   本物の単色 CRT は色を出せないので、ANSI 16 色は
--   「元の色の知覚輝度」に対応する緑の階調へ写像している。
--   (青 0.11 < 赤 0.30 < 紫 0.41 < 緑 0.59 < 水 0.70 < 黄 0.89 < 白 1.0)
-- ---------------------------------------------------------------------
config.colors = {
  foreground = '#3DF271',
  background = '#030B05',

  cursor_bg = '#7DFFA0',
  cursor_fg = '#030B05',
  cursor_border = '#7DFFA0',

  selection_fg = '#C9FFDA',
  selection_bg = '#1D8039',

  scrollbar_thumb = '#155C29',
  split = '#1B7A35',

  ansi = {
    '#06180C', -- black
    '#1B7A35', -- red
    '#2FBF56', -- green
    '#43E874', -- yellow
    '#0F4A22', -- blue
    '#23933F', -- magenta
    '#37D163', -- cyan
    '#4DF57C', -- white
  },
  brights = {
    '#0D3318', -- bright black
    '#2CA84B', -- bright red
    '#4AF676', -- bright green  ← 主役の蛍光緑
    '#7DFFA0', -- bright yellow
    '#1E6B31', -- bright blue
    '#35BE58', -- bright magenta
    '#5BFF8E', -- bright cyan
    '#C9FFDA', -- bright white  ← 焼き付き気味の白緑
  },

  visual_bell = '#4AF676',

  tab_bar = {
    background = '#030B05',
    active_tab = { bg_color = '#0F4A22', fg_color = '#7DFFA0', intensity = 'Bold' },
    inactive_tab = { bg_color = '#06180C', fg_color = '#1B7A35' },
    inactive_tab_hover = { bg_color = '#0D3318', fg_color = '#2FBF56' },
    new_tab = { bg_color = '#06180C', fg_color = '#1B7A35' },
    new_tab_hover = { bg_color = '#0D3318', fg_color = '#4AF676' },
  },
}

-- ---------------------------------------------------------------------
-- 画面レイヤ: 黒 → 中央がにじむ放射グラデーション → 走査線
-- ---------------------------------------------------------------------
config.background = {
  -- 1. 素の黒
  {
    source = { Color = '#030B05' },
    width = '100%',
    height = '100%',
  },
  -- 2. 管の中央がほのかに光るムラ + ノイズ（粒状感）
  {
    source = {
      Gradient = {
        colors = { '#0C2E17', '#030B05' },
        orientation = { Radial = { cx = 0.5, cy = 0.45, radius = 1.15 } },
        noise = 96,
      },
    },
    width = '100%',
    height = '100%',
  },
  -- 3. 走査線 (2x3px のタイルを敷き詰め)
  {
    source = {
      File = first_existing {
        ASSET_DIRS[1] .. '/scanlines.png',
        ASSET_DIRS[2] .. '/scanlines.png',
        ASSET_DIRS[3] .. '/scanlines.png',
      },
    },
    width = '100%',
    height = '3px',
    repeat_x = 'Repeat',
    repeat_y = 'Repeat',
    opacity = 0.55,
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
config.inactive_pane_hsb = { saturation = 0.7, brightness = 0.6 }

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
