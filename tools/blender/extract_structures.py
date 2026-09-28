# Reads stage 1's walls, bridge and gate frame off the hand-built base,
# resources/3d/jackal_stage1_lowpoly.blend, and writes them as the level
# file's "walls", "bridges" and gate object, for tools/level_structures.gd to
# put into assets/level3d/stage-0.json (docs/level-editor-plan.md, part 3):
#
#     blender-launcher -b resources/3d/jackal_stage1_lowpoly.blend --python tools/blender/extract_structures.py -- build/level3d/structures.json
#
# Every piece is a box, and is read off its own mesh -- before its bevel and
# its contour, which the builder puts back from the same base objects:
#
#   wall    J_Fortress's Wall_* and WallN_*: the long axis from and to, the
#           short one the width. J_Concrete is the "wall" style, the light
#           concrete of the sides and posts "side". Its merlons, the row of
#           Merlon objects along one edge, are the first one's distance from
#           the start, the step and the count.
#   bridge  Bridge_Deck from and to and its width, the piers' distances from
#           the start, the plates' first, step and count.
#   gate    J_Gate_Frame's middle, where the Gate object stands.
import bpy, json, math, sys, traceback

OUT = sys.argv[sys.argv.index("--") + 1]
REPORT = []


def bounds(o):
    """The box of an object's own mesh in the level's axes: x, z (south),
    height."""
    ws = [o.matrix_world @ v.co for v in o.data.vertices]
    xs = [v.x for v in ws]
    zs = [-v.y for v in ws]
    hs = [v.z for v in ws]
    return min(xs), max(xs), min(zs), max(zs), min(hs), max(hs)


def r(v):
    return round(v, 3)


def segment(o):
    x0, x1, z0, z1, h0, h1 = bounds(o)
    if x1 - x0 >= z1 - z0:
        zc = (z0 + z1) * 0.5
        return [r(x0), r(zc)], [r(x1), r(zc)], r(z1 - z0), r(h1)
    xc = (x0 + x1) * 0.5
    return [r(xc), r(z0)], [r(xc), r(z1)], r(x1 - x0), r(h1)


try:
    fortress = bpy.data.collections["J_Fortress"].objects
    walls = []
    merlons = [o for o in fortress if o.name.startswith("Merlon")]
    for o in sorted(fortress, key=lambda o: o.name):
        if not o.name.startswith("Wall"):
            continue
        a, b, width, height = segment(o)
        style = "wall" if o.data.materials[0].name == "J_Concrete" else "side"
        wall = {"id": o.name, "style": style, "from": a, "to": b, "width": width, "height": height}
        # The merlons on top of it: centres inside its box.
        x0, x1, z0, z1, h0, h1 = bounds(o)
        on = [m for m in merlons if x0 <= m.location.x <= x1 and z0 <= -m.location.y <= z1]
        if on:
            dx, dz = b[0] - a[0], b[1] - a[1]
            length = math.hypot(dx, dz)
            along = sorted(((m.location.x - a[0]) * dx + (-m.location.y - a[1]) * dz) / length for m in on)
            steps = [along[k + 1] - along[k] for k in range(len(along) - 1)]
            # Which edge they run along: left of from -> to is north for a
            # wall running east.
            left = (dz / length, -dx / length)
            m = on[0]
            off = (m.location.x - (a[0] + b[0]) * 0.5) * left[0] + (-m.location.y - (a[1] + b[1]) * 0.5) * left[1]
            wall["merlons"] = {"side": "left" if off > 0 else "right", "first": r(along[0]),
                               "step": r(sum(steps) / len(steps)) if steps else 0.96, "count": len(on)}
            REPORT.append("%s: %d merlons, steps %s, %.3f off the middle" % (o.name, len(on),
                          sorted(set(r(s) for s in steps)), off))
            for mm in on:
                merlons.remove(mm)
        walls.append(wall)
    REPORT.append("merlons on no wall: %d" % len(merlons))

    deck = bpy.data.objects["Bridge_Deck"]
    a, b, width, _ = segment(deck)
    piers = []
    for o in bpy.data.objects:
        if o.name.startswith("Bridge_Pier"):
            x0, x1 = bounds(o)[:2]
            piers.append(r((x0 + x1) * 0.5 - a[0]))
    piers.sort()
    plates = sorted(o.location.x - a[0] for o in bpy.data.objects if o.name.startswith("Bridge_Plate"))
    steps = [plates[k + 1] - plates[k] for k in range(len(plates) - 1)]
    bridge = {"id": "Bridge", "from": a, "to": b, "width": width, "piers": piers,
              "plates": {"first": r(plates[0]), "step": r(sum(steps) / len(steps)), "count": len(plates)}}
    REPORT.append("bridge: plates steps %s" % sorted(set(r(s) for s in steps)))

    frame = bpy.data.collections["J_Gate_Frame"].objects
    boxes = [bounds(o) for o in frame]
    centre = [r((min(b[0] for b in boxes) + max(b[1] for b in boxes)) * 0.5),
              r((min(b[2] for b in boxes) + max(b[3] for b in boxes)) * 0.5)]
    gate = {"id": "Gate", "asset": "Gate", "pos": [centre[0], 0.0, centre[1]], "yaw": 0.0, "scale": 1.0}

    json.dump({"walls": walls, "bridges": [bridge], "gate": gate, "report": REPORT},
              open(OUT, "w"), indent=1)
except Exception:
    open(OUT, "w").write(json.dumps({"error": traceback.format_exc()}))
