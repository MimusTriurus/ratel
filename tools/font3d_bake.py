"""Bakes the 3D preview's two bitmap fonts (Level3DFont): classic out of
Press Start 2P, modern out of Black Ops One.

    python tools/font3d_bake.py

Modern, BlackOpsOne-Regular.ttf (SIL Open Font License 1.1, OFL-BlackOpsOne.txt
beside it), is drawn smoothed, its letters their own widths, MODERN_CELL tall,
into assets/images/font3d_modern.png and .xml, and each glyph's advance, in
pixels of a MODERN_CELL-tall glyph, into font3d_modern.json; the digits all
take the widest one's, so that a number rolling up does not shift about. Its
shadow is MODERN_SHADOW down and to the right. The classic one:

assets/fonts/PressStart2P-Regular.ttf (SIL Open Font License 1.1, OFL-PressStart2P.txt
beside it) is drawn on its own 8x8 grid without smoothing and blown up four
times, nearest, into the same layout as assets/images/font.png, the 2D game's,
so that Atlas reads it as it reads that: a 32x32 cell a glyph, named
font-<colour>-<name>.png in assets/images/font3d.xml, the names
Level3DFont.name_of gives. Two colours, as the 3D preview uses of the game's:

    black   white letters, a black shadow at 80% (the game's sheet calls it
            black for its shadow)
    gray    white letters, an opaque grey shadow

the shadow one font pixel down and to the right, under the letter. Whether it
is drawn sharp or smoothed is Level3DFont.style's, not the sheet's. The 2D game
keeps the game's own font; only src/game3d reads this one (Level3DFont).
"""

import json

from PIL import Image, ImageDraw, ImageFont

TTF = 'assets/fonts/PressStart2P-Regular.ttf'
PNG = 'assets/images/font3d.png'
XML = 'assets/images/font3d.xml'
# What it holds: the game's CHARS (Main.CHARS) and what that font has not got.
CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ.,'-0123456789©!:()&`\" +/?%#"
SCALE = 4
CELL = 8 * SCALE
# Clear round each cell: the smoothed and modern fonts (Level3DFont.filter) sample it
# filtered, from its mipmaps, and a cell's neighbours would bleed into it.
GUTTER = 4
COLOURS = {
    'black': (0, 0, 0, 204),
    'gray': (102, 102, 102, 255),
}
NAMES = {
    '.': 'period', ',': 'comma', "'": 'apostrophe', '!': 'exclamation', '-': 'hyphen',
    '©': 'copyright', ' ': 'space', ':': 'colon', '(': 'left-paren', ')': 'right-paren',
    '&': 'ampersand', '`': 'left-quote', '"': 'right-quote', '+': 'plus', '/': 'slash',
    '?': 'question', '%': 'percent', '#': 'hash',
}


def glyph(font, ch):
    """The glyph's 8x8 mask, 255 where it is lit."""
    im = Image.new('L', (8, 8), 0)
    draw = ImageDraw.Draw(im)
    draw.fontmode = '1'
    draw.text((0, 0), ch, font=font, fill=255)
    return im


def main():
    font = ImageFont.truetype(TTF, 8)
    per_row = 512 // (CELL + GUTTER * 2)
    sheet = Image.new('RGBA', (512, 512), (0, 0, 0, 0))
    lines = ['<sheet>']
    i = 0
    for colour, shadow in COLOURS.items():
        for ch in CHARS:
            mask = glyph(font, ch).resize((CELL, CELL), Image.NEAREST)
            cell = Image.new('RGBA', (CELL, CELL), (0, 0, 0, 0))
            under = Image.new('RGBA', (CELL, CELL), shadow)
            cell.paste(under, (SCALE, SCALE), mask)
            cell.paste(Image.new('RGBA', (CELL, CELL), (255, 255, 255, 255)), (0, 0), mask)
            x = GUTTER + (i % per_row) * (CELL + GUTTER * 2)
            y = GUTTER + (i // per_row) * (CELL + GUTTER * 2)
            sheet.paste(cell, (x, y))
            name = NAMES.get(ch, ch)
            lines.append('\t<sprite name="font-%s-%s.png" x="%d" y="%d" width="%d" height="%d" />'
                         % (colour, name, x, y, CELL, CELL))
            i += 1
    lines.append('</sheet>')
    sheet.save(PNG)
    with open(XML, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    print('%d glyphs into %s' % (i, PNG))


MODERN_TTF = 'assets/fonts/BlackOpsOne-Regular.ttf'
MODERN_PNG = 'assets/images/font3d_modern.png'
MODERN_XML = 'assets/images/font3d_modern.xml'
MODERN_JSON = 'assets/images/font3d_modern.json'
MODERN_CELL = 64            # a glyph's height in the sheet
MODERN_CAPS = 54            # the capitals' height in it
MODERN_TOP = 3              # their top's
MODERN_SHADOW = 4
MODERN_TRACKING = 3         # added to every advance
MODERN_GUTTER = 4


def modern():
    probe = ImageFont.truetype(MODERN_TTF, 100)
    top, bottom = probe.getbbox('H')[1], probe.getbbox('H')[3]
    size = round(100 * MODERN_CAPS / (bottom - top))
    font = ImageFont.truetype(MODERN_TTF, size)
    lift = font.getbbox('H')[1] - MODERN_TOP
    digit = max(font.getlength(d) for d in '0123456789')
    sheet = Image.new('RGBA', (1024, 1024), (0, 0, 0, 0))
    lines = ['<sheet>']
    advances = {}
    x, y = MODERN_GUTTER, MODERN_GUTTER
    n = 0
    for colour, shadow in COLOURS.items():
        for ch in CHARS:
            advance = digit if ch.isdigit() else font.getlength(ch)
            width = int(advance + 0.999) + MODERN_SHADOW + 2
            if x + width + MODERN_GUTTER > sheet.width:
                x = MODERN_GUTTER
                y += MODERN_CELL + MODERN_GUTTER * 2
            mask = Image.new('L', (width, MODERN_CELL), 0)
            # A digit centred in the widest one's width.
            offset = (digit - font.getlength(ch)) * 0.5 if ch.isdigit() else 0.0
            ImageDraw.Draw(mask).text((offset, -lift), ch, font=font, fill=255)
            cell = Image.new('RGBA', (width, MODERN_CELL), (0, 0, 0, 0))
            cell.paste(Image.new('RGBA', mask.size, shadow), (MODERN_SHADOW, MODERN_SHADOW), mask)
            cell.alpha_composite(Image.merge('RGBA', [Image.new('L', mask.size, 255)] * 3 + [mask]))
            sheet.paste(cell, (x, y))
            name = NAMES.get(ch, ch)
            lines.append('\t<sprite name="font-%s-%s.png" x="%d" y="%d" width="%d" height="%d" />'
                         % (colour, name, x, y, width, MODERN_CELL))
            advances[name] = round(advance + MODERN_TRACKING, 2)
            x += width + MODERN_GUTTER * 2
            n += 1
    lines.append('</sheet>')
    sheet.save(MODERN_PNG)
    with open(MODERN_XML, 'w', encoding='utf-8', newline='\n') as f:
        f.write('\n'.join(lines) + '\n')
    with open(MODERN_JSON, 'w', encoding='utf-8', newline='\n') as f:
        json.dump({"cell": MODERN_CELL, "advances": advances}, f, indent=1, sort_keys=True)
        f.write('\n')
    print('%d glyphs into %s, size %d' % (n, MODERN_PNG, size))


if __name__ == '__main__':
    main()
    modern()
