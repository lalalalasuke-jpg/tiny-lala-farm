"""Noto Sans JP（可変フォント）から、ゲームで使う文字だけに絞ったフォントを作る。

使い方（uv が必要）:
  uv run --with fonttools python tools/make_font_subset.py <NotoSansJP[wght].ttf> fonts/NotoSansJP-Subset.ttf

入れる文字: ASCII・記号・かな・全角英数・JIS第1/第2水準の漢字（Shift_JIS で表せる文字 ＝ 約7,000字）。
元のフォント: https://github.com/google/fonts/tree/main/ofl/notosansjp （SIL Open Font License、fonts/OFL.txt）
"""
import sys

from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

src, dst = sys.argv[1], sys.argv[2]

chars = set()
for cp in range(0x20, 0x10000):
    ch = chr(cp)
    if 0xD800 <= cp <= 0xDFFF:
        continue
    try:
        ch.encode("shift_jis")
    except UnicodeEncodeError:
        continue
    chars.add(cp)
chars.update(range(0x20, 0x7F))
chars.update([0x2026, 0x2605, 0x2606, 0x30FC, 0xFF5E, 0x301C])  # … ★ ☆ ー ～ 〜

font = TTFont(src)
font = instancer.instantiateVariableFont(font, {"wght": 400})  # 太さを Regular に固定
opts = subset.Options()
opts.layout_features = ["*"]
opts.name_IDs = ["*"]
opts.notdef_outline = True
sub = subset.Subsetter(options=opts)
sub.populate(unicodes=sorted(chars))
sub.subset(font)
font.save(dst)
print(f"{len(chars)} chars -> {dst}")
