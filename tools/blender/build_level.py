# Builds a 3D level in Blender out of its level file, assets/level3d/stage-N.json:
# docs/level-editor-plan.md, stage 5.
#
#     blender -b resources/3d/jackal_stage1_lowpoly.blend --python tools/blender/build_level.py -- \
#         assets/level3d/stage-0.json --out build/level3d/jackal_stage1_gen.blend \
#         [--glb build/level3d/jackal_stage1_gen.glb] [--report build/level3d/report.txt]
#
# On this machine Blender is the Store build, and is run through
# %LOCALAPPDATA%\Microsoft\WindowsApps\blender-launcher.exe with the same
# arguments; its output is not seen, which is why everything goes to --report.
#
# The .blend it opens is the base: what the file does not describe yet -- the
# walls, the bridge, the gate, the buildings that are blown up, the palette,
# the sun and the cameras -- comes from there. Everything the file does
# describe is taken out of it and built again, into Gen_* collections:
#
#   Gen_Terrain     the ground: a constrained Delaunay triangulation of the
#                   level's bounds with every brow and waterline as an edge,
#                   the slope between them faceted in columns of points down
#                   it as jackal_cliffs.py did, heights off the file's profile
#                   (Level3DTerrain in the Godot tree says what it means). The
#                   sand is an object of its own, flat, as the preview wants
#                   it (_flat_ground_casts_nothing); the slopes and the bed
#                   another. Shore_Lines runs along every brow.
#   Gen_Vegetation  the forest floors and their trees, by the file's rule and
#                   the same hash as Level3DTerrain.tree_positions, and the
#                   palms the file places.
#   Gen_Props       the rest of the file's objects, as library meshes or
#                   collection instances of jackal_assets.blend.
#
# The ocean stays -- its Ocean modifier and J_WaterUnify are the base's -- but
# J_Shoreline, which the water's colour and foam are measured from, is traced
# again along the file's waterline.
#
# Nothing is written over the base: the result is saved --out, and exported
# --glb through the base's own jackal_export_glb.py.
import bpy, bmesh, json, math, os, sys, time
from mathutils import Vector, kdtree
from mathutils.geometry import delaunay_2d_cdt

T0 = time.time()
REPORT = []


def say(line):
    REPORT.append("%6.1fs  %s" % (time.time() - T0, line))


# --- Arguments --------------------------------------------------------------------

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def arg(name, default=None):
    return ARGV[ARGV.index(name) + 1] if name in ARGV else default


LEVEL = ARGV[0]
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, arg("--out", "build/level3d/level_gen.blend"))
GLB = arg("--glb")
REPORT_PATH = os.path.join(ROOT, arg("--report", "build/level3d/report.txt"))

# --- What the build does, and the numbers it does it with -------------------------

# jackal_cliffs.py's: a column of points down the face every so far along the
# brow, at DOWN of the way, knocked off the straight line by up to JITTER.
COLUMN = (0.24, 0.48)
DOWN = (0.22, 0.48, 0.74)
JITTER = (0.12, 0.07, 0.08)         # along, out, down; metres
DARK = 0.4                          # the share of slope facets turned furthest from the sun
NEIGHBOURS = 24                     # ... among the facets nearest each
MIN_GAP = 0.10                      # between the slope's column points
EDGE_GAP = 0.05                     # from a column point to the brow or the waterline
SPECK_AREA = 0.002                  # a facet this small (m2) ...
SPECK_TURN = 40.0                   # ... turned this far from its neighbours is a speck
SPECKS_ALLOWED = 14                 # as many as the hand-built stage's slopes have
BED_STEP = 0.75                     # the river bed's points
BED_FADE = 3.0                      # over which it falls away from an edge that is no shore
BED_DEEP = -2.4                     # to where the water shows nothing (Land_Base_North's depth)
UNSEEN = -2.0                       # below this the water shows no edge of the ground
SUN = Vector((0.4265, -0.5212, -0.7392))
SEARCH = 3.0                        # Level3DTerrain.SEARCH
BUCKET = 1.0
# jackal_cel.py's line along the brow: BROW wide, LIFT over the ground.
BROW = 0.028
LIFT = 0.003
FLOOR_LIFT = 0.015                  # the forest floor over the sand
# The trees: the library's broad-leaved and pine meshes, and how they were
# sized and leant on stage 1 (jackal_level_edges.py): smaller towards the edge.
BROAD = ["ForestTree_%d" % k for k in range(8)]
PINES = ["ForestPine_%d" % k for k in range(2)]
TREE_SCALE = (0.57, 1.12)
TREE_TALL = (1.0, 1.2)
TREE_LEAN = 0.05                    # radians either way
EDGE = 1.5                          # metres over which the trees shrink to the edge
EDGE_SCALE = 0.75

# Named so the preview knows them (level3d_preview.gd, _kind_of): "Terrain" and
# "Beach" are ground, "Forest_Floor" the forest, "Palm" a trunk.
SAND_OBJECT = "Terrain_Land"
SLOPE_OBJECT = "Beach_Slope"
# What the file describes, taken out of the base before it is built again: the
# base's collections of ground and vegetation whole, and any object whose name
# is an id of the file's (the glb's names are Blender's with "." as "_").
REPLACED_COLLECTIONS = ("J_Terrain", "J_Vegetation")
KEPT_WATER = ("Ocean",)

MASK = 0xFFFFFFFF


def hash01(a, b, seed, salt):
    """Level3DTerrain.hash01, to the bit."""
    h = (a * 374761393 + b * 668265263 + seed * 1442695041 + salt * 3266489917) & MASK
    h = ((h ^ (h >> 15)) * 1540483477) & MASK
    h = ((h ^ (h >> 13)) * 668265261) & MASK
    h = h ^ (h >> 16)
    return h / 4294967296.0


# --- Plan geometry ------------------------------------------------------------------
#
# The file is in Godot's axes, x east and z south; Blender's y is north. Plan
# points here are Blender's (x, y) = (x, -z).


def plan(p):
    return Vector((float(p[0]), -float(p[1])))


def rings_of(polygon):
    return [[plan(p) for p in polygon["outer"]]] + [[plan(p) for p in h] for h in polygon.get("holes", [])]


def profile_at(table, t):
    if t <= table[0][0]:
        return table[0][1]
    for k in range(1, len(table)):
        if t <= table[k][0]:
            t0, h0 = table[k - 1]
            t1, h1 = table[k]
            return h0 + (h1 - h0) * (t - t0) / max(t1 - t0, 1e-9)
    return table[-1][1]


class Segments:
    """Segments bucketed on a BUCKET grid: nearest distance and point."""

    def __init__(self):
        self.a, self.b, self.buckets = [], [], {}

    def add(self, p, q):
        i = len(self.a)
        self.a.append(p)
        self.b.append(q)
        for y in range(math.floor(min(p.y, q.y) / BUCKET), math.floor(max(p.y, q.y) / BUCKET) + 1):
            for x in range(math.floor(min(p.x, q.x) / BUCKET), math.floor(max(p.x, q.x) / BUCKET) + 1):
                self.buckets.setdefault((x, y), []).append(i)

    def nearest(self, p, cap):
        best, at = cap, None
        reach = math.ceil(cap / BUCKET)
        hx, hy = math.floor(p.x / BUCKET), math.floor(p.y / BUCKET)
        for y in range(hy - reach, hy + reach + 1):
            for x in range(hx - reach, hx + reach + 1):
                for i in self.buckets.get((x, y), ()):
                    a, b = self.a[i], self.b[i]
                    ab = b - a
                    t = 0.0 if ab.length_squared == 0 else max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
                    c = a + ab * t
                    d = (p - c).length
                    if d < best:
                        best, at = d, c
        return best, at


class Inside:
    """Even-odd point in a set of rings, the rings' edges bucketed by row."""

    def __init__(self, rings):
        self.rows = {}
        for ring in rings:
            n = len(ring)
            for k in range(n):
                p, q = ring[k], ring[(k + 1) % n]
                if p.y == q.y:
                    continue
                for y in range(math.floor(min(p.y, q.y)), math.floor(max(p.y, q.y)) + 1):
                    self.rows.setdefault(y, []).append((p, q))

    def __call__(self, v):
        inside = False
        for p, q in self.rows.get(math.floor(v.y), ()):
            if (p.y > v.y) != (q.y > v.y):
                x = p.x + (q.x - p.x) * (v.y - p.y) / (q.y - p.y)
                if x > v.x:
                    inside = not inside
        return inside


def inside_any(tests, v):
    return any(t(v) for t in tests)


# --- The ground ---------------------------------------------------------------------


def real_edges(rings, bounds, inside):
    """The edges of rings that are a real edge of what `inside` tests: in on
    one side and out on the other, both sides within the level's bounds. The
    stretch of a ring along the bounds, and the cut two water bodies share,
    are not a shore (Level3DTerrain.edges, the same rule)."""
    x0, y0, x1, y1 = bounds
    out = []
    for ring in rings:
        n = len(ring)
        for k in range(n):
            p, q = ring[k], ring[(k + 1) % n]
            along = q - p
            if along.length < 1e-9:
                continue
            normal = Vector((-along.y, along.x)).normalized() * 0.05
            middle = (p + q) * 0.5
            a, b = middle + normal, middle - normal
            if not all(x0 <= c.x <= x1 and y0 <= c.y <= y1 for c in (a, b)):
                continue
            if inside(a) != inside(b):
                out.append((p, q))
    return out


def build_ground(doc, materials):
    terrain = doc["terrain"]
    profile = terrain["profiles"][terrain["profile"]]
    slope, foot = profile["slope"], profile["foot"]
    bed = foot[-1][1]
    foot_reach = foot[-1][0]
    b = terrain["bounds"]
    # Blender's bounds: y is -z, so the file's z range flips.
    bounds = (b[0], -b[3], b[2], -b[1])

    land_rings, water_rings = [], []
    land_faces, water_faces = [], []
    for polygon in terrain["land"]:
        land_rings.extend(rings_of(polygon))
    water_by_body = [rings_of(polygon) for polygon in doc.get("water", [])]
    for rings in water_by_body:
        water_rings.extend(rings)
    in_land = Inside(land_rings)
    in_water = Inside(water_rings)

    brows = Segments()
    brow_edges = real_edges(land_rings, bounds, in_land)
    for p, q in brow_edges:
        brows.add(p, q)
    shores = Segments()
    shore_edges = real_edges(water_rings, bounds, in_water)
    for p, q in shore_edges:
        shores.add(p, q)

    coords, heights, edges, faces = [], [], [], []

    def vertex(p, h):
        coords.append(p)
        heights.append(h)
        return len(coords) - 1

    x0, y0, x1, y1 = bounds
    corners = [vertex(Vector(c), None) for c in ((x0, y0), (x1, y0), (x1, y1), (x0, y1))]
    for k in range(4):
        edges.append((corners[k], corners[(k + 1) % 4]))
    # A brow vertex the simplification left a hair over the waterline (the
    # spit's nose, where the slope is a few centimetres across) is at the
    # water's level, or every triangle from it out to the bed slopes up to it.
    for ring in land_rings:
        ids = [vertex(p, -1.0 if in_water(p) else 0.0) for p in ring]
        edges.extend((ids[k], ids[(k + 1) % len(ids)]) for k in range(len(ids)))
        land_faces.append(len(faces))
        faces.append(ids)
    for ring in water_rings:
        # Every waterline vertex is at the water's level: only the slope, above
        # the water, is kept of the triangulation, and where a ring runs along
        # the bounds or the cut between bodies it touches nothing else.
        ids = [vertex(p, -1.0) for p in ring]
        edges.extend((ids[k], ids[(k + 1) % len(ids)]) for k in range(len(ids)))
        water_faces.append(len(faces))
        faces.append(ids)

    # The face: a column of points down it every COLUMN along each brow. No
    # two of them nearer than MIN_GAP, and none nearer the brow or the
    # waterline than EDGE_GAP: two points a few centimetres apart at heights
    # the jitter set apart make a facet standing on its edge, a speck of the
    # wrong tone in the rock (_specks).
    columns = 0
    placed = {}

    def crowded(c):
        cx, cy = math.floor(c.x / MIN_GAP), math.floor(c.y / MIN_GAP)
        for y in range(cy - 1, cy + 2):
            for x in range(cx - 1, cx + 2):
                for other in placed.get((x, y), ()):
                    if (other - c).length < MIN_GAP:
                        return True
        return False
    for n, (p, q) in enumerate(brow_edges):
        along = q - p
        length = along.length
        if length < 1e-6:
            continue
        tangent = along / length
        s = 0.0
        step = 0
        while s < length:
            at = p + tangent * s
            d, w = shores.nearest(at, SEARCH)
            if w is not None and d > 0.05:
                out = (w - at) / d
                for k, share in enumerate(DOWN):
                    j = [hash01(n, step, k, salt) * 2.0 - 1.0 for salt in (10, 11, 12)]
                    c = at + (w - at) * share + tangent * (j[0] * JITTER[0]) + out * (j[1] * JITTER[1])
                    if in_land(c) or in_water(c) or crowded(c):
                        continue
                    db, _ = brows.nearest(c, SEARCH)
                    dw, _ = shores.nearest(c, SEARCH)
                    if db < EDGE_GAP or dw < EDGE_GAP:
                        continue
                    t = db / max(db + dw, 1e-6)
                    vertex(c, profile_at(slope, t) + j[2] * JITTER[2] * min(t, 1.0 - t) * 2.0)
                    placed.setdefault((math.floor(c.x / MIN_GAP), math.floor(c.y / MIN_GAP)), []).append(c)
                    columns += 1
            step += 1
            s += COLUMN[0] + (COLUMN[1] - COLUMN[0]) * hash01(n, step, 0, 13)
    say("ground: %d brow and %d shore edges, %d column points"
        % (len(brow_edges), len(shore_edges), columns))

    out_coords, _, out_faces, orig_verts, _, orig_faces = delaunay_2d_cdt(
        coords, edges, faces, 0, 1e-5, True)
    say("ground: triangulated, %d vertices, %d faces" % (len(out_coords), len(out_faces)))

    # What each triangle is, by its middle: delaunay_2d_cdt's orig_faces want
    # the input faces wound counter-clockwise, and the file's rings, turned
    # into Blender's axes, are not all of them that way round.
    face_kind = []
    for face in out_faces:
        middle = sum((Vector(out_coords[v]) for v in face), Vector((0, 0))) / len(face)
        face_kind.append("land" if in_land(middle) else "water" if in_water(middle) else "slope")

    # Heights: an input vertex's own, and for one the triangulation made (where
    # constraints cross) the heights its faces imply.
    z = [None] * len(out_coords)
    for k, origins in enumerate(orig_verts):
        for i in origins:
            if heights[i] is not None:
                z[k] = heights[i]
                break
    touching = [set() for _ in out_coords]
    for k, face in enumerate(out_faces):
        for v in face:
            touching[v].add(face_kind[k])
    for k in range(len(z)):
        if z[k] is not None:
            continue
        kinds = touching[k]
        if "land" in kinds:
            z[k] = 0.0
        elif "water" in kinds:
            z[k] = bed  # a corner of the bounds, or a sliver along them
        else:
            p = Vector(out_coords[k])
            db, _ = brows.nearest(p, SEARCH)
            dw, _ = shores.nearest(p, SEARCH)
            z[k] = profile_at(slope, db / max(db + dw, 1e-6)) if db < SEARCH or dw < SEARCH else 0.0

    # The triangulation is the ground above the water only: the sand one
    # object, flat, the slopes another. What it made inside the water goes.
    # Under the water nothing is triangulated -- the wall and the bed are built
    # (_underwater) -- because the water's shader shows the ground through the
    # shallows (level3d_ocean.gdshader, clarity), and whatever the
    # triangulation fanned out there, from a waterline vertex to the bed or
    # across a river's mouth to the cut, showed through as dark rays and pale
    # wedges.
    parts = {"land": [], "rest": []}
    dropped = 0
    flat_sand = 0
    for k, face in enumerate(out_faces):
        if face_kind[k] == "water":
            dropped += 1
        elif face_kind[k] == "land":
            parts["land"].append(k)
        elif all(abs(z[v]) < 1e-6 for v in face):
            # A triangle of brow vertices only, filling a bend of the brow
            # outside the land: it is at the sand's height, and is sand. Painted
            # as rock it was a brown speck on the brow.
            parts["land"].append(k)
            flat_sand += 1
        else:
            parts["rest"].append(k)
    say("ground: %d faces inside the water left out, %d flat at the brow made sand" % (dropped, flat_sand))
    objects = {}
    for part, name in (("land", SAND_OBJECT), ("rest", SLOPE_OBJECT)):
        bm = bmesh.new()
        index = {}
        for k in parts[part]:
            vs = []
            for v in out_faces[k]:
                if v not in index:
                    c = out_coords[v]
                    index[v] = bm.verts.new((c[0], c[1], 0.0 if part == "land" else z[v]))
                vs.append(index[v])
            try:
                f = bm.faces.new(vs)
            except ValueError:
                continue
            f.smooth = False
            f.material_index = 0
        bm.normal_update()
        for f in bm.faces:
            if f.normal.z < 0:
                f.normal_flip()
        if part == "rest":
            bm.normal_update()
            before = len(_specks(bm))
            after = _relax_specks(bm)
            say("ground: %d specks on the slope, %d after relaxing them (the hand-built "
                "stage has %d; want no more)" % (before, after, SPECKS_ALLOWED))
            for f in _specks(bm)[:10]:
                c = f.calc_center_median()
                say("  speck at (%.2f, %.2f), corners at %s, %.1f cm2"
                    % (c.x, -c.y, sorted(round(v.co.z, 2) for v in f.verts), f.calc_area() * 1e4))
            if after > SPECKS_ALLOWED:
                raise RuntimeError("%d specks on the slope" % after)
            low = sum(1 for f in bm.faces if min(v.co.z for v in f.verts) < -1.0 - 1e-4)
            say("ground: %d faces of the slope reach under the water (want 0)" % low)
            if low:
                # Under the water is the wall's and the bed's only; a slope face
                # there is the kind of thing the water shows as a streak.
                raise RuntimeError("%d slope faces under the water" % low)
            walls, beds = _underwater(bm, doc, water_rings, bounds, in_water, foot, bed)
            say("ground: under the water, %d faces of wall and %d of river bed" % (walls, beds))
            bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
            _check_underwater_edges(bm, shores, foot_reach)
        mesh = bpy.data.meshes.new(name)
        bm.to_mesh(mesh)
        bm.free()
        objects[name] = mesh
    _paint_ground(objects[SAND_OBJECT], objects[SLOPE_OBJECT], bed, materials)
    return objects, brow_edges, shore_edges


def _specks(bm):
    """Facets of the slope small enough to be a pixel or two from above and
    turned more than SPECK_TURN from the facets round them: what reads as a
    dead pixel in the rock."""
    out = []
    limit = math.cos(math.radians(SPECK_TURN))
    for f in bm.faces:
        if f.calc_area() >= SPECK_AREA:
            continue
        heights = [v.co.z for v in f.verts]
        if max(heights) - min(heights) < 0.01:
            continue  # flat: a bend of the waterline filled at the water's level
        around = Vector((0, 0, 0))
        for e in f.edges:
            for g in e.link_faces:
                if g is not f:
                    around += g.normal * g.calc_area()
        if around.length > 1e-12 and f.normal.dot(around.normalized()) < limit:
            out.append(f)
    return out


def _relax_specks(bm, passes=3):
    """Each speck's free corners -- the column points; the brow at 0 and the
    waterline at -1 stay where they are -- brought to the mean height of the
    vertices round them, until no speck is left or the passes are spent.
    Returns how many are left."""
    for _ in range(passes):
        specks = _specks(bm)
        if not specks:
            return 0
        for f in specks:
            for v in f.verts:
                if abs(v.co.z) < 1e-6 or abs(v.co.z + 1.0) < 1e-6:
                    continue
                near = [e.other_vert(v).co.z for e in v.link_edges]
                v.co.z = sum(near) / len(near)
        bm.normal_update()
    return len(_specks(bm))


def _check_underwater_edges(bm, shores, foot_reach):
    """The second thing the water must not show: an open edge of the ground
    under it. The shallows show the ground down to about the bed, so an edge
    there is a line in the water -- unless it is the wall's own foot, along the
    shore where the old cliff's foot was. Anything else means a hole or an
    edge where there should be neither, and the build stops."""
    bad = []
    for e in bm.edges:
        if not e.is_boundary:
            continue
        a, b = e.verts[0].co, e.verts[1].co
        if max(a.z, b.z) >= -1.0 - 1e-3 or min(a.z, b.z) <= UNSEEN:
            continue
        middle = Vector(((a.x + b.x) * 0.5, (a.y + b.y) * 0.5))
        d, _ = shores.nearest(middle, foot_reach * 3.0)
        if d >= foot_reach * 3.0:
            bad.append(middle)
    say("ground: %d open edges under the water away from a shore (want 0)" % len(bad))
    if bad:
        for m in bad[:10]:
            say("  at (%.2f, %.2f)" % (m.x, -m.y))
        raise RuntimeError("%d open edges under the water" % len(bad))


def shore_chains(rings, bounds, inside):
    """The runs of consecutive shore edges round each ring (real_edges' rule),
    each a list of points and whether it closes on itself."""
    x0, y0, x1, y1 = bounds
    chains = []
    for ring in rings:
        n = len(ring)
        real = []
        for k in range(n):
            p, q = ring[k], ring[(k + 1) % n]
            along = q - p
            if along.length < 1e-9:
                real.append(False)
                continue
            normal = Vector((-along.y, along.x)).normalized() * 0.05
            middle = (p + q) * 0.5
            a, b = middle + normal, middle - normal
            real.append(all(x0 <= c.x <= x1 and y0 <= c.y <= y1 for c in (a, b))
                        and inside(a) != inside(b))
        if all(real):
            chains.append((list(ring), True))
            continue
        if not any(real):
            continue
        start = next(k for k in range(n) if real[k] and not real[k - 1])
        run = None
        for m in range(n):
            k = (start + m) % n
            if real[k]:
                if run is None:
                    run = [ring[k]]
                run.append(ring[(k + 1) % n])
            elif run is not None:
                chains.append((run, False))
                run = None
        if run is not None:
            chains.append((run, False))
    return chains


def _underwater(bm, doc, water_rings, bounds, in_water, foot, bed):
    """What lies under the water, built rather than triangulated: along every
    run of shore a wall, a row of vertices for each row of the profile's foot
    table, out from the waterline into the water, down to the bed; and under
    the river its bed, flat. The sea has no bed, as it had none on the
    hand-built stage. The wall's top row is the waterline's own vertices,
    which the slope ends on, and is welded to it."""
    walls = 0
    for points, closed in shore_chains(water_rings, bounds, in_water):
        n = len(points)
        m = n if closed else n - 1
        normals = []
        for k in range(m):
            p, q = points[k], points[(k + 1) % n]
            along = (q - p).normalized()
            normal = Vector((-along.y, along.x))
            if not in_water((p + q) * 0.5 + normal * 0.02):
                normal = -normal
            normals.append(normal)
        rows = []
        for d, h in foot:
            row = []
            for k in range(n):
                if closed:
                    around = [normals[(k - 1) % m], normals[k % m]]
                else:
                    around = [normals[i] for i in (k - 1, k) if 0 <= i < m]
                direction = sum(around, Vector((0, 0)))
                direction = direction.normalized() if direction.length > 1e-9 else around[0]
                # Mitred, so the wall keeps its reach round a bend; held where
                # the bend is sharp.
                reach = d / max(min(direction.dot(a) for a in around), 0.35)
                c = points[k] + direction * reach
                row.append(bm.verts.new((c.x, c.y, h)))
            rows.append(row)
        for r in range(len(rows) - 1):
            for k in range(m):
                quad = (rows[r][k], rows[r][(k + 1) % n], rows[r + 1][(k + 1) % n], rows[r + 1][k])
                try:
                    f = bm.faces.new(quad)
                    f.smooth = False
                    walls += 1
                except ValueError:
                    pass
    # The river's bed ends at a shore only. Where its polygon ends otherwise
    # -- the cut to the sea at its mouth, the level's bounds -- the bed goes
    # down over BED_FADE to BED_DEEP, where the water shows nothing, rather
    # than stopping in a straight edge the shallows would show: the sea beside
    # it has no bed at all. A point every BED_STEP inside keeps the fall
    # smooth and its triangles small.
    beds = 0
    for polygon in doc.get("water", []):
        if polygon.get("kind") != "river":
            continue
        rings = rings_of(polygon)
        inside = Inside(rings)
        shore = {(round(p.x, 4), round(p.y, 4), round(q.x, 4), round(q.y, 4))
                 for p, q in real_edges(rings, bounds, in_water)}
        open_edges = Segments()
        for ring in rings:
            for k in range(len(ring)):
                p, q = ring[k], ring[(k + 1) % len(ring)]
                if (round(p.x, 4), round(p.y, 4), round(q.x, 4), round(q.y, 4)) not in shore:
                    open_edges.add(p, q)
        coords, edges, faces = [], [], []
        for ring in rings:
            base = len(coords)
            coords.extend(ring)
            edges.extend((base + k, base + (k + 1) % len(ring)) for k in range(len(ring)))
            faces.append(list(range(base, base + len(ring))))
        lo = Vector((min(c.x for c in coords), min(c.y for c in coords)))
        hi = Vector((max(c.x for c in coords), max(c.y for c in coords)))
        edge_index = Segments()
        for ring in rings:
            for k in range(len(ring)):
                edge_index.add(ring[k], ring[(k + 1) % len(ring)])
        for gy in range(math.ceil(lo.y / BED_STEP), math.floor(hi.y / BED_STEP) + 1):
            for gx in range(math.ceil(lo.x / BED_STEP), math.floor(hi.x / BED_STEP) + 1):
                c = Vector((gx * BED_STEP, gy * BED_STEP))
                if inside(c) and edge_index.nearest(c, BED_STEP * 0.3)[0] >= BED_STEP * 0.3:
                    coords.append(c)
        out, _, out_faces, _, _, _ = delaunay_2d_cdt(coords, edges, faces, 0, 1e-5, True)

        def depth(c):
            d, _ = open_edges.nearest(Vector(c), BED_FADE)
            t = 1.0 - min(d / BED_FADE, 1.0)
            return bed + (BED_DEEP - bed) * t * t * (3.0 - 2.0 * t)

        verts = [bm.verts.new((c[0], c[1], depth(c))) for c in out]
        for face in out_faces:
            middle = sum((Vector(out[v]) for v in face), Vector((0, 0))) / len(face)
            if inside(middle):
                try:
                    f = bm.faces.new([verts[v] for v in face])
                    f.smooth = False
                    beds += 1
                except ValueError:
                    pass
        bmesh.ops.delete(bm, geom=[v for v in verts if not v.link_faces], context="VERTS")
    bm.normal_update()
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    return walls, beds


def _paint_ground(sand, rest, bed, materials):
    sand.materials.append(materials["J_Sand"])
    for name in ("J_BeachBrown", "J_RockDark", "J_RiverBed"):
        rest.materials.append(materials[name])
    # Slope facets: the DARK share turned furthest from the sun dark; the
    # river's bed its own colour.
    # The foot, the wall from the waterline down, is rock as the face is:
    # jackal_rock_face.py painted the old cliff so.
    slope_faces = []
    for p in rest.polygons:
        highest = max(rest.vertices[v].co.z for v in p.vertices)
        if highest <= bed + 1e-4:  # the river's bed, and where it falls away
            p.material_index = 2
        else:
            slope_faces.append(p)
    # Dark by its neighbours, as jackal_rock_face.py did: a facet is dark when
    # it is turned further from the sun than DARK of the NEIGHBOURS nearest
    # it. A share over the whole level darkened every bank facing away from
    # the sun and none facing it.
    if slope_faces:
        tree = kdtree.KDTree(len(slope_faces))
        for k, p in enumerate(slope_faces):
            tree.insert(p.center, k)
        tree.balance()
        lit = [p.normal.dot(-SUN) for p in slope_faces]
        for k, p in enumerate(slope_faces):
            near = sorted(lit[i] for _, i, _ in tree.find_n(p.center, NEIGHBOURS))
            p.material_index = 1 if lit[k] < near[int(len(near) * DARK)] else 0


def build_shore_lines(brow_edges, material):
    """jackal_cel.py's shore_lines: a black ribbon BROW wide, LIFT over the
    sand, along every brow edge, its ends run on half its width so the joins
    at the bends do not tear."""
    bm = bmesh.new()
    for p, q in brow_edges:
        along = q - p
        if along.length < 1e-6:
            continue
        t = along.normalized()
        n = Vector((-t.y, t.x)) * (BROW * 0.5)
        a, b = p - t * (BROW * 0.5), q + t * (BROW * 0.5)
        vs = [bm.verts.new((c.x, c.y, LIFT)) for c in (a - n, b - n, b + n, a + n)]
        bm.faces.new(vs)
    mesh = bpy.data.meshes.new("Shore_Lines")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    return mesh


def trace_shoreline(shore_edges):
    """J_Shoreline: the waterline as loose edges, which J_WaterUnify measures
    shore_dist from."""
    bm = bmesh.new()
    index = {}

    def v(p):
        key = (round(p.x, 4), round(p.y, 4))
        if key not in index:
            index[key] = bm.verts.new((p.x, p.y, -1.0))
        return index[key]

    for p, q in shore_edges:
        a, b = v(p), v(q)
        if a != b:
            try:
                bm.edges.new((a, b))
            except ValueError:
                pass
    mesh = bpy.data.meshes.new("J_Shoreline")
    bm.to_mesh(mesh)
    bm.free()
    return mesh


# --- The forest ---------------------------------------------------------------------


def floor_mesh(polygon, material, name):
    rings = rings_of(polygon)
    coords, edges, faces = [], [], []
    for ring in rings:
        base = len(coords)
        coords.extend(ring)
        edges.extend((base + k, base + (k + 1) % len(ring)) for k in range(len(ring)))
        faces.append(list(range(base, base + len(ring))))
    out, _, out_faces, _, _, _ = delaunay_2d_cdt(coords, edges, faces, 0, 1e-5, True)
    inside = Inside(rings)
    bm = bmesh.new()
    verts = [bm.verts.new((c[0], c[1], FLOOR_LIFT)) for c in out]
    for k, face in enumerate(out_faces):
        middle = sum((Vector(out[v]) for v in face), Vector((0, 0))) / len(face)
        if inside(middle):
            try:
                f = bm.faces.new([verts[v] for v in face])
                f.smooth = False
            except ValueError:
                pass
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for f in bm.faces:
        if f.normal.z < 0:
            f.normal_flip()
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(material)
    return mesh


def tree_positions(polygon):
    """Level3DTerrain.tree_positions, but kept by the polygon itself rather
    than by a raster of it: same squares, same hash, same choices."""
    spacing, jitter = float(polygon["spacing"]), float(polygon["jitter"])
    pines, seed = float(polygon["pines"]), int(polygon["seed"])
    rings = [[Vector((float(p[0]), float(p[1]))) for p in polygon["outer"]]] \
        + [[Vector((float(p[0]), float(p[1]))) for p in h] for h in polygon.get("holes", [])]
    inside = Inside(rings)
    edge = Segments()
    for ring in rings:
        for k in range(len(ring)):
            edge.add(ring[k], ring[(k + 1) % len(ring)])
    xs = [p.x for p in rings[0]]
    zs = [p.y for p in rings[0]]
    out = []
    for b in range(math.floor(min(zs) / spacing), math.ceil(max(zs) / spacing) + 1):
        for a in range(math.floor(min(xs) / spacing), math.ceil(max(xs) / spacing) + 1):
            at = Vector(((a + 0.5) * spacing + (hash01(a, b, seed, 0) * 2.0 - 1.0) * jitter,
                         (b + 0.5) * spacing + (hash01(a, b, seed, 1) * 2.0 - 1.0) * jitter))
            if not inside(at):
                continue
            d, _ = edge.nearest(at, EDGE)
            out.append({
                "at": at, "pine": hash01(a, b, seed, 2) < pines,
                "yaw": hash01(a, b, seed, 3) * math.tau, "scale": hash01(a, b, seed, 4),
                "variant": hash01(a, b, seed, 5), "tall": hash01(a, b, seed, 6),
                "lean": (hash01(a, b, seed, 7) * 2.0 - 1.0, hash01(a, b, seed, 8) * 2.0 - 1.0),
                "edge": d / EDGE,
            })
    return out


# --- The build ----------------------------------------------------------------------


def collection(name, parent):
    c = bpy.data.collections.new(name)
    parent.children.link(c)
    return c


def link_library(assets_path, meshes, collections):
    """The library meshes and collections the file's objects and trees need,
    linked if the base does not have them already."""
    want_meshes = [m for m in meshes if m not in bpy.data.meshes]
    want_cols = [c for c in collections if c not in bpy.data.collections]
    if not want_meshes and not want_cols:
        return
    with bpy.data.libraries.load(assets_path, link=True) as (src, dst):
        dst.meshes = [m for m in want_meshes if m in src.meshes]
        dst.collections = [c for c in want_cols if c in src.collections]


def main():
    doc = json.load(open(os.path.join(ROOT, LEVEL), encoding="utf-8"))
    catalog = json.load(open(os.path.join(ROOT, "assets/level3d/catalog.json"), encoding="utf-8"))
    ids = {o["id"] for o in doc["objects"]}
    say("level %s: %d objects, %d land, %d water, %d forest"
        % (LEVEL, len(doc["objects"]), len(doc["terrain"]["land"]), len(doc.get("water", [])),
           len(doc.get("forest", []))))

    # What stood where, before it goes: the report compares.
    before = {}
    for o in bpy.data.objects:
        key = o.name.replace(".", "_")
        if key in ids:
            before[key] = (o.matrix_world.copy(), o.data.name if o.data else
                           (o.instance_collection.name if o.instance_collection else None))
    old_trees = sum(1 for o in bpy.data.objects if o.name.startswith(("ForestTree", "Beyond_Tree")))

    doomed = set()
    for name in REPLACED_COLLECTIONS:
        doomed.update(bpy.data.collections[name].all_objects)
    doomed.update(o for o in bpy.data.objects if o.name.replace(".", "_") in ids)
    for o in doomed:
        bpy.data.objects.remove(o, do_unlink=True)
    say("base: %d objects taken out, %d trees among them" % (len(doomed), old_trees))

    materials = {m.name: m for m in bpy.data.materials}
    assets = os.path.join(os.path.dirname(bpy.data.filepath), "jackal_assets.blend")
    lib_meshes = BROAD + PINES + [a["mesh"] for a in catalog["assets"].values() if "mesh" in a]
    lib_cols = [a["collection"] for a in catalog["assets"].values() if "collection" in a]
    link_library(assets, lib_meshes, lib_cols)

    top = bpy.data.collections["Jackal_LowPoly"]
    gen_terrain = collection("Gen_Terrain", top)
    gen_vegetation = collection("Gen_Vegetation", top)
    gen_props = collection("Gen_Props", top)

    meshes, brow_edges, shore_edges = build_ground(doc, materials)
    for name, mesh in meshes.items():
        gen_terrain.objects.link(bpy.data.objects.new(name, mesh))
    gen_terrain.objects.link(bpy.data.objects.new("Shore_Lines", build_shore_lines(brow_edges, materials["J_Black"])))
    shoreline = bpy.data.objects.get("J_Shoreline")
    if shoreline:
        old = shoreline.data
        shoreline.data = trace_shoreline(shore_edges)
        bpy.data.meshes.remove(old)
    say("ground: %d brow edges drawn, J_Shoreline %d edges" % (len(brow_edges), len(shore_edges)))

    trees = 0
    for k, polygon in enumerate(doc.get("forest", [])):
        gen_vegetation.objects.link(bpy.data.objects.new(
            "Forest_Floor_%s" % polygon["id"],
            floor_mesh(polygon, materials["J_ForestFloor"], "Forest_Floor_%s" % polygon["id"])))
        for tree in tree_positions(polygon):
            names = PINES if tree["pine"] else BROAD
            mesh = bpy.data.meshes[names[min(int(tree["variant"] * len(names)), len(names) - 1)]]
            o = bpy.data.objects.new("ForestTree_%s_%d" % (polygon["id"], trees), mesh)
            size = TREE_SCALE[0] + (TREE_SCALE[1] - TREE_SCALE[0]) * tree["scale"]
            size *= EDGE_SCALE + (1.0 - EDGE_SCALE) * min(tree["edge"], 1.0)
            o.location = (tree["at"].x, -tree["at"].y, FLOOR_LIFT)
            o.rotation_euler = (tree["lean"][0] * TREE_LEAN, tree["lean"][1] * TREE_LEAN, tree["yaw"])
            o.scale = (size, size, size * (TREE_TALL[0] + (TREE_TALL[1] - TREE_TALL[0]) * tree["tall"]))
            gen_vegetation.objects.link(o)
            trees += 1
    say("forest: %d floors, %d trees (the base had %d)" % (len(doc.get("forest", [])), trees, old_trees))

    errors = []
    for obj in doc["objects"]:
        asset = catalog["assets"][obj["asset"]]
        if "mesh" in asset:
            o = bpy.data.objects.new(obj["id"], bpy.data.meshes[asset["mesh"]])
        else:
            o = bpy.data.objects.new(obj["id"], None)
            o.instance_type = "COLLECTION"
            o.instance_collection = bpy.data.collections[asset["collection"]]
        x, y, zz = obj["pos"]
        o.location = (x, -zz, y)
        o.rotation_euler = (0.0, 0.0, math.radians(obj["yaw"]))
        o.scale = (obj["scale"],) * 3
        (gen_vegetation if obj["asset"].startswith("Palm") else gen_props).objects.link(o)
        if obj["id"] in before:
            was, data = before[obj["id"]]
            now = o.matrix_basis  # matrix_world waits for a depsgraph update
            errors.append(((now.translation - was.translation).length,
                           abs(((now.to_euler().z - was.to_euler().z + math.pi) % math.tau) - math.pi),
                           abs(now.to_scale().x - was.to_scale().x), data == (o.data.name if o.data else o.instance_collection.name)))
    if errors:
        worst = sorted(zip(errors, [o["id"] for o in doc["objects"] if o["id"] in before]), key=lambda e: -e[0][0])[:5]
        for e, name in worst:
            if e[0] > 0.002:
                say("  %s is %.3f m from where the base had it (base %s, now %s)"
                    % (name, e[0], tuple(round(v, 3) for v in before[name][0].translation),
                       tuple(round(v, 3) for v in bpy.data.objects[name].matrix_basis.translation)))
        say("objects: %d placed; against the base: position %.4f m at worst, yaw %.5f rad, scale %.4f, "
            "%d of %d the same asset" % (len(doc["objects"]), max(e[0] for e in errors),
                                         max(e[1] for e in errors), max(e[2] for e in errors),
                                         sum(1 for e in errors if e[3]), len(errors)))

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=OUT, relative_remap=True, copy=True)
    say("saved %s" % OUT)
    if GLB:
        path = os.path.join(ROOT, GLB)
        namespace = {"__name__": "jackal_export_glb"}
        exec(bpy.data.texts["jackal_export_glb.py"].as_string(), namespace)
        namespace["export_stage"](path)
        say("exported %s, %.1f MB" % (path, os.path.getsize(path) / 1e6))
        _import_uncompressed(path)


def _import_uncompressed(path):
    """Have Godot import the glb with its vertex positions uncompressed.
    Compressed, a surface's positions are 16 bits across its own bounds, so a
    vertex two surfaces share -- the light facet and the dark one, the slope
    and the sand -- comes out a hair apart in each, and the water shows
    through the crack as a line of bright pixels close up. The ground is one
    mesh the length of the level, where a step is about the size of a pixel
    at the preview's closest zoom. An existing .import keeps its uid and
    only has the flag turned; a missing one is started with just the flag,
    which Godot fills in with its defaults on import."""
    imp = path + ".import"
    key = "meshes/force_disable_compression="
    if os.path.exists(imp):
        text = open(imp, encoding="utf-8").read()
        if key + "false" in text:
            open(imp, "w", encoding="utf-8", newline="\n").write(text.replace(key + "false", key + "true"))
    else:
        open(imp, "w", encoding="utf-8", newline="\n").write(
            '[remap]\n\nimporter="scene"\n\n[params]\n\n%strue\n' % key)
    say("%s: vertex compression off" % imp)


try:
    main()
except Exception:
    import traceback
    REPORT.append(traceback.format_exc())
finally:
    os.makedirs(os.path.dirname(REPORT_PATH), exist_ok=True)
    open(REPORT_PATH, "w", encoding="utf-8").write("\n".join(REPORT) + "\n")
