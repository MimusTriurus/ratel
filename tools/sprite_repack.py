#!/usr/bin/env python3
"""Repack sprites-1..9 into one atlas per logical object.

The nine source sheets are packing-driven: sprites-1 holds the player, brown
tanks, soldiers, mines and lasers only because they happened to fit together.
This splits them by name stem instead -- brown-tank.png holds exactly the three
brown-tank frames -- so the file tree names what it contains.

Pixels are copied verbatim out of the source sheets, so the result is the same
art in a different arrangement; verify.py checks that region by region.

Runtime lookup goes through the generated index.xml rather than a directory
scan, because an exported build ships the .xml files as raw includes and
DirAccess over them is not something to rely on.

Run from the repo root:  python tools/sprite_repack.py
"""
import glob
import os
import re
import sys
from collections import defaultdict

from PIL import Image

IMAGES = os.path.join("assets", "images")
OUT_DIR = os.path.join(IMAGES, "sprites")
PAD = 1                     # transparent gutter, as in the source sheets
ENTRY = re.compile(
    r'name="([^"]+)"\s+x="(\d+)"\s+y="(\d+)"\s+width="(\d+)"\s+height="(\d+)"')

# A trailing -N is a frame index, except where it is part of the name: the
# friendly helicopter's wings are named for their blade angle, not a sequence.
NOT_A_FRAME = ("-15", "-30")


def group_of(name: str) -> str:
    """brown-tank-0.png -> brown-tank"""
    stem = name[:-4] if name.endswith(".png") else name
    if stem.endswith(NOT_A_FRAME):
        return stem
    return re.sub(r"-\d+$", "", stem)


def read_sheets():
    """[(sprite_name, sheet_name, x, y, w, h)] over every sprites-N sheet."""
    paths = sorted(glob.glob(os.path.join(IMAGES, "sprites-*.xml")),
                   key=lambda p: int(re.search(r"-(\d+)\.xml$", p).group(1)))
    out = []
    for path in paths:
        sheet = os.path.basename(path)[:-4]
        with open(path, encoding="utf-8") as f:
            text = f.read()
        for m in ENTRY.finditer(text):
            out.append((m.group(1), sheet,
                        int(m.group(2)), int(m.group(3)),
                        int(m.group(4)), int(m.group(5))))
    return out


def shelf_pack(sizes, width):
    """Place (w, h) boxes tallest-first into rows. Returns positions or None."""
    order = sorted(range(len(sizes)),
                   key=lambda i: (-sizes[i][1], -sizes[i][0]))
    pos = [None] * len(sizes)
    x = y = row_h = 0
    for i in order:
        w, h = sizes[i][0] + PAD, sizes[i][1] + PAD
        if PAD + x + w > width:
            x, y, row_h = 0, y + row_h, 0
        if PAD + x + w > width:
            return None
        pos[i] = (PAD + x, PAD + y)
        x += w
        row_h = max(row_h, h)
    return pos, y + row_h + PAD


def pow2_at_least(n):
    p = 1
    while p < n:
        p <<= 1
    return p


def pack_group(frames):
    """Pick the tidiest canvas that holds the group.

    Candidate row widths are powers of two, but the canvas is then cropped to
    what the rows actually use -- Godot has no power-of-two requirement, and a
    128x1024 strip for six tank frames wastes both memory and the eye. Area
    barely moves between candidates (the frames are what they are), so the
    tie-break that matters is squareness.
    """
    sizes = [(w, h) for _, _, _, _, w, h in frames]
    min_w = pow2_at_least(max(w for w, _ in sizes) + 2 * PAD)
    best = None
    width = min_w
    while width <= 2048:
        packed = shelf_pack(sizes, width)
        if packed is not None:
            pos, used_h = packed
            used_w = max(x + w for (x, _), (w, _) in zip(pos, sizes)) + PAD
            score = (used_w * used_h,
                     abs(used_w / used_h - 1.0) if used_h else 0.0)
            if best is None or score < best[0]:
                best = (score, used_w, used_h, pos)
        width <<= 1
    if best is None:
        raise RuntimeError("cannot pack group")
    _, width, height, pos = best
    return width, height, pos


def main() -> int:
    if not os.path.isdir(IMAGES):
        print("run from the repo root", file=sys.stderr)
        return 1

    entries = read_sheets()
    groups = defaultdict(list)
    for e in entries:
        groups[group_of(e[0])].append(e)

    os.makedirs(OUT_DIR, exist_ok=True)
    sources = {}
    index = []
    for group in sorted(groups):
        frames = sorted(groups[group], key=lambda e: e[0])
        width, height, pos = pack_group(frames)
        sheet = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        rows = []
        for (name, src, sx, sy, w, h), (dx, dy) in zip(frames, pos):
            if src not in sources:
                sources[src] = Image.open(
                    os.path.join(IMAGES, src + ".png")).convert("RGBA")
            sheet.paste(sources[src].crop((sx, sy, sx + w, sy + h)), (dx, dy))
            rows.append((name, dx, dy, w, h))
        sheet.save(os.path.join(OUT_DIR, group + ".png"))
        index.append((group, width, height, sorted(rows)))

    lines = ['<?xml version="1.0" encoding="UTF-8"?>',
             "<!-- Generated by tools/sprite_repack.py - do not edit. -->",
             "<sprites>"]
    total = 0
    for group, width, height, rows in index:
        lines.append('\t<atlas file="%s.png" width="%d" height="%d">'
                     % (group, width, height))
        for name, x, y, w, h in rows:
            lines.append('\t\t<sprite name="%s" x="%d" y="%d" '
                         'width="%d" height="%d" />' % (name, x, y, w, h))
            total += 1
        lines.append("\t</atlas>")
    lines.append("</sprites>")
    with open(os.path.join(OUT_DIR, "index.xml"), "w",
              encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")

    print("wrote %d atlases, %d sprites to %s" % (len(index), total, OUT_DIR))
    return 0


if __name__ == "__main__":
    sys.exit(main())
