#!/usr/bin/env python3
"""緑蛍光管テーマのパレットと背景画像を生成する。

配置には要らない。テーマを触るときだけ使う開発用スクリプト。
Python 3 標準ライブラリだけで動く (Pillow 等は不要)。

  python3 scripts/gen-theme.py            .config/wezterm/*.png を書き出し、
                                          パレットと検査結果を表示する
  python3 scripts/gen-theme.py --dry-run  画像を書かずに表示だけ
  python3 scripts/gen-theme.py --inspect FILE
                                          既存の PNG の中身を覗く

.wezterm.lua / .tmux.conf / .config/starship.toml の色は、ここが出力した値を
手で貼っている。色相や床の値をいじったら 3 つとも貼り直すこと。
"""
import math, os, struct, sys, zlib

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(REPO, '.config', 'wezterm')

# ============================================================ PNG 出力 / 読み取り
def write_png(path, w, h, rgba_rows):
    raw = b''.join(b'\x00' + bytes(row) for row in rgba_rows)
    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data
                + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))
    with open(path, 'wb') as f:
        f.write(b'\x89PNG\r\n\x1a\n'
                + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
                + chunk(b'IDAT', zlib.compress(raw, 9))
                + chunk(b'IEND', b''))
    return os.path.getsize(path)

def read_png(path):
    d = open(path, 'rb').read()
    i, idat, ihdr = 8, b'', None
    while i < len(d):
        ln = struct.unpack('>I', d[i:i+4])[0]
        tag, body = d[i+4:i+8], d[i+8:i+8+ln]
        if tag == b'IHDR': ihdr = struct.unpack('>IIBBBBB', body)
        if tag == b'IDAT': idat += body
        i += 12 + ln
    w, h, depth, ctype = ihdr[0], ihdr[1], ihdr[2], ihdr[3]
    bpp = {0:1, 2:3, 3:1, 4:2, 6:4}[ctype] * depth // 8
    raw, stride = zlib.decompress(idat), w * bpp
    out, prev, p = [], bytearray(stride), 0
    for _ in range(h):
        f = raw[p]; p += 1
        line = bytearray(raw[p:p+stride]); p += stride
        for x in range(stride):
            a = line[x-bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x-bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pp = a + b - c
                pa, pb, pc = abs(pp-a), abs(pp-b), abs(pp-c)
                line[x] = (line[x] + (a if (pa <= pb and pa <= pc)
                                      else (b if pb <= pc else c))) & 255
        out.append(bytes(line)); prev = line
    return w, h, bpp, out

# ==================================================================== 測色
def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def rel_lum(rgb):
    return 0.2126*_lin(rgb[0]) + 0.7152*_lin(rgb[1]) + 0.0722*_lin(rgb[2])

def contrast(a, b):
    la, lb = rel_lum(a), rel_lum(b)
    return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)

def hexs(rgb):
    return '#%02X%02X%02X' % rgb

def hue_of(rgb):
    r, g, b = [c / 255 for c in rgb]
    mx, mn = max(r, g, b), min(r, g, b)
    if mx == mn: return 0.0
    d = mx - mn
    h = ((g-b)/d) % 6 if mx == r else ((b-r)/d + 2 if mx == g else (r-g)/d + 4)
    return h * 60

# ============================================================ 蛍光体パレット
# 単一蛍光体の管は 1 つの色相しか出せない。あとは全部「明るさ」。
# P1 蛍光体のピークは 525nm 付近＝黄緑。以前の 137° はシアン寄りのミントで、
# 単色 CRT というより Matrix 寄りの緑だった。
HUE = 125.0
K = HUE / 60.0 - 2.0   # (B-R)/(G-min)。この比を保つと色相が固定される

def phosphor(g, desat):
    """緑の値 g を色相 HUE の色にする。desat は R/G 比 (0=純色, 1=白)。"""
    g = max(0, min(255, int(round(g))))
    r = g * desat
    b = r + K * (g - r)
    return (int(round(r)), g, int(round(max(0, min(255, b)))))

# 元の色の知覚輝度。このテーマの土台になっている対応表。
W = {'black': 0.00, 'red': 0.30, 'green': 0.59, 'yellow': 0.89,
     'blue': 0.11, 'magenta': 0.41, 'cyan': 0.70, 'white': 1.00}
ORDER = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white']

def ramp(gmin, gmax, dmin, dmax, dexp, black_g, black_d):
    """黒以外の 7 色を [gmin,gmax] に写す。
    黒は前景ではなく背景として使う色なので、この床の対象外。"""
    lo, hi = W['blue'], W['white']
    out = {}
    for name in ORDER:
        if name == 'black':
            out[name] = phosphor(black_g, black_d)
            continue
        t = (W[name] - lo) / (hi - lo)
        out[name] = phosphor(gmin + t * (gmax - gmin),
                             dmin + (dmax - dmin) * (t ** dexp))
    return out

# gmin が床。知覚輝度をそのまま 0 から使うと青が背景に対して 1.9:1 まで沈み、
# ls のディレクトリ名や git diff が読めなくなる。順序は保ったまま 3.2:1 まで上げる。
# dmin/dmax/dexp は元パレットの彩度カーブを実測してフィットした値なので、
# 変わるのは色相と床だけで、テーマの性格は保たれる。
NORMAL = ramp(112, 245, 0.203, 0.314, 1.9, black_g=24, black_d=0.28)
# bright は normal の red より上から始める (でないと bright blue と衝突する)
BRIGHTS = ramp(150, 255, 0.260, 0.790, 6.0, black_g=52, black_d=0.28)

BG        = phosphor(11,  0.28)   # 管の地の色
FG        = phosphor(242, 0.300)  # 通常の文字
# 背景レイヤ2 のグラデーション内側。このレイヤは不透明なので、画面中央では
# 素の黒を完全に上書きする = ここがそのまま「画面中央の実効背景」になる。
# 明るくすると下のパレットの床をそのまま食う (G=46 だと中央で blue が
# 2.39:1 まで落ちた)。G=20 なら 3.0:1 を保ちつつ素の黒の 2 倍で、
# 中央が光るムラとしては十分見える。
GLOW      = phosphor(20,  0.260)
SEL_BG    = phosphor(128, 0.227)
SCROLLBAR = phosphor(92,  0.228)
SPLIT     = phosphor(122, 0.221)

def check():
    print('=== パレット (色相 %.0f°) ===' % HUE)
    print('  周辺の背景 %s / 画面中央の実効背景 %s (中央は %.1f 倍明るい)'
          % (hexs(BG), hexs(GLOW), rel_lum(GLOW) / rel_lum(BG)))
    print('%-9s %-8s %5s %8s %8s | %-8s %8s %8s'
          % ('name', 'normal', 'hue', '中央', '周辺', 'bright', '中央', '周辺'))
    for n in ORDER:
        a, b = NORMAL[n], BRIGHTS[n]
        print('%-9s %-8s %5.1f %6.2f:1 %6.2f:1 | %-8s %6.2f:1 %6.2f:1'
              % (n, hexs(a), hue_of(a), contrast(a, GLOW), contrast(a, BG),
                 hexs(b), contrast(b, GLOW), contrast(b, BG)))
    print('%-9s %-8s %5.1f %6.2f:1 %6.2f:1'
          % ('fg', hexs(FG), hue_of(FG), contrast(FG, GLOW), contrast(FG, BG)))

    print('\n=== 検査 ===')
    bad = 0
    # コントラストは素の背景色ではなく「画面に実際に出ている背景」で測る。
    # 背景レイヤ2 のグラデーションは不透明なので、画面中央では素の黒が
    # 完全に上書きされる。BG だけ見ていると床を割っていても気づけない。
    for label, ref in (('中央', GLOW), ('周辺', BG)):
        for tier, pal in (('normal', NORMAL), ('bright', BRIGHTS)):
            for n in ORDER:
                if n == 'black':
                    continue       # 背景色なので暗くて当然
                c = contrast(pal[n], ref)
                if c < 3.0:
                    print('  NG  画面%s で %s %s が %.2f:1 しかない'
                          % (label, tier, n, c)); bad += 1
    for n in ORDER:
        d = abs(NORMAL[n][1] - BRIGHTS[n][1])
        if d < 10:
            print('  NG  %s の normal と bright の差が %d しかない' % (n, d)); bad += 1
    for tier, pal in (('normal', NORMAL), ('bright', BRIGHTS)):
        gs = sorted((pal[n][1], n) for n in ORDER if n != 'black')
        for (g1, n1), (g2, n2) in zip(gs, gs[1:]):
            if g2 - g1 < 10:
                print('  NG  %s の %s と %s の差が %d しかない'
                      % (tier, n1, n2, g2 - g1)); bad += 1
    seen = {}
    for tier, pal in (('', NORMAL), ('bright ', BRIGHTS)):
        for n in ORDER:
            h = hexs(pal[n])
            if h in seen:
                print('  NG  %s が重複: %s / %s%s' % (h, seen[h], tier, n)); bad += 1
            seen[h] = tier + n
    print('  問題なし' if not bad else '  %d 件' % bad)
    return bad

# ==================================================================== 背景画像
# 走査線タイル。セル高は 16px なので、タイルの高さは 16 の約数でなければ
# ならない。3px だと割り切れず、行ごとに走査線の位相がずれて、グリフの
# 横棒に暗線が乗る行と乗らない行が混ざる。4px なら 1 セルちょうど 4 本。
# alpha は 3px 版と同じ濃度 (平均 70 / 最大 150) に合わせてあるので、
# 周期だけが変わって画面全体の明るさは変わらない。
SCAN_PROFILE = [0, 45, 150, 85]

def gen_scanlines(path):
    return write_png(path, 2, len(SCAN_PROFILE),
                     [bytearray([0, 0, 0, a] * 2) for a in SCAN_PROFILE])

# ビネット。3 つの項を max() で合成する。
#   radial ... 管の輝度の落ち方。文字を潰さない程度に緩く
#   corner ... ブラウン管の角丸。隅だけに効き、辺には効かない
#   border ... 縁の影。window_padding の内側に収まる幅にしてある
VIG_R0, VIG_P, VIG_A = 0.28, 1.9, 0.62
COR_RAD, COR_START, COR_P, COR_A = 0.16, 0.05, 1.4, 0.72
BOR_START, BOR_P, BOR_A = 0.97, 1.2, 0.55

def vignette_alpha(dx, dy):
    """dx, dy はウィンドウ中心からの位置で [-1,1]。"""
    r = math.hypot(dx, dy) / math.sqrt(2)
    a = (max(0.0, (r - VIG_R0) / (1 - VIG_R0)) ** VIG_P) * VIG_A

    k = COR_RAD * 2
    qx = max(abs(dx) - (1 - k), 0.0) / k
    qy = max(abs(dy) - (1 - k), 0.0) / k
    d = math.hypot(qx, qy) - 1.0      # 辺の上で 0、隅で 0.414
    if d > COR_START:
        u = min(1.0, (d - COR_START) / (math.sqrt(2) - 1 - COR_START))
        a = max(a, (u ** COR_P) * COR_A)

    e = max(abs(dx), abs(dy))
    if e > BOR_START:
        a = max(a, (((e - BOR_START) / (1 - BOR_START)) ** BOR_P) * BOR_A)
    return min(1.0, a)

def gen_vignette(path, w=320, h=200):
    rows = []
    for y in range(h):
        dy = ((y + 0.5) / h - 0.5) * 2
        row = bytearray()
        for x in range(w):
            dx = ((x + 0.5) / w - 0.5) * 2
            row += bytes((0, 0, 0, int(round(vignette_alpha(dx, dy) * 255))))
        rows.append(row)
    return write_png(path, w, h, rows)

def preview_vignette(cols=72, lines=22):
    shade = ' .:-=+*#%@'
    print('\n=== ビネット (暗さ; @ が最も暗い) ===')
    for j in range(lines):
        dy = ((j + 0.5) / lines - 0.5) * 2
        print('  ' + ''.join(
            shade[min(9, int(vignette_alpha(((i + 0.5) / cols - 0.5) * 2, dy) * 10))]
            for i in range(cols)))
    for lbl, p in [('中心', (0, 0)), ('中間', (0.5, 0.5)), ('8割', (0.8, 0.8)),
                   ('辺の中央', (1, 0)), ('隅', (1, 1))]:
        print('  %-9s %.3f' % (lbl, vignette_alpha(*p)))

# ==================================================================== 貼り付け用
def emit():
    n, b = NORMAL, BRIGHTS
    print('\n=== .wezterm.lua ===')
    print("  foreground = '%s',"    % hexs(FG))
    print("  background = '%s',"    % hexs(BG))
    print("  cursor_bg / cursor_border = '%s',  cursor_fg = '%s',"
          % (hexs(b['yellow']), hexs(BG)))
    print("  compose_cursor / selection_fg = '%s',  selection_bg = '%s',"
          % (hexs(b['white']), hexs(SEL_BG)))
    print("  scrollbar_thumb = '%s',  split = '%s',"
          % (hexs(SCROLLBAR), hexs(SPLIT)))
    print("  visual_bell = '%s',"   % hexs(b['green']))
    print('  ansi = {')
    for k in ORDER:
        print("    '%s', -- %s" % (hexs(n[k]), k))
    print('  },')
    print('  brights = {')
    for k in ORDER:
        print("    '%s', -- bright %s" % (hexs(b[k]), k))
    print('  },')
    print("  背景グラデーション: 内側 '%s' -> 外側 '%s'" % (hexs(GLOW), hexs(BG)))

    print('\n=== .tmux.conf / .config/starship.toml で使っている色 ===')
    for k in ORDER:
        print('  %-9s %s   bright %s' % (k, hexs(n[k]), hexs(b[k])))
    print('  %-9s %s' % ('bg', hexs(BG)))
    print('  %-9s %s' % ('fg', hexs(FG)))
    print('  %-9s %s' % ('sel_bg', hexs(SEL_BG)))
    print('  %-9s %s' % ('scroll', hexs(SCROLLBAR)))

def main():
    args = sys.argv[1:]
    if args and args[0] == '--inspect':
        w, h, bpp, rows = read_png(args[1])
        print('%dx%d bpp=%d' % (w, h, bpp))
        for y, r in enumerate(rows[:16]):
            print(' y=%d %s' % (y, [tuple(r[i:i+bpp]) for i in range(0, len(r), bpp)][:16]))
        return 0

    bad = check()
    emit()
    preview_vignette()
    if '--dry-run' in args:
        print('\n--dry-run のため画像は書いていない')
    else:
        os.makedirs(ASSETS, exist_ok=True)
        print('\nscanlines.png %5d bytes  %s'
              % (gen_scanlines(os.path.join(ASSETS, 'scanlines.png')), ASSETS))
        print('vignette.png  %5d bytes  %s'
              % (gen_vignette(os.path.join(ASSETS, 'vignette.png')), ASSETS))
        print('\n配置に反映するには: bash scripts/deploy.sh')
    return 1 if bad else 0

if __name__ == '__main__':
    sys.exit(main())
