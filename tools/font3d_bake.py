"""Bakes the 3D preview's bitmap font out of Press Start 2P.

    python tools/font3d_bake.py

assets/fonts/PressStart2P-Regular.ttf (SIL Open Font License 1.1, OFL.txt
beside it) is drawn on its own 8x8 grid without smoothing and blown up four
times, nearest, into the same layout as assets/images/font.png, the 2D game's,
so that Atlas reads it as it reads that: a 32x32 cell a glyph, named
font-<colour>-<name>.png in assets/images/font3d.xml, the names
Level3DFont.name_of gives. Two colours, as the 3D preview uses of the game's:

    black   white letters, a black shadow at 80% (the game's sheet calls it
            black for its shadow)
    gray    white letters, an opaque grey shadow

the shadow one font pixel down and to the right, under the letter. Whether it
is drawn sharp or smoothed is Level3DFont.smooth's, not the sheet's. The 2D game
keeps the game's own font; only src/tools reads this one (Level3DFont).
"""

from PIL import Image, ImageDraw, ImageFont

TTF = 'assets/fonts/PressStart2P-Regular.ttf'
PNG = 'assets/images/font3d.png'
XML = 'assets/images/font3d.xml'
# What it holds: the game's CHARS (Main.CHARS) and what that font has not got.
CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ.,'-0123456789©!:()&`\" +/?%#"
SCALE = 4
CELL = 8 * SCALE
# Clear round each cell: the smoothed font (Level3DFont.smooth) samples it
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


if __name__ == '__main__':
    main()
