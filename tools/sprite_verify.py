#!/usr/bin/env python3
"""Check the repacked atlases against the original sprites-N sheets.

Compares every sprite region pixel for pixel, and checks that the name set is
exactly the same on both sides -- a silently dropped or duplicated frame is the
failure mode that would otherwise only show up as a wrong sprite in game.

Needs the pre-migration sheets, which the repack replaced; restore them first:

    git checkout <ref-before-migration> -- assets/images/sprites-[0-9]*

Run from the repo root:  python tools/sprite_verify.py
"""
import os
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sprite_repack import IMAGES, OUT_DIR, read_sheets  # noqa: E402

ATLAS = re.compile(r'<atlas file="([^"]+)"')
SPRITE = re.compile(r'<sprite name="([^"]+)" x="(\d+)" y="(\d+)" '
                    r'width="(\d+)" height="(\d+)"')


def read_index():
    out = {}
    current = None
    path = os.path.join(OUT_DIR, "index.xml")
    with open(path, encoding="utf-8") as f:
        for line in f:
            m = ATLAS.search(line)
            if m:
                current = m.group(1)
                continue
            m = SPRITE.search(line)
            if m:
                out[m.group(1)] = (current, int(m.group(2)), int(m.group(3)),
                                   int(m.group(4)), int(m.group(5)))
    return out


def main() -> int:
    old = {name: (sheet, x, y, w, h)
           for name, sheet, x, y, w, h in read_sheets()}
    new = read_index()

    missing = sorted(set(old) - set(new))
    extra = sorted(set(new) - set(old))
    if missing or extra:
        for n in missing:
            print("MISSING in repack: %s" % n)
        for n in extra:
            print("EXTRA in repack:   %s" % n)
        return 1

    cache = {}

    def img(path):
        if path not in cache:
            cache[path] = Image.open(path).convert("RGBA")
        return cache[path]

    bad = 0
    for name in sorted(old):
        osheet, ox, oy, ow, oh = old[name]
        nfile, nx, ny, nw, nh = new[name]
        if (ow, oh) != (nw, nh):
            print("SIZE  %s: %dx%d -> %dx%d" % (name, ow, oh, nw, nh))
            bad += 1
            continue
        a = img(os.path.join(IMAGES, osheet + ".png")).crop(
            (ox, oy, ox + ow, oy + oh))
        b = img(os.path.join(OUT_DIR, nfile)).crop((nx, ny, nx + nw, ny + nh))
        if a.tobytes() != b.tobytes():
            print("PIXELS %s (%s -> %s)" % (name, osheet, nfile))
            bad += 1

    # A frame overlapping its neighbour would sample the wrong art when the
    # engine rotates it, so check the packing itself too.
    per_atlas = {}
    for name, (f, x, y, w, h) in new.items():
        per_atlas.setdefault(f, []).append((name, x, y, w, h))
    for f, rects in per_atlas.items():
        for i in range(len(rects)):
            for j in range(i + 1, len(rects)):
                an, ax, ay, aw, ah = rects[i]
                bn, bx, by, bw, bh = rects[j]
                if ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah:
                    print("OVERLAP %s: %s / %s" % (f, an, bn))
                    bad += 1

    print("checked %d sprites in %d atlases: %s"
          % (len(old), len(per_atlas), "FAIL" if bad else "OK"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
