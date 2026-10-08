# The painted frame 1 (docs/story/paint/intro_01.webp: GPT image's paint
# over the Intro_01 blockout of resources/3d/jackal_story_frames.blend)
# taken back onto the map sheet, for the frame's 3D scene (Intro_01_3D):
# every texel of the sheet is projected through the blockout's camera and
# the painting sampled there. The painting kept the blockout's layout to a
# pixel or two inside the map, so no fitting is needed; its sheet is a
# little larger at the edges (SHEET). What stands on the map in the
# painting -- the cup, the loupe, the pencil, the pickup, the six flags --
# is painted out by copying paper from beside it, and the stage rings the
# flags' poles cut are drawn closed again. Writes the sheet's texture and
# the junta's flag cut out of the painting.
#
#     py tools/story_paint_map.py
#
# CAM, LOOK, LENS, MAP_W, MAP_H and curl() are the blockout's (build_intro_01
# and _map_sheet in the blend's script) and must stay so. Takes ~2 minutes.
import sys
import numpy as np
from PIL import Image

SRC = "docs/story/paint/intro_01.webp"
OUT = "docs/story/paint/intro_01_map.jpg"
OUT_FLAG = "docs/story/paint/intro_01_junta_flag.png"

MAP_W, MAP_H = 1.2, 0.8
CAM, LOOK, LENS = (0.0, -1.18, 0.78), (0.0, -0.02, 0.0), 40.0
SHEET = (-0.004, 1.0, 0.008, 1.017)      # the painted sheet's u0 u1 v0 v1, in the map's uv
TEX = (3072, 2048)
PAINT_W = 1672           # the painting's width, which the pixel positions below are in


def curl(u, v):
    """The sheet's height: the top right corner curling up, the bottom right a touch."""
    return 0.002 + 0.045 * np.clip((u + v - 1.72) / 0.28, 0, None) ** 2 \
        + 0.015 * np.clip((u - 0.88) / 0.12, 0, None) ** 2 * np.clip((0.2 - v) / 0.2, 0, None)


def cam_basis():
    c, l = np.array(CAM), np.array(LOOK)
    f = l - c
    f /= np.linalg.norm(f)
    r = np.cross(f, [0, 0, 1.0])
    r /= np.linalg.norm(r)
    return c, f, r, np.cross(r, f)


def project(u, v, z, W, H):
    """The map's uv (and height) -> a pixel (x right, y down) of a WxH frame."""
    c, f, r, up = cam_basis()
    k = LENS / 36.0 * W
    p = np.stack([(u - 0.5) * MAP_W - c[0], (v - 0.5) * MAP_H - c[1], z - c[2]], -1)
    d = p @ f
    return W / 2 + k * (p @ r) / d, H / 2 - k * (p @ up) / d


def sample(img, x, y):
    """Bilinear, the frame mirrored at its edges."""
    H, W = img.shape[:2]
    x = np.abs(x)
    x = np.where(x > W - 1, 2 * (W - 1) - x, x)
    y = np.abs(y)
    y = np.where(y > H - 1, 2 * (H - 1) - y, y)
    x0 = np.clip(np.floor(x).astype(int), 0, W - 2)
    y0 = np.clip(np.floor(y).astype(int), 0, H - 2)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    a = img[y0, x0] * (1 - fx) + img[y0, x0 + 1] * fx
    b = img[y0 + 1, x0] * (1 - fx) + img[y0 + 1, x0 + 1] * fx
    return a * (1 - fy) + b * fy


def poly_mask(W, H, pts):
    yy, xx = np.mgrid[0:H, 0:W] + 0.5
    inside = np.zeros((H, W), bool)
    for i in range(len(pts)):
        (x1, y1), (x2, y2) = pts[i], pts[(i + 1) % len(pts)]
        cond = (y1 > yy) != (y2 > yy)
        inside ^= cond & (xx < x1 + (yy - y1) * (x2 - x1) / ((y2 - y1) or 1e-9))
    return inside


def thick_line(a, b, w):
    a, b = np.array(a, float), np.array(b, float)
    d = b - a
    n = np.array([-d[1], d[0]]) / np.linalg.norm(d) * w / 2
    return [tuple(a + n), tuple(b + n), tuple(b - n), tuple(a - n)]


# The painting's props, in its pixels. Each flag: its pole's foot and top,
# its cloth's box; copied over by the paper nearby that best continues the
# paper round it (best_shift). The rest: a polygon, whether to match the
# patch's lighting to its surroundings, and steps of (where, shift in uv)
# applied in turn, so a later step may copy what an earlier one filled --
# the cup's foot along the left margin (the top margin along the top), the
# pencil from the desert to its left, the loupe from below in three bands
# (the fold across the map kept out of the copy); the pickup, like a flag,
# from wherever the paper best continues round it.
FLAGS = [((406, 681), (398, 606), (395, 605, 445, 641)),
         ((515, 542), (508, 471), (504, 470, 553, 504)),
         ((353, 438), (343, 372), (339, 371, 387, 403)),
         ((645, 369), (640, 303), (636, 302, 681, 333)),
         ((919, 308), (917, 242), (913, 241, 958, 272)),
         ((1238, 270), (1243, 176), (1239, 175, 1295, 217))]
POLE_W = 14
STAGE_UV = [(0.27, 0.17), (0.31, 0.36), (0.19, 0.53), (0.37, 0.66), (0.56, 0.79), (0.80, 0.88)]
PATCHES = [
    ([(0, 180), (250, 180), (250, 300), (260, 406), (0, 406)], False,
     [(lambda u, v: (u >= 0.033) & (v >= 0.966), (0.25, 0.0)),
      (lambda u, v: (u < 0.033) | (v < 0.966), (0.0, -0.45))]),
    ([(1262, 730), (1536, 614), (1584, 626), (1574, 676), (1306, 802), (1264, 792)], True,
     [(None, (-0.20, 0.0))]),
    ([(1288, 412), (1472, 412), (1486, 456), (1618, 466), (1672, 480), (1672, 568), (1276, 568)], True,
     [(lambda u, v: v < 0.40, (0.0, -0.26)), (lambda u, v: (v >= 0.40) & (v < 0.48), (0.0, -0.27)),
      (lambda u, v: v >= 0.48, (0.0, -0.31))]),
    ([(424, 702), (466, 688), (504, 688), (542, 700), (546, 816), (418, 816)], False, None),
]
BOTTOM_MARGIN = 0.056    # the bottom margin with its rule
JUNTA_FLAG = (1246, 183, 1287, 213)


def painted_map(img):
    """img: HxWx3 float, rows from the top. The sheet's texture, TEX[0] x
    TEX[1], rows from the bottom (v up)."""
    H, W = img.shape[:2]
    sc = W / PAINT_W
    tw, th = TEX
    u0, u1, v0, v1 = SHEET
    du1, dv1 = (u1 - u0) / (tw - 1), (v1 - v0) / (th - 1)
    u, v = np.meshgrid(np.linspace(u0, u1, tw), np.linspace(v0, v1, th))
    # The painted sheet's right edge leans (u 0.994 at v 0.42, 1.011 at
    # 0.76): our last tenth is stretched onto it, so no desk shows.
    edge = np.clip(0.991 + 0.05 * (v - 0.42), 0.97, 1.012)
    x, y = project(np.where(u > 0.9, 0.9 + (u - 0.9) * (edge - 0.9) / (u1 - 0.9), u), v, curl(u, v), W, H)
    tex = sample(img, x, y)
    outside = (x < 0) | (x > W - 1) | (y > H - 1)
    px = lambda du, dv: (int(round(du / du1)), int(round(dv / dv1)))
    shifted = lambda a, du, dv: np.roll(np.roll(a, -px(du, dv)[1], 0), -px(du, dv)[0], 1)
    # Off the frame (the bottom corners): the bottom margin copied along it
    # from the middle, the rest down from above (the sea and the margins run
    # up the sheet).
    off = outside.copy()
    for _ in range(6):
        along = off & (v < BOTTOM_MARGIN)
        for m, du, dv in ((along & (u < 0.5), 0.15, 0.0), (along & (u >= 0.5), -0.15, 0.0), (off & ~along, 0.0, 0.15)):
            tex[m] = shifted(tex, du, dv)[m]
            off[m] = shifted(off, du, dv)[m]

    def at(pts):
        """A polygon of the painting, as texels."""
        m = poly_mask(W, H, [(a * sc, b * sc) for a, b in pts])
        return m[np.clip(y.astype(int), 0, H - 1), np.clip(x.astype(int), 0, W - 1)] & ~outside

    def patch(m, steps, lp):
        """`m` painted out by `steps`, its lighting matched to round it if
        `lp`, each step's seam smudged at once (a later step may copy it)."""
        nonlocal tex
        if lp:
            lp_t = blur(smudge(tex, dilate(m, 4), grain=False), 24)
        for where, (du, dv) in steps:
            mm = m if where is None else m & where(u, v)
            src = shifted(tex, du, dv)
            if lp:
                src = np.clip(src * lp_t / np.maximum(blur(src, 24), 1e-3), 0, 1)
            tex[mm] = src[mm]
            tex = smudge(tex, dilate(mm, 3) & ~erode(mm, 3))

    flags = [at(thick_line(base, top, POLE_W)) | at([(x0 - 4, y0 - 6), (x1 + 6, y0 - 6), (x1 + 6, y1 + 5), (x0 - 4, y1 + 5)])
             for base, top, (x0, y0, x1, y1) in FLAGS]
    # The stage rings, read off before anything is copied over them (each
    # flag's pole cuts its ring), drawn on again at the end.
    cu = lambda uv: ((uv[0] - u0) / du1, (uv[1] - v0) / dv1)
    rings = [find_rings(tex, dilate(m, 2), *cu(st), [(44, 70), (60, 96)] if st == STAGE_UV[-1] else [(20, 44)])
             for m, st in zip(flags, STAGE_UV)]
    taken = np.zeros((th, tw), bool)
    for m in flags:
        taken |= dilate(m, 4)
    for poly, lp, steps in PATCHES:
        m = at(poly)
        patch(m, steps or [(None, best_shift(tex, m, taken | dilate(m, 4), du1, dv1, 0.16))], lp)
    for m in flags:
        patch(m, [(None, best_shift(tex, m, taken, du1, dv1))], False)
    for m, found in zip(flags, rings):
        draw_rings(tex, dilate(m, 3), found)
    return tex


def best_shift(tex, m, taken, du1, dv1, reach=0.1, step=0.004):
    """The shift (in uv) of the paper that, laid over `m`, best continues
    the paper round it, its source clear of everything `taken`."""
    th, tw = m.shape
    ry, rx = np.nonzero(dilate(m, 8) & ~dilate(m, 2))
    my, mx = np.nonzero(m)
    best, arg = None, (reach, 0.0)
    n = int(reach / step)
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            sx, sy = int(round(i * step / du1)), int(round(j * step / dv1))
            if abs(sx) < 40 and abs(sy) < 40:
                continue
            ys, xs = my + sy, mx + sx
            if ys.min() < 0 or ys.max() >= th or xs.min() < 0 or xs.max() >= tw or taken[ys, xs].any():
                continue
            ry2, rx2 = ry + sy, rx + sx
            if ry2.min() < 0 or ry2.max() >= th or rx2.min() < 0 or rx2.max() >= tw:
                continue
            d = ((tex[ry2, rx2] - tex[ry, rx]) ** 2).mean()
            if best is None or d < best:
                best, arg = d, (i * step, j * step)
    return arg


def find_rings(tex, hole, cx, cy, radii):
    """The red rings about (cx, cy) (texels), `hole` aside -- painted as
    ellipses, taller up the map than across: for each range of radii, the
    band (centre, stretch, inner and outer radius across, colour) that best
    overlaps the red left near the stage."""
    R = 140
    y0, x0 = int(cy) - R, int(cx) - R
    sub = tex[y0:y0 + 2 * R, x0:x0 + 2 * R]
    keep = ~hole[y0:y0 + 2 * R, x0:x0 + 2 * R]
    yy, xx = np.mgrid[0:2 * R, 0:2 * R]
    red = (sub[..., 0] - sub[..., 1] > 0.35) & (sub[..., 1] < 0.3) & keep
    found = []
    for rmin, rmax in radii:
        near = red & (np.hypot(xx - R, yy - R) < rmax * 1.7 + 10)
        tot = near.sum()
        best = None
        for s in (1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6):
            for oy in range(-30, 31, 3):
                for ox in range(-24, 25, 3):
                    d = np.hypot(xx - (R + ox), (yy - (R + oy)) / s).astype(int)
                    hit = np.concatenate([[0], np.cumsum(np.bincount(d[near].ravel(), minlength=4 * R))])
                    area = np.concatenate([[0], np.cumsum(np.bincount(d[keep].ravel(), minlength=4 * R))])
                    for h in (3, 4, 5, 6, 7):
                        lo = np.arange(rmin - h, rmax - h)
                        hi = lo + 2 * h + 1
                        hits = hit[hi] - hit[lo]
                        iou = hits / (area[hi] - area[lo] + tot - hits + 1e-9)
                        i = int(np.argmax(iou))
                        if best is None or iou[i] > best[0]:
                            best = (iou[i], ox, oy, s, lo[i], hi[i] - 1)
        f, ox, oy, s, lo, hi = best
        if f < 0.2:
            continue
        d = np.hypot(xx - (R + ox), (yy - (R + oy)) / s)
        band = (d >= lo) & (d <= hi + 1)
        found.append((x0 + R + ox, y0 + R + oy, s, lo, hi, np.median(sub[band & near], axis=0)))
        red &= ~band
    return found


def draw_rings(tex, where, found):
    """`found` rings drawn over `where`: their red, a dark pencil edge."""
    for cx, cy, s, lo, hi, col in found:
        R = int((hi + 4) * s)
        ys, xs = slice(int(cy) - R, int(cy) + R + 1), slice(int(cx) - R, int(cx) + R + 1)
        yy, xx = np.mgrid[ys, xs]
        d = np.hypot(xx - cx, (yy - cy) / s)
        band = (d >= lo - 0.5) & (d <= hi + 0.5) & where[ys, xs]
        edge = band & ((d < lo + 1.0) | (d > hi - 1.0))
        sub = tex[ys, xs]
        sub[band] = col
        sub[edge] = col * 0.45


def dilate(m, r):
    out = m.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= np.roll(np.roll(m, dy, 0), dx, 1)
    return out


def erode(m, r):
    return ~dilate(~m, r)


def blur(a, r):
    """Box blur of radius r along both axes."""
    for ax in (0, 1):
        c = np.cumsum(np.pad(a, [(r + 1, r) if i == ax else (0, 0) for i in range(a.ndim)], mode="edge"), axis=ax)
        n = a.shape[ax]
        a = (np.take(c, range(2 * r + 1, 2 * r + 1 + n), axis=ax) - np.take(c, range(0, n), axis=ax)) / (2 * r + 1)
    return a


def smudge(tex, hole, grain=True):
    """`hole` filled from its edge inwards by normalised blurs of what is
    known, finest first; the paper's grain put back as noise."""
    out = tex.copy()
    filled = ~hole
    for r in (2, 4, 8, 16, 32, 64, 128, 256):
        num = blur(out * filled[..., None], r)
        den = blur(filled.astype(float), r)[..., None]
        ok = (den[..., 0] > 0.05) & ~filled
        out[ok] = (num / np.maximum(den, 1e-6))[ok]
        filled |= ok
    if grain:
        g = blur(np.random.default_rng(1).normal(0, 1, tex.shape[:2]), 1)[..., None] * 0.06
        out[hole] = np.clip(out[hole] * (1 + g[hole]), 0, 1)
    return out


if __name__ == "__main__":
    src = sys.argv[1] if len(sys.argv) > 1 else SRC
    im = Image.open(src).convert("RGB")
    sc = im.width / PAINT_W
    tex = painted_map(np.asarray(im, float) / 255)
    Image.fromarray((np.clip(tex[::-1], 0, 1) * 255).astype(np.uint8)).save(OUT, quality=92)
    flag = im.crop(tuple(int(round(a * sc)) for a in JUNTA_FLAG))
    flag.resize((flag.width * 6, flag.height * 6), Image.LANCZOS).save(OUT_FLAG)
    print("wrote", OUT, OUT_FLAG)
