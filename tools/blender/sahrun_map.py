# Sahrun's map for the briefing table (docs/story/frames.md): a military
# topographic sheet of the 1980s, printed from assets/story/sahrun_map.json.
#
# Two images, both the whole sheet (its u, v 0..1 are the image's):
#   resources/3d/story/sahrun_print.png  the print -- paper, relief shading,
#       contours, sea, river, marsh, vegetation, roads, railway, the stages'
#       symbols, grid, frame, legend, names;
#   resources/3d/story/sahrun_marks.png  the team's red pencil over it, on
#       transparent -- the route, the stages ringed, the capital twice, the
#       landing crossed -- a layer of its own so that the game can draw it on.
#
# The relief, the sea and the land's tints are a raster (numpy); lines,
# symbols and lettering are meshes and text in a scene of their own,
# rendered from straight above by an orthographic camera over the raster.
#
# Run inside Blender, the briefing table's blend open
# (resources/3d/jackal_intro_01_3d.blend):
#
#     exec(open(r"<repo>/tools/blender/sahrun_map.py").read())
#     build()             # both images, then onto SF1P_Map in Intro_01_3D
#
# or headless:  blender -b resources/3d/jackal_intro_01_3d.blend
#                   --python tools/blender/sahrun_map.py -- --build
import bpy, bmesh, math, json, os, sys, random
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(bpy.data.filepath or "."), "..", ".."))
DATA = os.path.join(ROOT, "assets", "story", "sahrun_map.json")
OUT_DIR = os.path.join(ROOT, "resources", "3d", "story")
PRINT_PNG = os.path.join(OUT_DIR, "sahrun_print.png")
MARKS_PNG = os.path.join(OUT_DIR, "sahrun_marks.png")
FONT = os.path.join(os.environ.get("WINDIR", "C:/Windows"), "Fonts", "bahnschrift.ttf")
TITLE_FONT = os.path.join(ROOT, "assets", "fonts", "BlackOpsOne-Regular.ttf")

RES = (4800, 3200)          # the raster (relief, tints)
RENDER_RES = (6000, 4000)   # the print: the lines and lettering over the raster
RELIEF_RES = (1200, 800)    # the heights, smoothed up to RES
RELIEF_EXAGGERATION = 5.0   # the hill shading's slopes, steepened to read
SCENE = "SahrunPrint"
MM = 0.0018              # a symbol's millimetre: the sheet is a prop seen across a
                         # table, so its symbols and lettering are drawn 1.8 times up
REAL_MM = 0.001          # a true millimetre of paper: the scale bar

# The print's colours (sRGB 0..255). Red is the team's alone: nothing on the
# print is red, so that its pencil reads.
C = dict(
    paper=(238, 229, 206), land=(228, 208, 164), sea=(150, 194, 222), shore=(100, 154, 200),
    river=(40, 108, 188), veg=(170, 198, 130), marsh=(64, 116, 170), contour=(166, 116, 72),
    index=(128, 84, 50), shade=(118, 96, 80), stipple=(176, 146, 104),
    grid=(96, 98, 104), ink=(30, 30, 32), road=(220, 128, 60), built=(78, 76, 76),
    legend=(244, 238, 222), red=(196, 32, 28),
)


def _lin(rgb):
    return tuple((c / 255) / 12.92 if c / 255 <= 0.04045 else ((c / 255 + 0.055) / 1.055) ** 2.4 for c in rgb)


# ---------------------------------------------------------------------------
# The relief: heights in metres over the sheet, the raster under the lines.

def _polyline(pts, per=12):
    """Catmull-Rom through `pts` (lists of u, v)."""
    p = [Vector(pts[0])] + [Vector(q) for q in pts] + [Vector(pts[-1])]
    out = []
    for i in range(1, len(p) - 2):
        p0, p1, p2, p3 = p[i - 1], p[i], p[i + 1], p[i + 2]
        for k in range(per):
            t = k / per
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(p[-2])
    return out


def _dist(np, u, v, pts, aspect):
    """Distance from every (u, v) to the polyline `pts`, in u's units (v
    scaled by the sheet's aspect)."""
    d = np.full(u.shape, 9.0)
    for a, b in zip(pts, pts[1:]):
        ax, ay, bx, by = a.x, a.y * aspect, b.x, b.y * aspect
        dx, dy = bx - ax, by - ay
        L = dx * dx + dy * dy or 1e-12
        t = np.clip(((u - ax) * dx + (v * aspect - ay) * dy) / L, 0, 1)
        d = np.minimum(d, np.hypot(u - (ax + t * dx), v * aspect - (ay + t * dy)))
    return d


def _noise(np, u, v, seed, octaves=5, base=3.0):
    rng = np.random.default_rng(seed)
    n = np.zeros_like(u)
    for o in range(octaves):
        f = base * 2 ** o
        a, b, c = rng.uniform(0, 6.28, 3)
        n += np.sin(u * f + a + np.sin(v * f * 1.3 + b)) * np.cos(v * f + c) / 2 ** o
    return n


def _heights(np, D, u, v):
    asp = D["sheet"]["height_m"] / D["sheet"]["width_m"]
    n = _noise(np, u, v, 7)
    hl = D["highlands"]
    s = u * hl["axis"][0] + v * hl["axis"][1]
    t = np.clip((s - hl["from"]) / (hl["to"] - hl["from"]), 0, 1)
    h = 30 + 260 * np.clip(0.55 * u + 0.75 * v - 0.25, 0, None) + 40 * n
    n3 = _noise(np, u * 2.3, v * 2.3, 23, 5, 7.0)
    h += hl["height"] * t * t * (3 - 2 * t) * (0.75 + 0.3 * n + 0.25 * n3)
    for r in D["ridges"]:
        d = _dist(np, u, v, _polyline(r["points"], 10), asp)
        n2 = _noise(np, u * 3.1, v * 3.1, 17, 4, 6.0)
        h += r["height"] * (0.85 + 0.3 * n2) * np.exp(-(d / (0.024 + 0.008 * n + 0.004 * n2)) ** 2)
    b = D["basin"]
    db = np.hypot(u - b["at"][0], (v - b["at"][1]) * asp)
    h -= 0.6 * (h - 700) * np.clip(1 - db / b["radius"], 0, 1) ** 2 * (h > 700)
    dr = _dist(np, u, v, _polyline(D["river"]["points"], 10), asp)
    h -= 70 * np.exp(-(dr / 0.03) ** 2)
    return h, dr


def _upsample(np, a, shape):
    """Bilinear, `a` to `shape`."""
    h0, w0 = a.shape
    h1, w1 = shape
    y = np.linspace(0, h0 - 1, h1)
    x = np.linspace(0, w0 - 1, w1)
    y0 = np.floor(y).astype(int)
    x0 = np.floor(x).astype(int)
    y1 = np.minimum(y0 + 1, h0 - 1)
    x1 = np.minimum(x0 + 1, w0 - 1)
    fy = (y - y0)[:, None]
    fx = (x - x0)[None, :]
    return (a[y0][:, x0] * (1 - fx) * (1 - fy) + a[y0][:, x1] * fx * (1 - fy)
            + a[y1][:, x0] * (1 - fx) * fy + a[y1][:, x1] * fx * fy)


def _raster(D):
    """The print's raster: paper, land, relief, contours, sea, vegetation,
    marsh, stipple -- rows from the top, sRGB 0..1."""
    import numpy as np
    W, H = RES
    asp = D["sheet"]["height_m"] / D["sheet"]["width_m"]
    lu, lv = np.meshgrid(np.linspace(0, 1, RELIEF_RES[0]), np.linspace(1, 0, RELIEF_RES[1]))
    h_lo, dr_lo = _heights(np, D, lu, lv)
    coast = _polyline(D["coast"], 8)
    sea_d_lo = _dist(np, lu, lv, coast, asp)
    # Which side of the coast is the sea: left of it.
    cu = np.interp(lv[:, 0], [p.y for p in coast[::-1]], [p.x for p in coast[::-1]])
    sea_lo = lu < cu[:, None]
    f32 = np.float32
    h = _upsample(np, h_lo, (H, W)).astype(f32)
    dr = _upsample(np, dr_lo, (H, W)).astype(f32)
    sea_d = _upsample(np, sea_d_lo, (H, W)).astype(f32)
    sea = _upsample(np, sea_lo.astype(f32), (H, W)) > 0.5
    u, v = np.meshgrid(np.linspace(0, 1, W, dtype=f32), np.linspace(1, 0, H, dtype=f32))
    col = lambda k: np.array(C[k], float) / 255
    img = np.empty((H, W, 3), np.float32)
    img[:] = col("land")
    # Hill shading, light from the north-west, as the maps have it.
    gy, gx = np.gradient(h)
    px = D["sheet"]["width_m"] / W   # metres of paper a pixel; the ground's scale is 1:250 000
    k = RELIEF_EXAGGERATION / (px * 250000)
    nx, ny = -gx * k, gy * k
    shade = (nx * -0.6 + ny * 0.6 + 1.0) / np.sqrt(nx * nx + ny * ny + 1.0)
    shade = np.clip(shade, 0.0, 1.2)
    img *= (0.72 + 0.28 * shade)[..., None]
    img = img * 0.92 + col("shade") * 0.08 * (1 - np.clip(shade, 0, 1))[..., None]
    # Vegetation along the river, and the marsh's tint.
    n = _noise(np, u, v, 11, 4, 40.0)
    veg = np.clip((0.016 + 0.004 * n - dr) / 0.004, 0, 1) * 0.85
    img = img * (1 - veg[..., None]) + col("veg") * veg[..., None]
    m = D["marsh"]
    me = np.hypot((u - m["at"][0]) / m["radii"][0], (v - m["at"][1]) / m["radii"][1])
    marsh = (me < 1.0 + 0.06 * n)
    img = np.where(marsh[..., None], img * 0.7 + col("veg") * 0.3, img)
    # Desert stipple: a sparse grain of dots on the plain.
    rng = np.random.default_rng(5)
    grain = rng.random((H, W)) < 0.0035 * np.clip(1 - (h - 150) / 400, 0, 1)
    img = np.where((grain & ~sea & ~marsh)[..., None], col("stipple"), img)
    # Contours: every 50 m, every fifth heavier.
    g = np.hypot(gx, gy) + 1e-6
    for step, w, key in ((50.0, 0.9, "contour"), (250.0, 1.6, "index")):
        f = np.abs(h / step - np.round(h / step)) * step / g
        line = (f < w) & (h > 25) & ~sea
        img = np.where(line[..., None], img * 0.35 + col(key) * 0.65, img)
    # Marsh symbol: short blue dashes in rows.
    yy, xx = np.mgrid[0:H, 0:W]
    dash = (yy % 22 < 2) & ((xx + (yy // 22) * 9) % 26 < 12)
    img = np.where((marsh & dash)[..., None], col("marsh"), img)
    # The sea: its tint, lines along the shore.
    img = np.where(sea[..., None], col("sea"), img)
    sd_px = sea_d * W
    shore = sea & ((np.abs(sd_px - 10) < 1.2) | (np.abs(sd_px - 22) < 1.0) | (np.abs(sd_px - 38) < 0.9))
    img = np.where(shore[..., None], col("shore"), img)
    coastline = (sd_px < 2.2)
    img = np.where(coastline[..., None], col("ink") * 0.4 + col("shore") * 0.6, img)
    # The paper's margin outside the neatline.
    mu, mv = D["sheet"]["margin_u"], D["sheet"]["margin_v"]
    out = (u < mu) | (u > 1 - mu) | (v < mv) | (v > 1 - mv)
    img = np.where(out[..., None], col("paper"), img)
    return np.clip(img, 0, 1)


def _raster_image(D):
    import numpy as np
    img = _raster(D)
    H, W = img.shape[:2]
    rgba = np.concatenate([img[::-1], np.ones((H, W, 1))], axis=2).astype(np.float32)
    im = bpy.data.images.get("SahrunRaster") or bpy.data.images.new("SahrunRaster", W, H)
    if tuple(im.size) != (W, H):
        im.scale(W, H)
    im.colorspace_settings.name = "sRGB"
    im.pixels.foreach_set(rgba.ravel())
    return im


# ---------------------------------------------------------------------------
# The print's scene: flat shapes over the raster, seen from above.

class Print:
    def __init__(self, D):
        self.D = D
        self.W, self.H = D["sheet"]["width_m"], D["sheet"]["height_m"]
        sc = bpy.data.scenes.get(SCENE)
        if sc:
            for o in list(sc.objects):
                bpy.data.objects.remove(o, do_unlink=True)
        else:
            sc = bpy.data.scenes.new(SCENE)
        self.sc = sc
        self.c = sc.collection
        self.mats = {}
        self.font = bpy.data.fonts.load(FONT, check_existing=True)
        self.title_font = bpy.data.fonts.load(TITLE_FONT, check_existing=True)
        self.n = 0

    def P(self, uv, z=0.0):
        return Vector((uv[0] * self.W, uv[1] * self.H, z))

    def mat(self, key, alpha=1.0):
        name = "SahrunPrint_%s" % key
        m = self.mats.get(name) or bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        for x in list(nt.nodes):
            nt.nodes.remove(x)
        out = nt.nodes.new("ShaderNodeOutputMaterial")
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs["Color"].default_value = (*_lin(C[key]), 1)
        nt.links.new(em.outputs[0], out.inputs["Surface"])
        self.mats[name] = m
        return m

    def name(self, base):
        self.n += 1
        return "SP_%s_%d" % (base, self.n)

    def mesh(self, base, bm, key, z):
        me = bpy.data.meshes.new(base)
        bm.to_mesh(me)
        bm.free()
        me.materials.append(self.mat(key))
        o = bpy.data.objects.new(self.name(base), me)
        o.location.z = z
        self.c.objects.link(o)
        return o

    # Lines and shapes, in metres of paper (x, y).
    def strip(self, pts, width, key, z, base="Line", dash=None, closed=False):
        """A band `width` wide along `pts` (Vectors in metres); `dash` =
        (on, off) cuts it into dashes."""
        pts = [Vector((p.x, p.y)) for p in pts]
        if closed:
            pts = pts + [pts[0]]
        if dash:
            on, off = dash
            # Resample by arc length into dashes.
            runs, cur, acc, drawing = [], [pts[0]], 0.0, True
            for a, b in zip(pts, pts[1:]):
                seg = (b - a).length
                t = 0.0
                while seg - t > 1e-9:
                    left = (on if drawing else off) - acc
                    if seg - t >= left:
                        p = a + (b - a) * ((t + left) / seg)
                        if drawing:
                            cur.append(p)
                            runs.append(cur)
                        cur = [p]
                        t += left
                        acc = 0.0
                        drawing = not drawing
                    else:
                        if drawing:
                            cur.append(b)
                        acc += seg - t
                        t = seg
            if drawing and len(cur) > 1:
                runs.append(cur)
        else:
            runs = [pts]
        bm = bmesh.new()
        for run in runs:
            if len(run) < 2:
                continue
            left, right = [], []
            for i, p in enumerate(run):
                a = run[max(i - 1, 0)]
                b = run[min(i + 1, len(run) - 1)]
                d = (b - a)
                d = d.normalized() if d.length > 1e-12 else Vector((1, 0))
                nrm = Vector((-d.y, d.x)) * (width / 2)
                left.append(bm.verts.new((p.x + nrm.x, p.y + nrm.y, 0)))
                right.append(bm.verts.new((p.x - nrm.x, p.y - nrm.y, 0)))
            for i in range(len(run) - 1):
                bm.faces.new((left[i], right[i], right[i + 1], left[i + 1]))
        return self.mesh(base, bm, key, z)

    def poly(self, pts, key, z, base="Fill"):
        bm = bmesh.new()
        vs = [bm.verts.new((p.x, p.y, 0)) for p in pts]
        bm.faces.new(vs)
        return self.mesh(base, bm, key, z)

    def rect(self, at, w, h, key, z, angle=0.0, base="Rect"):
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        corners = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        return self.poly([Vector((at.x + x * ca - y * sa, at.y + x * sa + y * ca)) for x, y in corners], key, z, base)

    def frame(self, at, w, h, line, key, z, angle=0.0, dash=None, base="Frame"):
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        corners = [(-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)]
        pts = [Vector((at.x + x * ca - y * sa, at.y + x * sa + y * ca)) for x, y in corners]
        return self.strip(pts, line, key, z, base, dash=dash, closed=True)

    def ring(self, at, r, line, key, z, a0=0.0, a1=360.0, base="Ring", dash=None):
        n = max(int(abs(a1 - a0) / 6), 8)
        pts = [Vector((at.x + r * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
                       at.y + r * math.sin(math.radians(a0 + (a1 - a0) * i / n)))) for i in range(n + 1)]
        return self.strip(pts, line, key, z, base, dash=dash)

    def disc(self, at, r, key, z, base="Disc"):
        return self.poly([Vector((at.x + r * math.cos(2 * math.pi * i / 24), at.y + r * math.sin(2 * math.pi * i / 24)))
                          for i in range(24)], key, z, base)

    def text(self, body, at, size, key, z, align="CENTER", angle=0.0, italic=False, spacing=1.0, font=None,
             base="Text"):
        cu = bpy.data.curves.new(self.name(base), "FONT")
        cu.body = body
        cu.font = font or self.font
        cu.size = size
        cu.align_x, cu.align_y = align, "CENTER"
        cu.space_character = spacing
        cu.shear = 0.2 if italic else 0.0
        cu.materials.append(self.mat(key))
        o = bpy.data.objects.new(cu.name, cu)
        o.location = (at.x, at.y, z)
        o.rotation_euler.z = math.radians(angle)
        self.c.objects.link(o)
        return o


# ---------------------------------------------------------------------------
# Symbols, each drawn at `at` (metres), size in millimetres where it matters.

def sym_built(p, at, r, seed, z):
    rng = random.Random(seed)
    for _ in range(int(14 * (r / (12 * MM)) ** 2)):
        a, d = rng.uniform(0, 6.28), r * math.sqrt(rng.random())
        p.rect(at + Vector((d * math.cos(a), d * math.sin(a), 0)), rng.uniform(1.6, 3.2) * MM,
               rng.uniform(1.2, 2.4) * MM, "built", z, angle=rng.choice((0, 0, 90, 12)))


def sym_lz(p, at, z, s=1.0):
    r = 4.0 * MM * s
    tri = [at + Vector((r * math.cos(math.radians(90 + 120 * i)), r * math.sin(math.radians(90 + 120 * i)), 0))
           for i in range(3)]
    p.strip(tri, 0.6 * MM * s, "ink", z, "LZ", closed=True)


def sym_checkpoint(p, at, z, s=1.0, angle=0.0):
    p.rect(at, 3.2 * MM * s, 3.2 * MM * s, "ink", z, angle)
    ca, sa = math.cos(math.radians(angle + 90)), math.sin(math.radians(angle + 90))
    d = Vector((ca, sa, 0)) * 3.4 * MM * s
    p.strip([at - d, at + d], 0.7 * MM * s, "ink", z, "Barrier")


def sym_ruins(p, at, z, s=1.0):
    p.frame(at, 9 * MM * s, 7 * MM * s, 0.45 * MM * s, "ink", z, dash=(1.2 * MM * s, 0.9 * MM * s))
    for x, y in ((-2, -1), (1.5, 1.2), (1.8, -1.6)):
        p.rect(at + Vector((x * MM * s, y * MM * s, 0)), 1.4 * MM * s, 1.4 * MM * s, "ink", z, 20)


def sym_airfield(p, at, z, angle, s=1.0):
    p.rect(at, 22 * MM * s, 2.4 * MM * s, "ink", z, angle)
    p.rect(at + Vector((2 * MM * s, -1 * MM * s, 0)), 14 * MM * s, 1.8 * MM * s, "ink", z, angle + 70)
    p.ring(at, 12.5 * MM * s, 0.4 * MM * s, "ink", z, dash=(1.5 * MM * s, 1.2 * MM * s))


def sym_anchor(p, at, z, s=1.0):
    k = MM * s
    p.ring(at + Vector((0, 3.2 * k, 0)), 0.9 * k, 0.45 * k, "ink", z)
    p.strip([at + Vector((0, 2.3 * k, 0)), at + Vector((0, -2.8 * k, 0))], 0.6 * k, "ink", z, "Shank")
    p.strip([at + Vector((-1.6 * k, 1.4 * k, 0)), at + Vector((1.6 * k, 1.4 * k, 0))], 0.55 * k, "ink", z, "Stock")
    p.ring(at + Vector((0, -0.6 * k, 0)), 2.4 * k, 0.55 * k, "ink", z, 200, 340)


def sym_port(p, at, z, coast_dir=-1):
    for k, (dy, L) in enumerate(((-3.0, 8.0), (1.5, 11.0), (6.0, 7.0))):
        a = at + Vector((-1.0 * MM, dy * MM, 0))
        p.strip([a, a + Vector((coast_dir * L * MM, 0, 0))], 0.9 * MM, "ink", z, "Pier")


def sym_station(p, at, z, angle, s=1.0):
    p.rect(at, 5.5 * MM * s, 2.6 * MM * s, "ink", z, angle)


def sym_minefield(p, at, z, s=1.0, angle=35.0, legend=False):
    k = MM * s
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    w, h = (18 * k, 7 * k) if not legend else (10 * k, 5 * k)
    p.frame(at, w, h, 0.4 * k, "ink", z, angle, dash=(1.4 * k, 1.0 * k))
    n = 4 if not legend else 2
    for i in range(n):
        x = (-w / 2 + w * (i + 0.5) / n)
        c = at + Vector((x * ca, x * sa, 0))
        r = 1.5 * k
        tri = [c + Vector((r * math.cos(math.radians(90 + 120 * j)), r * math.sin(math.radians(90 + 120 * j)), 0))
               for j in range(3)]
        p.strip(tri, 0.4 * k, "ink", z, "Mine", closed=True)


def sym_armour(p, at, z, s=1.0):
    k = MM * s
    p.frame(at, 9 * k, 5.5 * k, 0.5 * k, "ink", z)
    pts = [at + Vector((3.0 * k * math.cos(2 * math.pi * i / 32), 1.6 * k * math.sin(2 * math.pi * i / 32), 0))
           for i in range(32)]
    p.strip(pts, 0.45 * k, "ink", z, "Track", closed=True)


def sym_hq(p, at, z, s=1.0):
    k = MM * s
    p.frame(at, 9 * k, 5.5 * k, 0.5 * k, "ink", z)
    p.strip([at + Vector((-4.5 * k, -2.75 * k, 0)), at + Vector((-4.5 * k, -10 * k, 0))], 0.55 * k, "ink", z, "Staff")
    p.text("HQ", at, 3.4 * k, "ink", z)


def sym_rail(p, pts, z, s=1.0):
    p.strip(pts, 0.8 * MM * s, "ink", z, "Rail")
    p.strip(pts, 2.6 * MM * s, "ink", z, "Sleepers", dash=(0.45 * MM * s, 3.2 * MM * s))


def sym_road(p, pts, z, s=1.0):
    p.strip(pts, 1.7 * MM * s, "ink", z, "RoadCase")
    p.strip(pts, 1.0 * MM * s, "road", z + 0.0002, "Road")


def sym_bridge(p, at, z, angle, s=1.0):
    k = MM * s
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    along, across = Vector((ca, sa, 0)), Vector((-sa, ca, 0))
    for side in (-1, 1):
        a = at + across * side * 1.6 * k
        p.strip([a - along * 2.6 * k - across * side * 0.8 * k, a - along * 2.0 * k,
                 a + along * 2.0 * k, a + along * 2.6 * k - across * side * 0.8 * k], 0.45 * k, "ink", z, "Bridge")


# ---------------------------------------------------------------------------

def _print_scene(D, raster):
    p = Print(D)
    W, H = p.W, p.H
    # The raster, under everything.
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    vs = [bm.verts.new(v) for v in ((0, 0, 0), (W, 0, 0), (W, H, 0), (0, H, 0))]
    f = bm.faces.new(vs)
    for lp, uv in zip(f.loops, ((0, 0), (1, 0), (1, 1), (0, 1))):
        lp[uvl].uv = uv
    m = bpy.data.materials.get("SahrunPrint_Raster") or bpy.data.materials.new("SahrunPrint_Raster")
    m.use_nodes = True
    nt = m.node_tree
    for x in list(nt.nodes):
        nt.nodes.remove(x)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    em = nt.nodes.new("ShaderNodeEmission")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image, tex.interpolation = raster, "Linear"
    nt.links.new(tex.outputs["Color"], em.inputs["Color"])
    nt.links.new(em.outputs[0], out.inputs["Surface"])
    me = bpy.data.meshes.new("SP_Raster")
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    o = bpy.data.objects.new("SP_Raster", me)
    p.c.objects.link(o)
    pr = p.c.objects
    mu, mv = D["sheet"]["margin_u"], D["sheet"]["margin_v"]
    Z = dict(grid=0.001, road=0.002, river=0.003, rail=0.004, sym=0.005, text=0.006, legend=0.007, ltext=0.008)
    # The grid: 10 columns A-K (no I), 7 rows, lettered in the margin.
    cols = "ABCDEFGHJK"
    for i in range(len(cols) + 1):
        uu = mu + (1 - 2 * mu) * i / len(cols)
        p.strip([p.P((uu, mv)), p.P((uu, 1 - mv))], 0.3 * MM, "grid", Z["grid"], "Grid")
    rows = 7
    for j in range(rows + 1):
        vv = mv + (1 - 2 * mv) * j / rows
        p.strip([p.P((mu, vv)), p.P((1 - mu, vv))], 0.3 * MM, "grid", Z["grid"], "Grid")
    for i, ch in enumerate(cols):
        uu = mu + (1 - 2 * mu) * (i + 0.5) / len(cols)
        for vv in (mv * 0.5, 1 - mv * 0.5):
            p.text(ch, p.P((uu, vv)), 6 * MM, "ink", Z["text"])
    for j in range(rows):
        vv = mv + (1 - 2 * mv) * (j + 0.5) / rows
        for uu in (mu * 0.5, 1 - mu * 0.5):
            p.text(str(j + 1), p.P((uu, vv)), 6 * MM, "ink", Z["text"])
    # The neatline: a heavy line round the map, a thin one outside it.
    p.frame(p.P((0.5, 0.5)), W * (1 - 2 * mu), H * (1 - 2 * mv), 1.2 * MM, "ink", Z["legend"])
    p.frame(p.P((0.5, 0.5)), W * (1 - 2 * mu) + 6 * MM, H * (1 - 2 * mv) + 6 * MM, 0.4 * MM, "ink", Z["legend"])
    # Roads, river, railway.
    for road in D["roads"]:
        sym_road(p, [p.P(q) for q in _polyline(road, 10)], Z["road"])
    river = [p.P(q) for q in _polyline(D["river"]["points"], 16)]
    n = len(river)
    for i in range(n - 1):
        w = (0.7 + 1.9 * i / n) * MM
        p.strip(river[i:i + 2], w, "river", Z["river"], "River")
    sym_rail(p, [p.P(q) for q in _polyline(D["rail"], 12)], Z["rail"])
    for b in D["bridges"]:
        sym_bridge(p, p.P(b[:2]), Z["sym"], b[2] if len(b) > 2 else 0)
    # The stages' places.
    for s in D["stages"]:
        at = p.P(s["at"])
        kind = s["symbol"]
        if kind == "lz":
            sym_lz(p, at, Z["sym"])
        elif kind == "checkpoint":
            sym_checkpoint(p, at + Vector((0.0, 3.5 * MM, 0)), Z["sym"], angle=-20)
        elif kind == "ruins":
            sym_ruins(p, at, Z["sym"])
            af = s["airfield"]
            sym_airfield(p, p.P(af["at"]), Z["sym"], af["angle"])
            p.text(af["label"], p.P(af["label_at"]), 5.5 * MM, "ink", Z["text"], align="LEFT", spacing=1.1)
        elif kind == "port":
            sym_built(p, at + Vector((5 * MM, 0, 0)), 9 * MM, 3, Z["sym"])
            sym_port(p, at + Vector((-3 * MM, 0, 0)), Z["sym"])
            sym_anchor(p, at + Vector((-15 * MM, -12 * MM, 0)), Z["sym"], 1.2)
        elif kind == "station":
            sym_station(p, at, Z["sym"], 38)
        elif kind == "minefield":
            sym_minefield(p, at, Z["sym"])
            dp = s["depot"]
            sym_armour(p, p.P(dp["at"]), Z["sym"])
            p.text(dp["label"], p.P(dp["label_at"]), 5 * MM, "ink", Z["text"], spacing=1.1)
        elif kind == "hq":
            sym_built(p, at + Vector((-3 * MM, -2 * MM, 0)), 13 * MM, 6, Z["sym"])
            sym_hq(p, at + Vector((14 * MM, 6 * MM, 0)), Z["sym"])
        big = kind in ("port", "hq")
        p.text(s["label"], p.P(s["label_at"]), (8.5 if big else 5.5) * MM, "ink", Z["text"],
               align="LEFT" if kind in ("lz", "checkpoint", "station") else "CENTER", spacing=1.15)
    # Water and land names, spot heights.
    r = D["river"]
    pts = _polyline(r["points"], 16)
    la = Vector(r["label_at"])
    best = min(range(len(pts) - 1), key=lambda i: (pts[i] - la).length)
    d = pts[best + 1] - pts[best]
    ang = math.degrees(math.atan2(d.y * H, d.x * W))
    if ang > 90 or ang < -90:
        ang += 180
    p.text(r["name"], p.P(r["label_at"]) + Vector((-6 * MM, 6 * MM, 0)), 8 * MM, "river", Z["text"], angle=ang,
           italic=True, spacing=1.6)
    m = D["marsh"]
    p.text("MARSH", p.P(m["label_at"]), 5.5 * MM, "marsh", Z["text"], italic=True, spacing=1.3)
    for su, sv, hgt in D["spot_heights"]:
        at = p.P((su, sv))
        p.disc(at, 0.8 * MM, "index", Z["sym"])
        p.text(str(hgt), at + Vector((1.5 * MM, -0.2 * MM, 0)), 4.5 * MM, "index", Z["text"], align="LEFT")
    _legend(p, Z)
    return p


def _legend(p, Z):
    """The margin's information, in a panel on the map's empty south-east:
    the sheet's name, its imprint, the scale, the north, the legend."""
    D = p.D
    u0, v0, u1, v1 = D["legend"]["box"]
    a, b = p.P((u0, v0)), p.P((u1, v1))
    mid = (a + b) / 2
    w, h = b.x - a.x, b.y - a.y
    p.rect(mid, w, h, "legend", Z["legend"] - 0.0005)
    p.frame(mid, w, h, 0.7 * MM, "ink", Z["legend"])
    y = b.y - 10 * MM
    p.text(D["title"], Vector((mid.x, y, 0)), 13 * MM, "ink", Z["ltext"], spacing=1.4, font=p.title_font)
    y -= 9 * MM
    p.text("   ".join(D["imprint"]), Vector((mid.x, y, 0)), 3.6 * MM, "ink", Z["ltext"], spacing=1.1)
    # A scale bar of 0..20 km at 1:250 000 (80 true millimetres), the north.
    y -= 8 * MM
    x0 = Vector((mid.x - 40 * REAL_MM - 8 * MM, y, 0))
    for k in range(4):
        c = x0 + Vector((k * 20 * REAL_MM + 10 * REAL_MM, 0, 0))
        if k % 2 == 0:
            p.rect(c, 20 * REAL_MM, 1.4 * MM, "ink", Z["ltext"])
        else:
            p.frame(c, 20 * REAL_MM, 1.4 * MM, 0.25 * MM, "ink", Z["ltext"])
    for k, lab in enumerate(("0", "5", "10", "15", "20 KM")):
        p.text(lab, x0 + Vector((k * 20 * REAL_MM, 3 * MM, 0)), 2.8 * MM, "ink", Z["ltext"])
    na = Vector((mid.x + 40 * REAL_MM + 4 * MM, y + 1 * MM, 0))
    p.poly([na + Vector((0, 5 * MM, 0)), na + Vector((-2 * MM, -4 * MM, 0)), na + Vector((0, -2 * MM, 0))], "ink",
           Z["ltext"])
    p.strip([na + Vector((0, 5 * MM, 0)), na + Vector((2 * MM, -4 * MM, 0)), na + Vector((0, -2 * MM, 0))],
            0.3 * MM, "ink", Z["ltext"], "North")
    p.text("N", na + Vector((4 * MM, 3 * MM, 0)), 4 * MM, "ink", Z["ltext"])
    y -= 6 * MM
    p.text("CONTOUR INTERVAL 50 METRES", Vector((mid.x, y, 0)), 3.2 * MM, "ink", Z["ltext"], spacing=1.1)
    y -= 4 * MM
    p.strip([Vector((a.x + 4 * MM, y, 0)), Vector((b.x - 4 * MM, y, 0))], 0.4 * MM, "ink", Z["ltext"], "Rule")
    y -= 7 * MM
    p.text("LEGEND", Vector((mid.x, y, 0)), 5 * MM, "ink", Z["ltext"], spacing=1.5)
    top = y - 9 * MM
    rows = [
        ("Main road", lambda at: sym_road(p, [at - Vector((7 * MM, 0, 0)), at + Vector((7 * MM, 0, 0))], Z["ltext"])),
        ("Railway", lambda at: sym_rail(p, [at - Vector((7 * MM, 0, 0)), at + Vector((7 * MM, 0, 0))], Z["ltext"])),
        ("River", lambda at: p.strip([at - Vector((7 * MM, 0, 0)), at + Vector((7 * MM, 0, 0))], 1.6 * MM, "river",
                                     Z["ltext"], "River")),
        ("Bridge", lambda at: sym_bridge(p, at, Z["ltext"], 0)),
        ("Contour, 50 m", lambda at: p.strip([at - Vector((7 * MM, 0, 0)), at + Vector((7 * MM, 0, 0))], 0.5 * MM,
                                             "contour", Z["ltext"])),
        ("Spot height", lambda at: (p.disc(at, 0.8 * MM, "index", Z["ltext"]),
                                    p.text("547", at + Vector((1.5 * MM, 0, 0)), 4 * MM, "index", Z["ltext"],
                                           align="LEFT"))),
        ("Marsh", lambda at: [p.strip([at + Vector((-6 * MM + x * MM, y * MM, 0)), at + Vector((-3 * MM + x * MM, y * MM, 0))],
                                      0.5 * MM, "marsh", Z["ltext"]) for x, y in ((0, 1.5), (5, 1.5), (2.5, -1.5), (7.5, -1.5))]),
        ("Built-up area", lambda at: sym_built(p, at, 5 * MM, 9, Z["ltext"])),
        ("Port", lambda at: sym_anchor(p, at, Z["ltext"])),
        ("Airfield", lambda at: sym_airfield(p, at, Z["ltext"], 30, 0.45)),
        ("Ruins", lambda at: sym_ruins(p, at, Z["ltext"], 0.9)),
        ("Checkpoint", lambda at: sym_checkpoint(p, at, Z["ltext"])),
        ("Station", lambda at: sym_station(p, at, Z["ltext"], 0)),
        ("Minefield", lambda at: sym_minefield(p, at, Z["ltext"], legend=True, angle=0)),
        ("Armour depot", lambda at: sym_armour(p, at, Z["ltext"], 0.9)),
        ("Headquarters", lambda at: sym_hq(p, at + Vector((0, 2 * MM, 0)), Z["ltext"], 0.7)),
        ("Landing zone", lambda at: sym_lz(p, at, Z["ltext"])),
    ]
    half = (len(rows) + 1) // 2
    step = (top - a.y - 5 * MM) / max(half - 1, 1)
    for i, (label, draw) in enumerate(rows):
        col, row = divmod(i, half)
        x = a.x + 11 * MM + col * w / 2
        y = top - row * step
        draw(Vector((x, y, 0)))
        p.text(label, Vector((x + 10 * MM, y, 0)), 3.4 * MM, "ink", Z["ltext"], align="LEFT")


def _marks_scene(D):
    """The team's red pencil: a hand's dashes from the landing through the
    stages, a ring on each, the capital twice, the landing crossed."""
    p = Print(D)
    rng = random.Random(41)
    stages = [s["at"] for s in D["stages"]]
    route = _polyline(stages, 18)
    route = [p.P(q) + Vector((rng.uniform(-0.4, 0.4) * MM, rng.uniform(-0.4, 0.4) * MM, 0)) for q in route]
    p.strip(route, 1.3 * MM, "red", 0.001, "Route", dash=(7 * MM, 4.5 * MM))
    for s in D["stages"][1:6]:
        at = p.P(s["at"])
        p.ring(at, 6.5 * MM, 1.1 * MM, "red", 0.002, -40, 330)
    cap = p.P(D["stages"][6]["at"])
    p.ring(cap, 12 * MM, 1.4 * MM, "red", 0.002, -30, 340)
    p.ring(cap + Vector((1.2 * MM, -0.6 * MM, 0)), 15.5 * MM, 1.0 * MM, "red", 0.002, 20, 375)
    land = p.P(D["stages"][0]["at"])
    for sgn in (-1, 1):
        d = Vector((math.cos(math.radians(45 * sgn)), math.sin(math.radians(45 * sgn)), 0)) * 6 * MM
        p.strip([land - d, land + d], 1.2 * MM, "red", 0.002, "LandingX")
    return p


def _render(sc, path, transparent):
    W, H = RENDER_RES
    cam = bpy.data.objects.get("SP_Camera")
    if cam is None:
        cam = bpy.data.objects.new("SP_Camera", bpy.data.cameras.new("SP_Camera"))
    if cam.name not in sc.collection.objects:
        sc.collection.objects.link(cam)
    D = json.load(open(DATA, encoding="utf-8"))
    w, h = D["sheet"]["width_m"], D["sheet"]["height_m"]
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = w
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.clip_start, cam.data.clip_end = 0.01, 10
    cam.location = (w / 2, h / 2, 1)
    cam.rotation_euler = (0, 0, 0)
    sc.camera = cam
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = W, H
    sc.render.resolution_percentage = 100
    sc.render.film_transparent = transparent
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA" if transparent else "RGB"
    sc.render.use_compositing = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.eevee.taa_render_samples = 16
    if sc.world is None:
        sc.world = bpy.data.worlds.new("SahrunPrint_World")
    sc.world.use_nodes = True
    bg = next(n for n in sc.world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (*_lin(C["paper"]), 1)
    sc.render.filepath = path
    bpy.ops.render.render(scene=sc.name, write_still=True)


def build_print():
    D = json.load(open(DATA, encoding="utf-8"))
    os.makedirs(OUT_DIR, exist_ok=True)
    raster = _raster_image(D)
    p = _print_scene(D, raster)
    _render(p.sc, PRINT_PNG, False)
    p = _marks_scene(D)
    _render(p.sc, MARKS_PNG, True)
    return PRINT_PNG, MARKS_PNG


def apply_to_sheet(obj="SF1P_Map"):
    """The briefing table's sheet: UVs over the whole sheet (centred on its
    origin), the print with the pencil over it."""
    o = bpy.data.objects[obj]
    me = o.data
    # The sheet's own size (the print is laid out at the data's 1.2 x 0.8
    # m and scaled onto whatever sheet the table has).
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    w, h = max(xs) - min(xs), max(ys) - min(ys)
    uv = me.uv_layers.active or me.uv_layers.new(name="UVMap")
    for lp in me.loops:
        co = me.vertices[lp.vertex_index].co
        uv.data[lp.index].uv = (co.x / w + 0.5, co.y / h + 0.5)
    m = o.material_slots[0].material
    nt = m.node_tree
    tex = nt.nodes["SF_Tex"]
    tex.image = bpy.data.images.load(PRINT_PNG, check_existing=True)
    tex.image.reload()
    tex.interpolation = "Cubic"
    marks = nt.nodes.get("SF_Marks") or nt.nodes.new("ShaderNodeTexImage")
    marks.name = "SF_Marks"
    marks.image = bpy.data.images.load(MARKS_PNG, check_existing=True)
    marks.image.reload()
    marks.interpolation = "Cubic"
    mix = nt.nodes.get("SF_MarksMix") or nt.nodes.new("ShaderNodeMix")
    mix.name, mix.data_type = "SF_MarksMix", "RGBA"
    rgba = lambda socks, name: next(s for s in socks if s.name == name and s.type == "RGBA")
    nt.links.new(marks.outputs["Alpha"], mix.inputs[0])
    nt.links.new(tex.outputs["Color"], rgba(mix.inputs, "A"))
    nt.links.new(marks.outputs["Color"], rgba(mix.inputs, "B"))
    targets = [s for n in nt.nodes if n != mix for s in n.inputs
               if s.is_linked and s.links[0].from_node == tex and s.links[0].from_socket.name == "Color"]
    for s in targets:
        nt.links.new(rgba(mix.outputs, "Result"), s)
    return o


def build():
    build_print()
    apply_to_sheet()


if "--build" in sys.argv:
    build()
    bpy.ops.wm.save_mainfile()
