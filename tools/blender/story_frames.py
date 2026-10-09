# The story's comic frames (docs/story/frames.md) as blockouts: each frame a
# scene of its own (Intro_01, Intro_03, Intro_08...), its camera, its light
# and its masses, flat colours lit in two tones and inked by the compositor
# -- not the picture, but the layout a generated picture is painted over
# (the prompts: docs/story/frame-prompts.md). 16:9, the game's 2048x1152.
# The comic's frames are in resources/3d/jackal_story_frames.blend, the
# briefing table (Intro_01_3D, "01_3D") in resources/3d/jackal_intro_01_3d.blend;
# each blend's text block jackal_story_frames.py only runs this file, so that
# inside Blender, either blend open:
#
#     exec(bpy.data.texts["jackal_story_frames.py"].as_string())
#     build_frame(8); render_frame(8, "//../../docs/renders/story/intro_08.png")
#
# or headless, the scene saved into the blend with --save:
#
#     blender -b resources/3d/jackal_intro_01_3d.blend
#         --python tools/blender/story_frames.py -- --build 01_3D [--save]
#
# Paths starting // are the open blend's: both blends are in resources/3d.
#
# Every frame leaves room for its caption, which the game lays over the
# picture rather than the picture carrying it (CAPTION in each builder).
import bpy, bmesh, math, random, sys
from mathutils import Vector, Matrix, noise
from bpy_extras import anim_utils

CHINOOK_GLB = "//jackal_chinook.glb"
CAR_GLB = {"olive": "//jackal_armored.glb", "blue": "//jackal_armored_b.glb"}
# As the title's landing (level3d_splash_landing.gd): the jeep 1:1, the
# Chinook at Level3DChinook.MODEL_SCALE / 0.375 against it.
CHINOOK_SCALE = 0.31 / 0.375
CAR_SCALE = 0.96
RES = (2048, 1152)

INK = (0.008, 0.006, 0.006)
INK_DEPTH = 0.06
INK_NORMAL = 0.9


# ---------------------------------------------------------------------------
# Materials

def _srgb(r, g, b):
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(r / 255), f(g / 255), f(b / 255))


def _bsdf(m):
    return next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.use_nodes else None


def _rgba(sockets, name):
    return next(s for s in sockets if s.name == name and s.type == "RGBA")


def _mat(name, rgb, flat=False):
    """A plain colour; `flat` ones are not lit (lamps, the sun, glow)."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    b = _bsdf(m)
    b.inputs["Base Color"].default_value = (*rgb, 1.0)
    b.inputs["Roughness"].default_value = 1.0
    b.inputs["Specular IOR Level"].default_value = 0.0
    m.diffuse_color = (*rgb, 1.0)
    m["flat"] = flat
    return m


def _vcol_mat(name, attr="Col"):
    m = _mat(name, (1, 1, 1))
    nt = m.node_tree
    a = nt.nodes.get("SF_Attr") or nt.nodes.new("ShaderNodeAttribute")
    a.name, a.attribute_name = "SF_Attr", attr
    nt.links.new(a.outputs["Color"], _bsdf(m).inputs["Base Color"])
    return m


def toon(mats, shade, step=0.5):
    """Two tones: lit, or `shade` (a colour, the shadow's tint) times the
    base -- a diffuse lighting stepped at `step`, multiplied in, emitted.
    The glbs' baked contours are left as they are."""
    for m in mats:
        if m and m.name.split(".")[0].endswith("Contour"):
            # The glbs' inverted hulls: Godot culls their front faces and
            # casts no shadow from them; Blender must be told both, or the
            # hull hides the body in black and wraps it in its own shadow.
            m.use_backface_culling = True
            for attr in ("use_backface_culling_shadow",):
                if hasattr(m, attr):
                    setattr(m, attr, True)
            if hasattr(m, "shadow_method"):
                m.shadow_method = "NONE"
            if hasattr(m, "use_transparent_shadow"):
                m.use_transparent_shadow = True
            nt = m.node_tree if m.use_nodes else None
            if nt and not nt.nodes.get("SF_NoShadow"):
                # Transparent to shadow rays, itself to the camera.
                out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output)
                surf = out.inputs["Surface"].links[0].from_socket if out.inputs["Surface"].is_linked else None
                if surf is not None:
                    lp = nt.nodes.new("ShaderNodeLightPath")
                    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
                    mix = nt.nodes.new("ShaderNodeMixShader")
                    mix.name = "SF_NoShadow"
                    nt.links.new(lp.outputs["Is Shadow Ray"], mix.inputs[0])
                    nt.links.new(surf, mix.inputs[1])
                    nt.links.new(tr.outputs[0], mix.inputs[2])
                    nt.links.new(mix.outputs[0], out.inputs["Surface"])
                    m.blend_method = "HASHED" if hasattr(m, "blend_method") else None
            continue
        if not m or not m.use_nodes:
            continue
        nt = m.node_tree
        out = next((n for n in nt.nodes if n.type == "OUTPUT_MATERIAL" and n.is_active_output), None)
        bsdf = _bsdf(m)
        if out is None or bsdf is None:
            continue
        base = bsdf.inputs["Base Color"]
        if m.get("flat"):
            g = nt.nodes.get("SF_Glow") or nt.nodes.new("ShaderNodeEmission")
            g.name = "SF_Glow"
            if base.is_linked:
                nt.links.new(base.links[0].from_socket, g.inputs["Color"])
            else:
                g.inputs["Color"].default_value = base.default_value
            nt.links.new(g.outputs[0], out.inputs["Surface"])
            continue
        emit = nt.nodes.get("SF_Emit")
        if emit is None:
            dif = nt.nodes.new("ShaderNodeBsdfDiffuse"); dif.name = "SF_Light"
            dif.inputs["Color"].default_value = (1, 1, 1, 1)
            rgb = nt.nodes.new("ShaderNodeShaderToRGB"); rgb.name = "SF_RGB"
            bw = nt.nodes.new("ShaderNodeRGBToBW"); bw.name = "SF_BW"
            ramp = nt.nodes.new("ShaderNodeValToRGB"); ramp.name = "SF_Step"
            ramp.color_ramp.interpolation = "CONSTANT"
            mul = nt.nodes.new("ShaderNodeMix"); mul.name = "SF_Mul"
            mul.data_type, mul.blend_type = "RGBA", "MULTIPLY"
            mul.inputs[0].default_value = 1.0
            emit = nt.nodes.new("ShaderNodeEmission"); emit.name = "SF_Emit"
            nt.links.new(dif.outputs[0], rgb.inputs[0])
            nt.links.new(rgb.outputs[0], bw.inputs[0])
            nt.links.new(bw.outputs[0], ramp.inputs["Fac"])
            nt.links.new(ramp.outputs["Color"], _rgba(mul.inputs, "A"))
            nt.links.new(_rgba(mul.outputs, "Result"), emit.inputs["Color"])
        e = nt.nodes["SF_Step"].color_ramp.elements
        e[0].position, e[0].color = 0.0, (*shade, 1)
        e[1].position, e[1].color = step, (1, 1, 1, 1)
        mul = nt.nodes["SF_Mul"]
        if base.is_linked:
            nt.links.new(base.links[0].from_socket, _rgba(mul.inputs, "B"))
        else:
            _rgba(mul.inputs, "B").default_value = base.default_value
        nt.links.new(emit.outputs[0], out.inputs["Surface"])


def ink(sc):
    """The compositor's line, as jackal_victory_paint.py's: the Laplacian of
    1/depth (outlines; Sobel on depth inks a grazing ground solid) and Sobel
    on the normal (creases), laid over the frame in INK."""
    vl = sc.view_layers[0]
    vl.use_pass_z = vl.use_pass_normal = True
    name = "SF_Ink_" + sc.name
    t = bpy.data.node_groups.get(name) or bpy.data.node_groups.new(name, "CompositorNodeTree")
    for n in list(t.nodes):
        t.nodes.remove(n)
    if not t.interface.items_tree:
        t.interface.new_socket("Image", in_out="OUTPUT", socket_type="NodeSocketColor")
    rl = t.nodes.new("CompositorNodeRLayers")
    rl.scene = sc
    out = t.nodes.new("NodeGroupOutput")

    def filt(sock, kind):
        f = t.nodes.new("CompositorNodeFilter")
        f.inputs["Type"].default_value = kind
        t.links.new(sock, f.inputs["Image"])
        return f.outputs[0]

    def math_(op, a, b=None):
        m = t.nodes.new("ShaderNodeMath")
        m.operation = op
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, float):
                m.inputs[i].default_value = v
            else:
                t.links.new(v, m.inputs[i])
        return m.outputs[0]

    w = math_("DIVIDE", 1.0, math_("MINIMUM", rl.outputs["Depth"], 2000.0))
    lap = math_("ABSOLUTE", filt(w, "Laplace"))
    zedge = math_("GREATER_THAN", math_("DIVIDE", lap, w), INK_DEPTH)
    vlen = t.nodes.new("ShaderNodeVectorMath")
    vlen.operation = "LENGTH"
    t.links.new(filt(rl.outputs["Normal"], "Sobel"), vlen.inputs[0])
    nedge = math_("GREATER_THAN", vlen.outputs["Value"], INK_NORMAL)
    line = math_("MAXIMUM", zedge, nedge)
    mix = t.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    t.links.new(line, mix.inputs[0])
    t.links.new(rl.outputs["Image"], _rgba(mix.inputs, "A"))
    _rgba(mix.inputs, "B").default_value = (*INK, 1)
    t.links.new(_rgba(mix.outputs, "Result"), out.inputs[0])
    sc.compositing_node_group = t
    sc.render.use_compositing = True


# ---------------------------------------------------------------------------
# Scenes, objects

def _scene(name):
    """The frame's scene, emptied: its own collection, world, render setup."""
    sc = bpy.data.scenes.get(name) or bpy.data.scenes.new(name)
    for o in list(sc.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    for c in list(sc.collection.children):
        bpy.data.collections.remove(c)
    bpy.data.orphans_purge(do_local_ids=True, do_linked_ids=False, do_recursive=True)
    c = bpy.data.collections.new(name)
    sc.collection.children.link(c)
    sc.render.engine = "BLENDER_EEVEE"
    sc.render.resolution_x, sc.render.resolution_y = RES
    sc.render.film_transparent = False
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    try:
        sc.eevee.use_shadows = True
    except AttributeError:
        pass
    return sc, c


def _world(sc, name, sky, ambient):
    """The camera sees `sky` (a colour, or (horizon, zenith) for a
    gradient); the lighting only `ambient`, so that the toon step reads the
    sun and the lamps, not the sky."""
    w = bpy.data.worlds.get(name) or bpy.data.worlds.new(name)
    w.use_nodes = True
    nt = w.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg_cam = nt.nodes.new("ShaderNodeBackground")
    bg_amb = nt.nodes.new("ShaderNodeBackground")
    bg_amb.inputs["Color"].default_value = (*ambient, 1)
    if isinstance(sky[0], tuple):
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        nt.links.new(tc.outputs["Generated"], sep.inputs[0])
        nt.links.new(sep.outputs["Z"], ramp.inputs["Fac"])
        e = ramp.color_ramp.elements
        # Generated, for a world, is the view direction: Z 0 at the horizon.
        e[0].position, e[0].color = 0.0, (*sky[0], 1)
        e[1].position, e[1].color = 0.45, (*sky[1], 1)
        nt.links.new(ramp.outputs["Color"], bg_cam.inputs["Color"])
    else:
        bg_cam.inputs["Color"].default_value = (*sky, 1)
    lp = nt.nodes.new("ShaderNodeLightPath")
    mix = nt.nodes.new("ShaderNodeMixShader")
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0])
    nt.links.new(bg_amb.outputs[0], mix.inputs[1])
    nt.links.new(bg_cam.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    sc.world = w
    return w


def _camera(c, sc, at, look, lens, roll=0.0):
    cam = bpy.data.objects.new(sc.name + "_Camera", bpy.data.cameras.new(sc.name + "_Camera"))
    c.objects.link(cam)
    cam.location = at
    q = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y")
    cam.rotation_euler = (q @ Matrix.Rotation(math.radians(roll), 4, "Z").to_quaternion()).to_euler()
    cam.data.lens = lens
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.clip_start, cam.data.clip_end = 0.05, 12000
    sc.camera = cam
    return cam


def _sun(c, name, toward, strength, color=(1, 1, 1), angle=0.5):
    """A sun shining towards `toward` (a direction)."""
    l = bpy.data.lights.new(name, "SUN")
    l.energy, l.color, l.angle = strength, color, math.radians(angle)
    o = bpy.data.objects.new(name, l)
    o.rotation_euler = Vector(toward).to_track_quat("-Z", "Y").to_euler()
    c.objects.link(o)
    return o


def _lamp(c, name, kind, at, look, power, color=(1, 1, 1), size=0.05, cone=None):
    l = bpy.data.lights.new(name, kind)
    l.energy, l.color = power, color
    l.shadow_soft_size = size
    if cone:
        l.spot_size, l.spot_blend = math.radians(cone), 0.15
    o = bpy.data.objects.new(name, l)
    o.location = at
    o.rotation_euler = (Vector(look) - Vector(at)).to_track_quat("-Z", "Y").to_euler()
    c.objects.link(o)
    return o


def _obj(c, name, bm, mats, smooth=False):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    o = bpy.data.objects.new(name, me)
    c.objects.link(o)
    return o


def box(c, name, mat, size, at, rot=(0, 0, 0), bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=2, affect="EDGES")
    o = _obj(c, name, bm, [mat])
    o.location, o.rotation_euler = at, [math.radians(a) for a in rot]
    return o


def cyl(c, name, mat, r, h, at, rot=(0, 0, 0), r2=None, seg=24, smooth=True):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h)
    o = _obj(c, name, bm, [mat], smooth)
    o.location, o.rotation_euler = at, [math.radians(a) for a in rot]
    return o


def ball(c, name, mat, r, at, scale=(1, 1, 1), sub=3):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    bmesh.ops.scale(bm, vec=scale, verts=bm.verts)
    o = _obj(c, name, bm, [mat], True)
    o.location = at
    return o


def ring(c, name, mat, r, thick):
    """A torus lying in XY: radius `r`, its tube `thick` across."""
    bm = bmesh.new()
    seg, sides = 48, 10
    rows = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        rows.append([bm.verts.new(((r + thick / 2 * math.cos(b)) * math.cos(a), (r + thick / 2 * math.cos(b)) * math.sin(a),
                                   thick / 2 * math.sin(b))) for b in (2 * math.pi * j / sides for j in range(sides))])
    for i in range(seg):
        for j in range(sides):
            a, b = rows[i], rows[(i + 1) % seg]
            bm.faces.new((a[j], b[j], b[(j + 1) % sides], a[(j + 1) % sides]))
    return _obj(c, name, bm, [mat], True)


def _import(path, c, suffix):
    """`path` imported into `c` alone, every name with `suffix`."""
    scenes, before = set(bpy.data.scenes), set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=bpy.path.abspath(path))
    out = []
    for o in [o for o in bpy.data.objects if o not in before]:
        if o.name.startswith("Icosphere"):
            bpy.data.objects.remove(o)
            continue
        for cc in list(o.users_collection):
            cc.objects.unlink(o)
        c.objects.link(o)
        o.name = o.name + suffix
        out.append(o)
    for sc in [s for s in bpy.data.scenes if s not in scenes]:
        bpy.data.scenes.remove(sc)
    return out


def _clip(rig, name, part=1.0):
    """The rig posed `part` of the way through its NLA clip `name`."""
    track = rig.animation_data.nla_tracks.get(name)
    a = track.strips[0].action
    f0, f1 = a.frame_range
    frame = f0 + (f1 - f0) * part
    cb = anim_utils.action_get_channelbag_for_slot(a, a.slots[0])
    for fc in cb.fcurves:
        path = fc.data_path
        if not path.startswith("pose.bones"):
            continue
        pb = rig.pose.bones.get(path.split('"')[1])
        if pb is not None:
            getattr(pb, path.rsplit(".", 1)[1])[fc.array_index] = fc.evaluate(frame)
    rig.animation_data.action = None
    for t in rig.animation_data.nla_tracks:
        t.mute = True


def _mats_of(objs):
    return {s.material for o in objs if o.type in ("MESH", "CURVE", "FONT")
            for s in o.material_slots if s.material}


def car(c, k, paint, at, yaw):
    """The players' armoured pickup, stock: every fit and upgrade hidden but
    the missile launcher a cleared round has (as jackal_victory.py)."""
    objs = _import(CAR_GLB[paint], c, ".SF%d" % k)
    root = next(o for o in objs if o.parent is None and "Root" in o.name)
    fits = ("Grad", "HeavyLauncher", "Mortar", "Rail", "StageLauncher", "Stage", "Tube")
    for o in objs:
        base = o.name.rsplit(".SF", 1)[0].split("_", 1)[-1]
        hide = base.startswith(("Up", "Aerial", "Mine", "HeavyMissile", "StageMissile", "Rocket", "Tube"))
        hide = hide or any(base.startswith(f) for f in fits)
        o.hide_render = o.hide_viewport = hide
    root.location = at
    root.rotation_mode = "XYZ"
    root.rotation_euler = (0, 0, math.radians(yaw))
    root.scale = (CAR_SCALE,) * 3
    return root, objs


# ---------------------------------------------------------------------------
# 1. Sahrun. 1987. -- the country's map on a desk under a lamp, the way the
# team will go pencilled on it.
#
# The country is laid out on the original's between-stage map (MapMode):
# six stages one after another, the junta's fortress last. Its pixel art is
# Konami's and is not used; what is kept is the route. The sea is in the
# west, as on stage 1 (the sea on the left, the desert behind the landing,
# the river coming in diagonally from the top right). The Ashra runs down
# from the north-eastern hills, past the capital, to the sea in the
# south-west. Kalmir is a sea port up the coast; the railway goes inland
# from it through the swamp and the mined valley to the capital, which is
# the junta's headquarters (stage 6).

MAP_W, MAP_H = 2.6, 2.6 / 1.5   # the briefing table's sheet, nearly the whole desk (3 x 2)
PIN_SIZE = 1.6           # the pins and the token, grown with the sheet (from Intro_01's 1.2 m)
MAP_PX = (1800, 1200)
MARGIN = 0.035           # the paper's pale edge, of the map's width
# The map's own coordinates: u west to east, v south to north, 0..1.
ASHRA = [(0.85, 0.95), (0.80, 0.88), (0.71, 0.74), (0.63, 0.58), (0.52, 0.44), (0.42, 0.31),
         (0.33, 0.21), (0.24, 0.15), (0.16, 0.135)]
STAGES = [(0.31, 0.09),  # the landing, in the desert south of the river
          (0.27, 0.17),  # 1 the checkpoint at the Ashra's last bend
          (0.31, 0.36),  # 2 the old city and the airfield
          (0.19, 0.53),  # 3 Kalmir
          (0.37, 0.66),  # 4 the swamp and the railway
          (0.56, 0.79),  # 5 the mined valley and the garage
          (0.80, 0.88)]  # 6 the capital, the junta's headquarters
RAIL = [(0.20, 0.53), (0.30, 0.60), (0.38, 0.66), (0.48, 0.75), (0.62, 0.83), (0.80, 0.88)]


def _catmull(pts, per=12):
    pts = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(per):
            t = k / per
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t ** 3))
    out.append(pts[-2])
    return out


def _uv_world(u, v, z=0.0):
    return Vector(((u - 0.5) * MAP_W, (v - 0.5) * MAP_H, z))


def _map_image():
    """The land, painted: sea, desert, green along the river, the swamp, the
    valley's ridges, the hills, the paper's margin. Rows from the south."""
    import numpy as np
    w, h = MAP_PX
    u, v = np.meshgrid(np.linspace(0, 1, w), np.linspace(0, 1, h))
    rng = np.random.default_rng(3)
    n = np.zeros_like(u)
    for o in range(5):
        f = 3 * 2 ** o
        a, b, c = rng.uniform(0, 6.28, 3)
        n += np.sin(u * f + a + np.sin(v * f * 1.3 + b)) * np.cos(v * f + c) / 2 ** o
    river = _catmull([Vector(p) for p in ASHRA], 16)
    d = np.full(u.shape, 9.0)
    for p in river[::2]:
        d = np.minimum(d, np.hypot(u - p.x, (v - p.y) * MAP_H / MAP_W))
    coast = 0.14 + 0.025 * np.sin(v * 9) + 0.012 * n + 0.04 * np.clip(v - 0.5, 0, 1)
    hills = np.clip((v + 0.6 * u - 1.25) / 0.15 + 0.15 * n, 0, 1)
    ridges = np.clip(1 - np.abs(np.abs((v - 0.79) - 0.45 * (u - 0.56) - 0.015 * n) - 0.05)
                     / (0.025 + 0.01 * n), 0, 1) * np.clip(1 - np.abs(u - 0.56) / 0.10, 0, 1) ** 0.5
    swamp = np.clip(np.clip(1 - np.hypot((u - 0.36) / 0.09, (v - 0.66) / 0.06) - 0.1 * n, 0, 1) * 3, 0, 1)
    c = lambda r, g, b: np.array([r, g, b], float) / 255
    img = np.empty((h, w, 3))
    img[:] = c(214, 168, 104)
    img *= (1 + 0.05 * n)[..., None]
    green = np.clip(1 - d / 0.04, 0, 1)[..., None] * 0.6
    img = img * (1 - green) + c(150, 156, 92) * green
    for f, col in ((hills, c(132, 96, 64)), (ridges, c(116, 86, 60)), (swamp, c(104, 128, 84))):
        img = img * (1 - f[..., None]) + col * f[..., None]
    img = np.where((u < coast)[..., None], c(92, 140, 170) * (1 + 0.04 * n)[..., None], img)
    edge = (u < MARGIN) | (u > 1 - MARGIN) | (v < MARGIN * 1.5) | (v > 1 - MARGIN * 1.5)
    img = np.where(edge[..., None], c(232, 222, 196), img)
    rgba = np.concatenate([np.clip(img, 0, 1), np.ones((h, w, 1))], axis=2).astype(np.float32)
    im = bpy.data.images.get("SF1_Sahrun") or bpy.data.images.new("SF1_Sahrun", w, h)
    im.scale(w, h)
    im.pixels.foreach_set(rgba.ravel())
    im.pack()
    return im


def _annulus(c, name, mat, at, r, width):
    """A pencilled ring, flat on the paper (a torus this small inks black)."""
    bm = bmesh.new()
    seg = 40
    outer = [bm.verts.new((math.cos(a) * (r + width / 2), math.sin(a) * (r + width / 2), 0))
             for a in (2 * math.pi * i / seg for i in range(seg))]
    inner = [bm.verts.new((math.cos(a) * (r - width / 2), math.sin(a) * (r - width / 2), 0))
             for a in (2 * math.pi * i / seg for i in range(seg))]
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((inner[i], outer[i], outer[j], inner[j]))
    o = _obj(c, name, bm, [mat])
    o.location = at
    return o


def _map_sheet(c):
    """The sheet, the map's image on it: unrolled on the desk, its left
    edge held down by the cup, its top right corner curling up a little,
    the bottom right a touch."""
    nx, ny = 120, 80
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            curl = 0.045 * max(0.0, (u + v - 1.72) / 0.28) ** 2 \
                + 0.015 * max(0.0, (u - 0.88) / 0.12) ** 2 * max(0.0, (0.2 - v) / 0.2)
            row.append(bm.verts.new(((u - 0.5) * MAP_W, (v - 0.5) * MAP_H, 0.002 + curl)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for lp in f.loops:
                lp[uvl].uv = (lp.vert.co.x / MAP_W + 0.5, lp.vert.co.y / MAP_H + 0.5)
    m = _mat("SF1_Map", (1, 1, 1))
    nt = m.node_tree
    tex = nt.nodes.get("SF_Tex") or nt.nodes.new("ShaderNodeTexImage")
    tex.name, tex.image = "SF_Tex", _map_image()
    nt.links.new(tex.outputs["Color"], _bsdf(m).inputs["Base Color"])
    return _obj(c, "SF1_Map", bm, [m])


def _ribbon(c, name, mat, uvs, width, z, per=12, dashes=0):
    """A line drawn on the map through `uvs`: `width` (metres, or a pair
    from the first point to the last), dashed when `dashes` is the dash's
    length in points."""
    pts = [_uv_world(*p).to_2d() for p in uvs]
    pts = _catmull(pts, per) if per > 1 else pts
    w0, w1 = width if isinstance(width, tuple) else (width, width)
    bm = bmesh.new()
    rows = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        nrm = Vector((-d.y, d.x)) * (w0 + (w1 - w0) * i / (len(pts) - 1)) / 2
        rows.append([bm.verts.new((*(p + nrm * s), z)) for s in (-1, 1)])
    for i, (a, b) in enumerate(zip(rows, rows[1:])):
        if dashes and (i // dashes) % 2:
            continue
        bm.faces.new((a[0], b[0], b[1], a[1]))
    return _obj(c, name, bm, [mat])


JEEP_TOKEN = 0.06        # the die-cast pickup's length on the map, metres (the glb's hull: 4.12)


def _flag(c, name, cloth, pin, at, size=1.0):
    """A map pin with a small flag, stuck in at `at`, the cloth square to
    the camera; returns the cloth's middle. No number on it: a generated
    picture would scrawl one."""
    h = 0.05 * size
    cyl(c, name + "Pin", pin, 0.0011 * size, h, at + Vector((0, 0, h / 2)), seg=8)
    w, t = 0.024 * size, 0.016 * size
    mid = at + Vector((w / 2 + 0.0008, 0, h - t / 2))
    box(c, name, cloth, (w, 0.0008, t), mid)
    return mid


def build_intro_01():
    sc, c = _scene("Intro_01")
    _world(sc, "SF1_World", _srgb(20, 16, 14), _srgb(36, 30, 28))
    M = dict(
        desk=_mat("SF1_Desk", _srgb(96, 62, 40)),
        river=_mat("SF1_River", _srgb(48, 104, 170)),
        rail=_mat("SF1_Rail", _srgb(52, 44, 38)),
        red=_mat("SF1_Red", _srgb(176, 30, 28)),
        black=_mat("SF1_Black", _srgb(30, 28, 26)),
        paper=_mat("SF1_Paper", _srgb(244, 238, 222)),
        pencil=_mat("SF1_Pencil", _srgb(214, 170, 40)),
        brass=_mat("SF1_Brass", _srgb(190, 150, 70)),
        cup=_mat("SF1_Cup", _srgb(222, 220, 210)),
        coffee=_mat("SF1_Coffee", _srgb(54, 34, 22)),
        glass=_mat("SF1_Glass", _srgb(170, 196, 200)),
        photo=_mat("SF1_Photo", _srgb(120, 116, 108)),
        flag=_mat("SF1_Flag", _srgb(200, 30, 26)),
    )
    box(c, "SF1_Desk", M["desk"], (3.0, 2.0, 0.06), (0, 0, -0.03))
    _map_sheet(c)
    # The Ashra, widening to its mouth; the railway, its sleepers.
    _ribbon(c, "SF1_Ashra", M["river"], ASHRA, (0.003, 0.009), 0.0032, per=16)
    _ribbon(c, "SF1_Railway", M["rail"], RAIL, 0.0016, 0.0034, per=10)
    _ribbon(c, "SF1_Sleepers", M["rail"], RAIL, 0.006, 0.0033, per=40, dashes=1)
    # The way, in red pencil: dashes from the landing through the stages,
    # each stage ringed and flagged, the capital ringed twice under the
    # junta's own flag -- the staff map's pins that the between-stage map
    # will carry on.
    _ribbon(c, "SF1_Route", M["red"], STAGES, 0.0028, 0.0038, per=24, dashes=3)
    for k, (u, v) in enumerate(STAGES[1:6], 1):
        at = _uv_world(u, v, 0.0039)
        _annulus(c, "SF1_Stage%d" % k, M["red"], at, 0.011, 0.003)
        _flag(c, "SF1_Flag%d" % k, M["flag"], M["black"], at)
    land = _uv_world(*STAGES[0], 0.004)
    for s in (-1, 1):
        box(c, "SF1_LandingX%d" % s, M["red"], (0.026, 0.0028, 0.001), land, rot=(0, 0, 45 * s))
    cap = _uv_world(*STAGES[6], 0.004)
    box(c, "SF1_Capital", M["black"], (0.016, 0.016, 0.0015), cap)
    _annulus(c, "SF1_CapitalRing", M["red"], cap - Vector((0, 0, 0.0001)), 0.026, 0.0034)
    _annulus(c, "SF1_CapitalRing2", M["red"], cap + Vector((0.002, -0.001, -0.0001)), 0.031, 0.0024)
    junta = _flag(c, "SF1_Junta", M["black"], M["black"], cap, size=1.4)
    coil = _annulus(c, "SF1_JuntaCoil", M["red"], junta + Vector((0, -0.0008, 0)), 0.0042, 0.0016)
    coil.rotation_euler = (math.radians(90), 0, 0)
    # The team's token on the landing: a die-cast pickup, as a staff map's
    # piece, nose up the route.
    root, _ = car(c, 0, "olive", land + Vector((0.012, -0.012, -0.002)), 0.0)
    root.scale = (JEEP_TOKEN / 4.12,) * 3
    root.rotation_euler = (0, 0, math.radians(180 - 18))
    # Kalmir's docks, a black dot on the coast.
    cyl(c, "SF1_Kalmir", M["black"], 0.006, 0.002, _uv_world(*STAGES[3], 0.004))
    # A pencil across the desert, the cup standing on the map's left edge
    # to hold it down, a loupe on
    # the desert east of the river, a photograph half under the map.
    cyl(c, "SF1_Pencil", M["pencil"], 0.0045, 0.18, (0.36, -0.30, 0.0075), rot=(0, 90, 28), seg=6, smooth=False)
    cyl(c, "SF1_PencilTip", M["desk"], 0.0045, 0.02, (0.36 + 0.1 * math.cos(math.radians(28)),
        -0.30 + 0.1 * math.sin(math.radians(28)), 0.0075), rot=(0, 90, 28), r2=0.0005, seg=6, smooth=False)
    cup = Vector((-0.585, 0.16, 0.002))
    cyl(c, "SF1_Cup", M["cup"], 0.045, 0.09, cup + Vector((0, 0, 0.045)), r2=0.05)
    cyl(c, "SF1_Coffee", M["coffee"], 0.044, 0.002, cup + Vector((0, 0, 0.083)))
    loupe = Vector((0.40, -0.06, 0.012))
    ring(c, "SF1_LoupeRim", M["brass"], 0.05, 0.005).location = loupe
    cyl(c, "SF1_LoupeGlass", M["glass"], 0.048, 0.003, loupe)
    cyl(c, "SF1_LoupeHandle", M["black"], 0.008, 0.09, loupe + Vector((0.09, -0.03, 0)), rot=(0, 90, -18))
    box(c, "SF1_Photo", M["photo"], (0.14, 0.10, 0.002), (-0.62, -0.38, 0.001), rot=(0, 0, -12))
    # The lamp out of frame, upper left: a warm pool on the map, the desk's
    # edges falling off into the dark.
    _lamp(c, "SF1_Lamp", "SPOT", (-0.5, -0.2, 1.3), (0.05, 0.05, 0), 60.0, _srgb(255, 226, 180), size=0.15, cone=75)
    # A low fill from our side, so the flags' and the token's faces to us
    # are lit, not in the lamp's shade.
    _lamp(c, "SF1_Fill", "SPOT", (0.1, -0.9, 0.25), (0.0, 0.1, 0.03), 6.0, _srgb(255, 236, 210), size=0.2, cone=70)
    _camera(c, sc, (0.0, -1.18, 0.78), (0.0, -0.02, 0.0), 40.0)
    toon(_mats_of(c.objects), _srgb(70, 62, 70), step=0.18)
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 2. In one night, the army took the capital. -- the palace square at
# night: tanks on the paving, soldiers on the steps, and down the palace's
# portico, from its roof, the junta's black banner with its red coil being
# let down over the columns, lit from below by floodlights.

TANK_GLB = "//jackal_tank.glb"
SOLDIER_GLB = "//low_poly_soldier.glb"
TANK_SCALE2 = 1.3        # the game's tank is a stubby 5.3 m; ~7 m here
PALACE_Y = 52.0          # the palace's front
PALACE_W, PALACE_H = 54.0, 17.0


def _unit(c, path, k, at, yaw, scale, clip, part=0.0):
    """A rigged glb (a tank, a soldier) stood at `at`, turned `yaw` degrees
    from facing -Y, posed at `part` of its NLA clip `clip`."""
    objs = _import(path, c, ".U%d" % k)
    rig = next(o for o in objs if o.type == "ARMATURE")
    rig.location = at
    rig.rotation_mode = "XYZ"
    rig.rotation_euler = (0, 0, math.radians(yaw))
    rig.scale = (scale,) * 3
    _clip(rig, clip, part)
    return rig, objs


def _palace(c, M):
    y0, w, h = PALACE_Y, PALACE_W, PALACE_H
    box(c, "SF2_Palace", M["stone"], (w, 16, h), (0, y0 + 8, h / 2))
    box(c, "SF2_Cornice", M["stone_dark"], (w + 1.0, 17, 0.8), (0, y0 + 8, h + 0.4))
    box(c, "SF2_Parapet", M["stone"], (w + 1.0, 0.6, 1.4), (0, y0 - 0.2, h + 1.5))
    # Two rows of windows, dark, across the wings.
    for row, z in enumerate((5.0, 11.0)):
        for i in range(-12, 13):
            x = i * 2.1
            if abs(x) < 9.5:
                continue
            box(c, "SF2_Win%d_%d" % (row, i), M["window"], (1.0, 0.3, 2.4), (x, y0 - 0.05, z))
    # The portico: eight columns on a podium, the entablature, a pediment.
    box(c, "SF2_Podium", M["stone_dark"], (20, 6, 1.6), (0, y0 - 3, 0.8))
    for i in range(8):
        x = -8.4 + i * 2.4
        cyl(c, "SF2_Column%d" % i, M["stone"], 0.6, h - 3.2, (x, y0 - 4.6, 1.6 + (h - 3.2) / 2), r2=0.52, seg=16)
    box(c, "SF2_Entablature", M["stone"], (20, 6, 1.6), (0, y0 - 3, h - 0.8))
    bm = bmesh.new()
    a, b, t = bm.verts.new((-10.4, 0, 0)), bm.verts.new((10.4, 0, 0)), bm.verts.new((0, 0, 3.4))
    bm.faces.new((a, b, t))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=6.0)
    ped = _obj(c, "SF2_Pediment", bm, [M["stone"]])
    ped.location = (0, y0 - 6.0 + 6.0, h)
    # The steps down to the square, the doors behind the columns.
    for i in range(8):
        box(c, "SF2_Step%d" % i, M["stone_dark"], (22 + i * 1.2, 0.5, 0.2), (0, y0 - 6.25 - i * 0.5, 1.5 - i * 0.2))
    box(c, "SF2_Door", M["window"], (3.0, 0.3, 5.0), (0, y0 - 0.05, 4.1))
    # A dome over the middle.
    cyl(c, "SF2_Drum", M["stone"], 6.0, 4.0, (0, y0 + 8, h + 2.0), seg=32)
    dome = ball(c, "SF2_Dome", M["dome"], 6.2, (0, y0 + 8, h + 4.0), scale=(1, 1, 0.8), sub=4)
    cyl(c, "SF2_Spire", M["stone_dark"], 0.3, 3.0, (0, y0 + 8, h + 10.4), seg=8)


def _banner(c, M, x, y, width, top, hang):
    """The junta's banner let down at `y` from `top`: the cloth hanging
    `hang` metres, rippled, the rest still rolled at its foot."""
    nx, nz = 16, 24
    bm = bmesh.new()
    rows = []
    for j in range(nz + 1):
        z = top - hang * j / nz
        row = []
        for i in range(nx + 1):
            u = i / nx
            ripple = 0.25 * math.sin(u * 9.0 + j * 0.5) * (j / nz)
            row.append(bm.verts.new((x + (u - 0.5) * width, y - ripple - 0.15, z)))
        rows.append(row)
    for j in range(nz):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    _obj(c, "SF2_Banner", bm, [M["banner"]], True)
    roll = cyl(c, "SF2_BannerRoll", M["banner"], 0.55, width + 0.2, (x, y - 0.5, top - hang), rot=(0, 90, 0))
    # Flat: a torus this thin from this far inks black.
    coil = _annulus(c, "SF2_BannerCoil", M["red"], (x, y - 0.6, top - hang * 0.42), width * 0.27, 0.5)
    coil.rotation_euler = (math.radians(90), 0, 0)
    ball(c, "SF2_BannerHead", M["red"], 0.9, (x + width * 0.27, y - 0.95, top - hang * 0.30), scale=(1.5, 0.3, 1.0))
    # The ropes it is let down on, up to the men on the roof.
    for s in (-1, 1):
        cyl(c, "SF2_Rope%d" % s, M["rope"], 0.04, hang + 1.4, (x + s * width / 2, y - 0.7, top - hang / 2 + 0.7), seg=6)


def build_intro_02():
    sc, c = _scene("Intro_02")
    _world(sc, "SF2_World", (_srgb(44, 52, 86), _srgb(10, 12, 26)), _srgb(30, 34, 56))
    M = dict(
        paving=_mat("SF2_Paving", _srgb(120, 116, 110)),
        stone=_mat("SF2_Stone", _srgb(214, 200, 176)),
        stone_dark=_mat("SF2_StoneDark", _srgb(170, 156, 136)),
        window=_mat("SF2_Window", _srgb(34, 32, 40)),
        dome=_mat("SF2_Dome", _srgb(150, 168, 150)),
        banner=_mat("SF2_Banner", _srgb(26, 24, 24)),
        # The banner's coil is printed on it: flat, never in shade.
        red=_mat("SF2_Red", _srgb(196, 30, 26), flat=True),
        rope=_mat("SF2_Rope", _srgb(200, 190, 160)),
        pole=_mat("SF2_Pole", _srgb(40, 40, 44)),
        lamp=_mat("SF2_LampGlow", _srgb(255, 226, 160), flat=True),
        beam=_mat("SF2_Beam", _srgb(120, 134, 170), flat=True),
        moon=_mat("SF2_Moon", _srgb(236, 236, 220), flat=True),
    )
    box(c, "SF2_Square", M["paving"], (240, 200, 0.2), (0, 20, -0.1))
    _palace(c, M)
    # Over the portico's columns, from the entablature; two men up on its
    # ledge either side, letting it down.
    _banner(c, M, 0.0, PALACE_Y - 6.1, 7.0, PALACE_H, 9.5)
    for k, x in enumerate((-5.6, 5.6)):
        _unit(c, SOLDIER_GLB, 10 + k, (x, PALACE_Y - 5.4, PALACE_H), 180.0, 1.0, "Attention")
    # The tanks: one close on the left, turned across us, its gun over the
    # square; one further in on the right, facing the palace.
    _unit(c, TANK_GLB, 0, (-7.5, 10.0, 0.0), 245.0, TANK_SCALE2, "Idle")
    _unit(c, TANK_GLB, 1, (9.0, 27.0, 0.0), 130.0, TANK_SCALE2, "Idle")
    # Soldiers on the steps and by the tanks, at the order.
    for k, (x, y, z, yaw) in enumerate(((-6.0, PALACE_Y - 8.4, 0.0, 180.0), (-2.5, PALACE_Y - 8.6, 0.0, 180.0),
                                        (2.5, PALACE_Y - 8.6, 0.0, 180.0), (6.0, PALACE_Y - 8.4, 0.0, 180.0),
                                        (-3.2, 13.5, 0.0, 150.0), (3.0, 19.0, 0.0, 200.0))):
        _unit(c, SOLDIER_GLB, 20 + k, (x, y, z), yaw, 1.0, "Order")
    # Street lamps round the square.
    for k, (x, y) in enumerate(((-16, 20), (16, 20), (-16, 38), (16, 38))):
        post = cyl(c, "SF2_LampPost%d" % k, M["pole"], 0.12, 4.6, (x, y, 2.3), seg=8)
        bulb = ball(c, "SF2_LampBulb%d" % k, M["lamp"], 0.35, (x, y, 5.0))
        post.visible_shadow = bulb.visible_shadow = False
        _lamp(c, "SF2_Street%d" % k, "POINT", (x, y, 5.0), (0, 0, 0), 2500.0, _srgb(255, 210, 150), size=0.3)
    # Floodlights at the foot of the steps, thrown up the front onto the banner.
    for k, x in enumerate((-9.0, 9.0)):
        _lamp(c, "SF2_Flood%d" % k, "SPOT", (x * 0.6, PALACE_Y - 16, 0.6), (x * -0.1, PALACE_Y, 12.0),
              60000.0, _srgb(255, 236, 200), size=0.4, cone=40)
    # Searchlight beams into the sky behind the palace, crossing.
    for k, (x, lean) in enumerate(((-18.0, 18.0), (20.0, -24.0))):
        beam = cyl(c, "SF2_Searchlight%d" % k, M["beam"], 0.6, 120.0, (x, PALACE_Y + 30, 60.0), r2=3.5,
                   rot=(-8, lean, 0), seg=16)
        beam.visible_shadow = False
    ball(c, "SF2_Moon", M["moon"], 14.0, (-120.0, 600.0, 260.0))
    # The moon, cold and from the left behind us; the street lamps warm.
    _sun(c, "SF2_Moonlight", (0.45, 0.55, -0.7), 0.9, _srgb(160, 176, 220))
    _camera(c, sc, (-1.5, -10.0, 1.5), (1.5, 30.0, 10.0), 24.0, roll=-2)
    toon(_mats_of(c.objects), _srgb(64, 70, 108), step=0.5)
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 3. The people called them the Mamba. -- the general on his stand, from
# below and close, against a bright sky: the face lost under the visor,
# only the cap and the white glove on the rail catch the light.

def build_intro_03():
    sc, c = _scene("Intro_03")
    _world(sc, "SF3_World", (_srgb(244, 222, 176), _srgb(150, 176, 204)), _srgb(70, 70, 84))
    M = dict(
        stand=_mat("SF3_Stand", _srgb(120, 112, 100)),
        drape=_mat("SF3_Drape", _srgb(34, 32, 32)),
        red=_mat("SF3_Red", _srgb(184, 30, 26)),
        uniform=_mat("SF3_Uniform", _srgb(104, 110, 74)),
        cap=_mat("SF3_Cap", _srgb(98, 104, 70)),
        band=_mat("SF3_Band", _srgb(168, 30, 26)),
        visor=_mat("SF3_Visor", _srgb(26, 24, 24)),
        gold=_mat("SF3_Gold", _srgb(224, 180, 70)),
        glove=_mat("SF3_Glove", _srgb(244, 240, 230)),
        skin=_mat("SF3_Skin", _srgb(160, 112, 82)),
        metal=_mat("SF3_Metal", _srgb(70, 70, 76)),
        banner=_mat("SF3_Banner", _srgb(30, 28, 28)),
        pole=_mat("SF3_Pole", _srgb(170, 170, 170)),
    )
    # The stand's rail across the bottom of the frame, hung with black, a
    # red coil on it -- the mamba's sign.
    box(c, "SF3_Parapet", M["stand"], (3.2, 0.5, 1.25), (0, 0, 0.625), bevel=0.02)
    box(c, "SF3_Rail", M["stand"], (3.3, 0.6, 0.08), (0, 0, 1.29), bevel=0.01)
    box(c, "SF3_Drape", M["drape"], (1.6, 0.02, 1.1), (0.55, -0.26, 0.68))
    coil = ring(c, "SF3_Coil", M["red"], 0.30, 0.04)
    coil.location, coil.rotation_euler = (0.55, -0.28, 0.66), (math.radians(90), 0, 0)
    ball(c, "SF3_CoilHead", M["red"], 0.08, (0.84, -0.29, 0.78), scale=(1.4, 0.4, 0.9))
    # The general behind the rail.
    g = Vector((0.05, 0.40, 0.0))
    box(c, "SF3_Torso", M["uniform"], (0.58, 0.32, 0.72), g + Vector((0, 0, 1.36)), bevel=0.08)
    box(c, "SF3_Belly", M["uniform"], (0.52, 0.30, 0.25), g + Vector((0, 0, 1.08)), bevel=0.06)
    for s in (-1, 1):
        box(c, "SF3_Board%d" % s, M["gold"], (0.16, 0.11, 0.025), g + Vector((s * 0.23, 0, 1.72)), rot=(0, s * -12, 0))
    for k in range(9):
        box(c, "SF3_Ribbon%d" % k, (M["red"], M["gold"], M["band"])[k % 3], (0.045, 0.012, 0.02),
            g + Vector((-0.20 + (k % 3) * 0.05, -0.165, 1.56 - (k // 3) * 0.026)))
    cyl(c, "SF3_Neck", M["skin"], 0.066, 0.12, g + Vector((0, 0, 1.77)))
    ball(c, "SF3_Head", M["skin"], 0.115, g + Vector((0, 0, 1.89)), scale=(0.9, 1.0, 1.1))
    # The cap: the crown wider at the top, the red band, the visor pulled
    # low over the eyes, the badge.
    cyl(c, "SF3_CapBand", M["band"], 0.114, 0.06, g + Vector((0, 0, 1.97)))
    cyl(c, "SF3_CapCrown", M["cap"], 0.115, 0.07, g + Vector((0, -0.01, 2.035)), r2=0.165, rot=(-8, 0, 0))
    cyl(c, "SF3_CapTop", M["cap"], 0.165, 0.025, g + Vector((0, -0.02, 2.08)), r2=0.155, rot=(-8, 0, 0))
    bm = bmesh.new()
    bmesh.ops.create_circle(bm, cap_ends=True, segments=32, radius=0.125)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.y > 0.02], context="VERTS")
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.012)
    visor = _obj(c, "SF3_Visor", bm, [M["visor"]])
    visor.location, visor.rotation_euler = g + Vector((0, -0.06, 1.95)), (math.radians(-24), 0, 0)
    ball(c, "SF3_Badge", M["gold"], 0.028, g + Vector((0, -0.13, 2.01)), scale=(1, 0.3, 1))
    # Both arms out to the rail, the gloves over its edge towards us.
    for side, hand in ((-1, Vector((-0.36, -0.25, 1.355))), (1, Vector((0.46, -0.22, 1.355)))):
        sh = g + Vector((side * 0.28, 0.0, 1.62))
        d = hand - sh
        arm = cyl(c, "SF3_Arm%d" % side, M["uniform"], 0.062, d.length, (sh + hand) / 2, r2=0.052)
        arm.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        box(c, "SF3_Palm%d" % side, M["glove"], (0.11, 0.12, 0.04), hand + Vector((0, 0.0, -0.005)), bevel=0.014)
        for k in range(4):
            # Curled over the rail's front edge and down its face.
            box(c, "SF3_Finger%d_%d" % (side, k), M["glove"], (0.025, 0.03, 0.10),
                hand + Vector((-0.04 + k * 0.027, -0.072, -0.045)), rot=(-12, 0, 0), bevel=0.01)
        box(c, "SF3_Thumb%d" % side, M["glove"], (0.024, 0.065, 0.024),
            hand + Vector((-side * 0.065, -0.02, 0.0)), rot=(0, 0, side * 30), bevel=0.01)
    # Microphones on goosenecks, off to his left so the face stays clear.
    for k, x in enumerate((0.22, 0.34)):
        cyl(c, "SF3_MicStem%d" % k, M["metal"], 0.008, 0.36, (x, -0.16, 1.47), rot=(-20, 0, 18), seg=8)
        ball(c, "SF3_Mic%d" % k, M["metal"], 0.034, (x - 0.06, -0.10, 1.64), scale=(1, 1, 1.5))
    # Behind him the sky; a black banner hung from a gantry far off on the
    # right, and two flagpoles on the left.
    box(c, "SF3_Gantry", M["pole"], (0.25, 0.25, 16), (5.0, 14.0, 8.0))
    box(c, "SF3_Banner", M["banner"], (3.6, 0.05, 9.0), (7.0, 14.0, 9.5))
    big = ring(c, "SF3_BannerCoil", M["red"], 1.2, 0.18)
    big.location, big.rotation_euler = (7.0, 13.95, 10.5), (math.radians(90), 0, 0)
    for k, x in enumerate((-3.4, -2.0)):
        cyl(c, "SF3_Pole%d" % k, M["pole"], 0.05, 11.0, (x, 7.0 + k, 5.5), seg=8)
        box(c, "SF3_Flag%d" % k, M["banner"], (1.6, 0.02, 1.0), (x + 0.82, 7.0 + k, 10.4), rot=(0, 0, 8))
    # The sun high behind him, towards us: his front in shade; the crown,
    # the shoulder boards and the gloves' backs catching it.
    _sun(c, "SF3_Sun", (0.2, -0.6, -0.78), 2.2, _srgb(255, 236, 200))
    _camera(c, sc, (-0.05, -0.95, 1.12), (0.02, 0.4, 1.78), 28.0, roll=-5)
    toon(_mats_of(c.objects), _srgb(110, 106, 132), step=0.5)
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 4. Aid workers. Reporters. A downed helicopter crew. Forty-one names. --
# midday on a dusty road at a town's edge: a file of captives, plain
# clothes and bare heads, marched to an army truck by an armed escort
# walking with them; smoke on the hills where the helicopter came down.

# The soldier's parts (low_poly_soldier.glb), by what they are on him.
SOLDIER_PARTS = {"Soldier_Material_001": "clothes", "Soldier_Material_002": "trousers",
                 "Soldier_Material_003": "vest", "Soldier_Material_004": "hair"}


def _person(c, k, at, yaw, clip, dress=None, part=0.25, armed=False):
    """A man on the soldier's model: armed and in his uniform, or a
    captive with the rifle gone and `dress` ({vest, clothes, hair}: sRGB)
    for his own clothes. Returns the rig and a function giving a bone's
    world position, to hang props on his hands."""
    rig, objs = _unit(c, SOLDIER_GLB, k, at, yaw, 1.0, clip, part)
    for o in objs:
        base = o.name.rsplit(".U", 1)[0]
        if base.startswith("M4"):
            o.hide_render = o.hide_viewport = not armed
        what = SOLDIER_PARTS.get(base)
        if dress and what == "hair" and o.type == "MESH":
            # A captive has no helmet.
            o.hide_render = o.hide_viewport = True
        elif dress and what and o.type == "MESH":
            rgb = dress.get(what) or tuple(int(v * 0.8) for v in dress["clothes"])
            m = _mat("SF4_%s_%d" % (what, k), _srgb(*rgb))
            o.material_slots[0].material = m
    W = Matrix.LocRotScale(rig.location, rig.rotation_euler, rig.scale)

    def bone(name):
        rig.users_scene[0].view_layers[0].depsgraph.update()
        return W @ rig.pose.bones[name].head
    if dress:
        # The helmet is in the uniform's mesh: a bare head over it, his
        # hair on top.
        top = W @ rig.pose.bones["head_09"].tail
        neck = W @ rig.pose.bones["head_09"].head
        mid = neck.lerp(top, 0.55)
        ball(c, "SF4_Head%d" % k, _mat("SF4_Skin", _srgb(200, 150, 112)), 0.15, mid, scale=(0.95, 1.0, 1.15))
        ball(c, "SF4_Hair%d" % k, _mat("SF4_Hair%d" % k, _srgb(*dress["hair"])), 0.158,
             mid + Vector((0, 0, 0.045)), scale=(0.97, 1.02, 0.85))
    return rig, bone


def _truck(c, M, at, yaw):
    """A canvas-backed army lorry, its tailgate down towards the file."""
    root = bpy.data.objects.new("SF4_Truck", None)
    c.objects.link(root)
    root.location, root.rotation_euler = at, (0, 0, math.radians(yaw))
    parts = [
        box(c, "SF4_TruckChassis", M["truck"], (6.4, 2.3, 0.5), (0, 0, 1.0)),
        box(c, "SF4_TruckBed", M["truck"], (4.2, 2.4, 0.3), (-1.0, 0, 1.4)),
        box(c, "SF4_TruckCab", M["truck"], (1.8, 2.3, 1.7), (2.3, 0, 2.1), bevel=0.08),
        box(c, "SF4_TruckGlass", M["glass"], (0.05, 1.9, 0.6), (3.22, 0, 2.5)),
        box(c, "SF4_TruckCanvas", M["canvas"], (4.2, 2.5, 1.9), (-1.0, 0, 2.5), bevel=0.25),
        box(c, "SF4_TruckGate", M["truck"], (0.12, 2.3, 0.7), (-3.2, 0, 1.15), rot=(0, 70, 0)),
        box(c, "SF4_TruckHold", M["window"], (0.05, 2.0, 1.5), (-3.12, 0, 2.3)),
    ]
    for i, (x, s) in enumerate(((2.2, 1), (2.2, -1), (-1.6, 1), (-1.6, -1), (-2.8, 1), (-2.8, -1))):
        parts.append(cyl(c, "SF4_Wheel%d" % i, M["tyre"], 0.55, 0.4, (x, s * 1.15, 0.55), rot=(90, 0, 0), seg=16))
    for p in parts:
        p.parent = root
    return root


def build_intro_04():
    sc, c = _scene("Intro_04")
    _world(sc, "SF4_World", (_srgb(226, 214, 190), _srgb(120, 160, 206)), _srgb(96, 92, 100))
    M = dict(
        road=_mat("SF4_Road", _srgb(200, 170, 124)),
        wall=_mat("SF4_Wall", _srgb(214, 186, 146)),
        wall2=_mat("SF4_Wall2", _srgb(190, 158, 118)),
        window=_mat("SF4_Window", _srgb(40, 34, 30)),
        truck=_mat("SF4_Truck", _srgb(120, 116, 84)),
        canvas=_mat("SF4_Canvas", _srgb(146, 138, 100)),
        glass=_mat("SF4_Glass", _srgb(70, 84, 96)),
        tyre=_mat("SF4_Tyre", _srgb(34, 32, 30)),
        smoke=_mat("SF4_Smoke", _srgb(70, 66, 66)),
        hill=_mat("SF4_Hill", _srgb(186, 150, 110)),
    )
    box(c, "SF4_Road", M["road"], (300, 300, 0.2), (0, 100, -0.1))
    # The town's edge behind: flat-roofed houses, a wall with a gate.
    for i, (x, y, w, h, d) in enumerate(((-16, 14, 8, 5.5, 6), (-7, 16, 6, 7.5, 6), (2, 15, 9, 4.5, 6),
                                         (12, 17, 7, 6.5, 6), (20, 14, 8, 5.0, 6))):
        box(c, "SF4_House%d" % i, (M["wall"], M["wall2"])[i % 2], (w, d, h), (x, y + d / 2, h / 2))
        for j in range(int(w // 2.5)):
            box(c, "SF4_HouseWin%d_%d" % (i, j), M["window"], (0.8, 0.2, 1.1),
                (x - w / 2 + 1.4 + j * 2.5, y - 0.05, h * 0.6))
    box(c, "SF4_Wall", M["wall2"], (40, 0.5, 2.2), (0, 10.5, 1.1))
    # Hills far off, and on them the smoke of the helicopter that came down.
    for i, (x, y, r) in enumerate(((-120, 420, 90), (-10, 470, 120), (130, 430, 80))):
        ball(c, "SF4_Hill%d" % i, M["hill"], r, (x, y, -r * 0.62), scale=(1.6, 1.0, 1.0), sub=3)
    rng = random.Random(4)
    for i in range(14):
        t = i / 13
        ball(c, "SF4_Smoke%d" % i, M["smoke"], 6 + 14 * t,
             (40 + 30 * t + rng.uniform(-4, 4), 400 - 20 * t, 30 + 140 * t ** 0.8), sub=2).visible_shadow = False
    _truck(c, M, (9.5, 1.2, 0.0), 0.0)
    # The file, walking right to the truck: plain clothes, bare heads.
    walk = "Walk_Unarmed"
    for k, (x, dress) in enumerate(((3.0, ((236, 232, 220), (150, 180, 210), (110, 70, 40))),
                                    (1.2, ((176, 156, 112), (220, 216, 200), (40, 32, 28))),
                                    (-0.6, ((150, 158, 136), (150, 158, 136), (176, 140, 90))),
                                    (-2.4, ((180, 90, 60), (90, 90, 100), (60, 40, 30))),
                                    (-4.2, ((230, 230, 220), (120, 140, 120), (30, 28, 26))),
                                    (-6.0, ((90, 110, 150), (200, 190, 170), (120, 90, 50))),
                                    (-7.8, ((200, 180, 140), (110, 100, 90), (50, 40, 30))))):
        _person(c, 40 + k, (x, 0.7, 0.0), 90.0, walk, dict(vest=dress[0], clothes=dress[1], hair=dress[2]),
                part=(0.15 + 0.31 * k) % 1.0)
    # The escort, armed, walking with the file on our side of it and one on
    # the far side; one near us halted, his rifle on them; one at the truck.
    for k, (x, y) in enumerate(((2.1, -0.8), (-1.5, -0.9), (-5.1, -0.8), (0.3, 2.1), (-3.3, 2.0))):
        _person(c, 50 + k, (x, y, 0.0), 90.0, "Walk", part=(0.4 + 0.37 * k) % 1.0, armed=True)
    _person(c, 56, (-1.8, -3.6, 0.0), 65.0, "Aim", part=0.5, armed=True)
    _person(c, 57, (5.9, -1.3, 0.0), 120.0, "Order", armed=True)
    # Noon, from high on the right: short hard shadows.
    _sun(c, "SF4_Sun", (-0.45, 0.6, -0.65), 2.6, _srgb(255, 244, 222))
    _camera(c, sc, (-0.4, -9.0, 1.4), (0.9, 0.0, 1.5), 30.0, roll=0)
    toon(_mats_of(c.objects), _srgb(120, 112, 128), step=0.5)
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 5. Governments expressed concern. No one came. -- a conference hall in
# grey daylight, down the length of a long table: chairs on both sides,
# nearly all of them empty, the microphones off, three diplomats at the
# far end; the light in cold stripes through tall windows on the right.

TABLE_L = 14.0           # along +Y, the camera at its near end
SEATS = 8                # a side


def _chair(c, M, name, at, face, askew=0.0):
    """A conference chair at `at`, its front towards `face` (+1 east, -1
    west), turned `askew` degrees, pulled out as it was left."""
    root = bpy.data.objects.new(name, None)
    c.objects.link(root)
    root.location = at
    root.rotation_euler = (0, 0, math.radians((90 if face > 0 else -90) + askew))
    parts = [box(c, name + "Seat", M["chair"], (0.5, 0.5, 0.08), (0, 0, 0.46), bevel=0.02),
             box(c, name + "Back", M["chair"], (0.5, 0.07, 0.6), (0, 0.24, 0.82), bevel=0.02),
             cyl(c, name + "Leg", M["metal"], 0.03, 0.42, (0, 0, 0.21), seg=8),
             cyl(c, name + "Foot", M["metal"], 0.25, 0.03, (0, 0, 0.015), seg=10)]
    for p in parts:
        p.parent = root
    return root


def _place(c, M, name, x, y, side, occupied):
    """A seat's things on the table: the name plate, blank; the microphone
    on its gooseneck, its light off; a glass; papers if it is taken."""
    edge = x - side * 0.55
    box(c, name + "Plate", M["plate"], (0.04, 0.26, 0.09), (edge, y, 0.80), rot=(0, side * -12, 0))
    cyl(c, name + "MicBase", M["metal"], 0.06, 0.03, (edge + side * 0.12, y + 0.22, 0.765), seg=12)
    box(c, name + "MicLight", M["off"], (0.02, 0.03, 0.012), (edge + side * 0.07, y + 0.22, 0.785))
    stem = cyl(c, name + "MicStem", M["metal"], 0.007, 0.26, (edge + side * 0.09, y + 0.22, 0.89), seg=6)
    stem.rotation_euler = (0, math.radians(side * -15), 0)
    ball(c, name + "Mic", M["metal"], 0.022, (edge + side * 0.055, y + 0.22, 1.02), scale=(1, 1, 1.4), sub=2)
    cyl(c, name + "Glass", M["glass"], 0.035, 0.11, (edge + side * 0.25, y - 0.2, 0.81), seg=12)
    if occupied:
        box(c, name + "Papers", M["paper"], (0.3, 0.22, 0.01), (edge + side * 0.25, y + 0.05, 0.765), rot=(0, 0, 8))


def build_intro_05():
    sc, c = _scene("Intro_05")
    _world(sc, "SF5_World", (_srgb(200, 206, 214), _srgb(170, 180, 196)), _srgb(80, 84, 96))
    M = dict(
        floor=_mat("SF5_Carpet", _srgb(84, 96, 118)),
        wall=_mat("SF5_Wall", _srgb(196, 192, 182)),
        panel=_mat("SF5_Panel", _srgb(120, 92, 66)),
        table=_mat("SF5_Table", _srgb(110, 78, 52)),
        cloth=_mat("SF5_Baize", _srgb(70, 96, 82)),
        chair=_mat("SF5_Chair", _srgb(52, 52, 58)),
        metal=_mat("SF5_Metal", _srgb(150, 150, 156)),
        off=_mat("SF5_MicOff", _srgb(70, 20, 20)),
        plate=_mat("SF5_Plate", _srgb(240, 238, 230)),
        glass=_mat("SF5_Glass", _srgb(190, 210, 216)),
        paper=_mat("SF5_Paper", _srgb(244, 242, 236)),
        emblem=_mat("SF5_Emblem", _srgb(90, 130, 170)),
        lamp=_mat("SF5_Lamp", _srgb(236, 240, 244), flat=True),
        sky=_mat("SF5_Window", _srgb(214, 222, 232), flat=True),
    )
    L = TABLE_L
    # Floor and ceiling end at the walls: past the window wall the ceiling
    # would shade the windows from the sun.
    box(c, "SF5_Floor", M["floor"], (11, L + 10, 0.1), (0, L / 2 - 1, -0.05))
    box(c, "SF5_Ceiling", M["wall"], (11, L + 10, 0.1), (0, L / 2 - 1, 4.6))
    box(c, "SF5_LeftWall", M["wall"], (0.2, L + 10, 4.6), (-5.5, L / 2 - 1, 2.3))
    box(c, "SF5_LeftDado", M["panel"], (0.22, L + 10, 1.1), (-5.48, L / 2 - 1, 0.55))
    # The end wall: wood panelling, a large plain emblem -- a ring and a
    # disc, no one's arms in particular.
    box(c, "SF5_EndWall", M["panel"], (14, 0.2, 4.6), (0, L + 1.5, 2.3))
    _annulus(c, "SF5_EmblemRing", M["emblem"], (0, L + 1.38, 2.9), 0.75, 0.12).rotation_euler = (math.radians(90), 0, 0)
    cyl(c, "SF5_EmblemDisc", M["emblem"], 0.45, 0.04, (0, L + 1.38, 2.9), rot=(90, 0, 0), seg=32)
    # The right wall: tall windows between piers, the sky pale behind.
    for i in range(9):
        y = -2.0 + i * 2.2
        box(c, "SF5_Pier%d" % i, M["wall"], (0.4, 0.9, 4.6), (5.5, y, 2.3))
    box(c, "SF5_Sill", M["wall"], (0.4, L + 10, 0.9), (5.5, L / 2 - 1, 0.45))
    box(c, "SF5_Lintel", M["wall"], (0.4, L + 10, 0.6), (5.5, L / 2 - 1, 4.3))
    box(c, "SF5_Sky", M["sky"], (0.1, L + 30, 8), (14.0, L / 2, 3.0)).visible_shadow = False
    # The table, its green baize, the chairs: eight a side, all but three
    # empty, several pulled out and left askew.
    box(c, "SF5_Table", M["table"], (2.2, L, 0.06), (0, L / 2, 0.72))
    box(c, "SF5_Baize", M["cloth"], (2.24, L + 0.04, 0.012), (0, L / 2, 0.756))
    box(c, "SF5_Skirt", M["table"], (2.0, L - 0.4, 0.6), (0, L / 2, 0.4))
    taken = {(-1, 6), (-1, 7), (1, 7)}
    askew = {(-1, 0): 18.0, (1, 1): -24.0, (-1, 3): -12.0, (1, 4): 30.0, (1, 2): 8.0}
    for side in (-1, 1):
        for i in range(SEATS):
            y = 0.9 + i * (L - 1.8) / (SEATS - 1)
            pulled = 0.25 if (side, i) in askew else 0.0
            x = side * (1.55 + pulled)
            _chair(c, M, "SF5_Chair%d_%d" % (side, i), (x, y, 0.0), -side, askew.get((side, i), 0.0))
            _place(c, M, "SF5_Seat%d_%d_" % (side, i), side * 1.1, y, side, (side, i) in taken)
            if (side, i) in taken:
                _person(c, 60 + i + (side > 0) * 10, (side * 1.5, y, 0.0), -90.0 * side, "Sit",
                        dict(vest=(232, 232, 228), clothes=(48, 50, 58), trousers=(40, 42, 50),
                             hair=(70 + 40 * i, 60 + 30 * i, 50 + 20 * i)), part=0.5)
    # The ceiling's lamps, off in daylight.
    for i in range(5):
        cyl(c, "SF5_Lamp%d" % i, M["wall"], 0.35, 0.05, (0, 1.0 + i * 3.0, 4.52), seg=24)
    # The room's shell casts no shadow: only the piers between the windows
    # do, striping the table and the floor.
    for o in c.objects:
        if o.name.startswith(("SF5_Floor", "SF5_Ceiling", "SF5_LeftWall", "SF5_LeftDado", "SF5_EndWall",
                              "SF5_Sill", "SF5_Lintel", "SF5_Lamp", "SF5_Emblem")):
            o.visible_shadow = False
    # Overcast daylight through the windows, from the right and a little
    # ahead: cold, the piers striping the table.
    # Low enough (some 22 degrees) to reach the table under the lintels,
    # and so strong: a diffuse surface gives back strength x cos / pi, and
    # the toon step is at 0.5.
    _sun(c, "SF5_Daylight", (-0.85, 0.2, -0.38), 6.0, _srgb(220, 230, 244), angle=2.0)
    _camera(c, sc, (0.0, -1.6, 1.42), (0.0, L, 0.9), 30.0)
    toon(_mats_of(c.objects), _srgb(112, 118, 140), step=0.5)
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 6. Someone had insured those forty-one lives. And someone had to pay. --
# Arden Mutual, a high office at sunset: on the desk before us the folder
# marked 41, the telephone, its cord running off to Ms. Everly, who stands
# at the window with the receiver at her ear, her back half to us, the
# city below; the low sun through the blinds in stripes across the desk.

def _text(c, name, mat, body, at, size, rot=(0, 0, 0)):
    """A line of 3D text lying in its XY plane (flat, facing up) at `at`."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body, cu.size, cu.extrude = body, size, 0.0006
    cu.align_x, cu.align_y = "CENTER", "CENTER"
    o = bpy.data.objects.new(name, cu)
    c.objects.link(o)
    o.location, o.rotation_euler = at, [math.radians(a) for a in rot]
    cu.materials.append(mat)
    return o


def _cord(c, mat, pts, name):
    """The phone's cord: a smooth tube through `pts`."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions, cu.bevel_depth, cu.bevel_resolution = "3D", 0.007, 2
    sp = cu.splines.new("NURBS")
    sp.points.add(len(pts) - 1)
    for p, q in zip(sp.points, pts):
        p.co = (*q, 1.0)
    sp.use_endpoint_u, sp.order_u = True, 4
    o = bpy.data.objects.new(name, cu)
    c.objects.link(o)
    cu.materials.append(mat)
    return o


def build_intro_06():
    sc, c = _scene("Intro_06")
    _world(sc, "SF6_World", (_srgb(250, 170, 110), _srgb(90, 80, 130)), _srgb(70, 64, 80))
    M = dict(
        floor=_mat("SF6_Carpet", _srgb(92, 70, 64)),
        wall=_mat("SF6_Wall", _srgb(200, 190, 172)),
        wood=_mat("SF6_Wood", _srgb(96, 60, 40)),
        desk=_mat("SF6_Desk", _srgb(70, 44, 30)),
        leather=_mat("SF6_Leather", _srgb(40, 60, 46)),
        folder=_mat("SF6_Folder", _srgb(214, 180, 112)),
        # The folder's label and its number read whatever the light.
        label=_mat("SF6_Label", _srgb(244, 240, 228), flat=True),
        ink=_mat("SF6_Ink", _srgb(24, 22, 22)),
        stamp=_mat("SF6_Stamp", _srgb(176, 34, 30)),
        phone=_mat("SF6_Phone", _srgb(30, 30, 32)),
        brass=_mat("SF6_Brass", _srgb(196, 160, 80)),
        shade=_mat("SF6_LampShade", _srgb(40, 110, 70)),
        glow=_mat("SF6_LampGlow", _srgb(255, 230, 170), flat=True),
        slat=_mat("SF6_Slat", _srgb(214, 206, 190)),
        tower=_mat("SF6_Tower", _srgb(96, 90, 118)),
        tower2=_mat("SF6_Tower2", _srgb(120, 108, 130)),
        lit=_mat("SF6_Lit", _srgb(255, 214, 140), flat=True),
        frame=_mat("SF6_Frame", _srgb(60, 56, 58)),
        books=_mat("SF6_Books", _srgb(120, 40, 36)),
    )
    box(c, "SF6_Floor", M["floor"], (8, 8, 0.1), (0, 0, -0.05))
    box(c, "SF6_LeftWall", M["wall"], (0.15, 8, 3.2), (-2.6, 0, 1.6))
    # Shelves of ledgers on the left wall.
    for i in range(4):
        box(c, "SF6_Shelf%d" % i, M["wood"], (0.35, 2.4, 0.04), (-2.35, 0.6, 0.6 + i * 0.5))
        box(c, "SF6_Ledgers%d" % i, M["books"], (0.28, 2.2, 0.32), (-2.36, 0.6, 0.78 + i * 0.5))
    # The window wall: a long window, the blinds half down, the city below.
    W_Y = 2.4
    box(c, "SF6_Sill", M["wall"], (5.2, 0.3, 0.8), (0.0, W_Y, 0.4))
    box(c, "SF6_Head", M["wall"], (5.2, 0.3, 0.4), (0.0, W_Y, 3.0))
    for i, x in enumerate((-2.55, -0.85, 0.85, 2.55)):
        box(c, "SF6_Mullion%d" % i, M["frame"], (0.12, 0.2, 2.0), (x, W_Y, 1.8))
    # Down past her shoulders, so that the low sun comes through them in
    # stripes onto the desk.
    for i in range(24):
        box(c, "SF6_Slat%d" % i, M["slat"], (5.0, 0.06, 0.025), (0.0, W_Y - 0.18, 2.75 - i * 0.075), rot=(-20, 0, 0))
    rng = random.Random(6)
    for i in range(26):
        x = rng.uniform(-260, 260)
        y = rng.uniform(80, 420)
        h = rng.uniform(40, 160)
        w = rng.uniform(18, 40)
        box(c, "SF6_Tower%d" % i, (M["tower"], M["tower2"])[i % 2], (w, w, h), (x, y, h / 2 - 60))
        for j in range(int(h / 14)):
            if rng.random() < 0.45:
                box(c, "SF6_Lit%d_%d" % (i, j), M["lit"], (w * 0.3, 0.5, 2.0),
                    (x + rng.uniform(-w / 3, w / 3), y - w / 2 - 0.3, j * 14 + 5 - 60))
    # The desk, its leather top, the folder marked 41 nearest us, the
    # telephone, the lamp, a pen.
    box(c, "SF6_Desk", M["desk"], (1.8, 0.9, 0.06), (0.1, 0.0, 0.75))
    box(c, "SF6_DeskBody", M["desk"], (1.7, 0.8, 0.7), (0.1, 0.05, 0.37))
    box(c, "SF6_Blotter", M["leather"], (0.9, 0.55, 0.008), (0.05, -0.02, 0.784))
    fx, fy = -0.12, -0.18
    box(c, "SF6_Folder", M["folder"], (0.34, 0.26, 0.02), (fx, fy, 0.795), rot=(0, 0, -8))
    box(c, "SF6_FolderTab", M["folder"], (0.1, 0.03, 0.012), (fx - 0.08, fy + 0.14, 0.796), rot=(0, 0, -8))
    box(c, "SF6_FolderLabel", M["label"], (0.16, 0.08, 0.004), (fx, fy, 0.806), rot=(0, 0, -8))
    _text(c, "SF6_41", _mat("SF6_LabelInk", _srgb(24, 22, 22), flat=True), "41", (fx, fy, 0.809), 0.075,
          rot=(0, 0, -8))
    box(c, "SF6_Stamp", M["stamp"], (0.12, 0.012, 0.002), (fx + 0.07, fy - 0.08, 0.806), rot=(0, 0, 14))
    px, py = 0.6, 0.1
    box(c, "SF6_PhoneBase", M["phone"], (0.2, 0.22, 0.07), (px, py, 0.82), bevel=0.02)
    box(c, "SF6_PhoneCradle", M["phone"], (0.18, 0.06, 0.03), (px, py + 0.05, 0.87))
    cyl(c, "SF6_PhoneDial", M["brass"], 0.05, 0.01, (px, py - 0.04, 0.86), seg=16)
    cyl(c, "SF6_LampStem", M["brass"], 0.012, 0.35, (-0.6, 0.25, 0.95), seg=8)
    cyl(c, "SF6_LampBase", M["brass"], 0.07, 0.02, (-0.6, 0.25, 0.79), seg=16)
    lamp = cyl(c, "SF6_LampShade", M["shade"], 0.045, 0.24, (-0.6, 0.18, 1.12), rot=(0, 90, 0), r2=0.045, seg=16)
    ball(c, "SF6_LampBulb", M["glow"], 0.04, (-0.6, 0.18, 1.08)).visible_shadow = False
    _lamp(c, "SF6_DeskLamp", "POINT", (-0.6, 0.16, 1.05), (0, 0, 0), 25.0, _srgb(255, 220, 160), size=0.05)
    cyl(c, "SF6_Pen", M["ink"], 0.006, 0.14, (0.22, -0.2, 0.795), rot=(0, 90, 30), seg=8)
    # Ms. Everly at the window, three-quarters from behind, the receiver at
    # her right ear, the cord down to the telephone.
    yaw = 160.0
    rig, bone = _person(c, 70, (0.75, 1.75, 0.0), yaw, "Listen",
                        dict(vest=(236, 232, 224), clothes=(70, 72, 82), trousers=(62, 64, 74), hair=(130, 70, 40)))
    head = bone("head_09")
    f = math.radians(yaw)
    right = Vector((-math.cos(f), -math.sin(f), 0.0))
    ear = head + Vector((0, 0, 0.12)) + right * 0.14
    rec = box(c, "SF6_Receiver", M["phone"], (0.05, 0.05, 0.22), ear, bevel=0.015)
    rec.rotation_euler = (0, math.radians(15), f)
    _cord(c, M["phone"], [ear - Vector((0, 0, 0.11)), ear + Vector((0.05, -0.3, -0.6)),
                          Vector((px + 0.2, py + 0.6, 0.6)), Vector((px + 0.1, py + 0.1, 0.8))], "SF6_Cord")
    # The sun low over the city, straight in through the blinds; the desk
    # lamp warm.
    _sun(c, "SF6_Sun", (0.15, -1.0, -0.22), 6.0, _srgb(255, 196, 140), angle=0.6)
    _camera(c, sc, (-0.45, -1.5, 1.22), (0.45, 1.6, 1.25), 28.0, roll=1)
    toon(_mats_of(c.objects), _srgb(100, 84, 110), step=0.5)
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 7. "Callahan." -- "I have a contract for you." -- the team's hangar at
# night: Badger under the one lamp at the wall telephone, the receiver at
# his ear; over him on the wall the honey badger, the R.A.T.E.L emblem;
# behind, in the dark, the two pickups and the crews, waiting.

EMBLEM_BLEND = "//ratel_emblem.blend"
EMBLEM_SIZE = 2.6        # metres across on the wall (the relief is 1.18 m)


def _emblem(c, at, size):
    """The R.A.T.E.L emblem (ratel_emblem.blend's relief), appended, stood
    up on the wall facing -Y at `at`, `size` metres across."""
    path = bpy.path.abspath(EMBLEM_BLEND)
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n.startswith("RATEL_")]
    root = bpy.data.objects.new("SF7_Emblem", None)
    c.objects.link(root)
    root.location = at
    root.rotation_euler = (math.radians(90), 0, 0)
    root.scale = (size / 1.18,) * 3
    for o in dst.objects:
        c.objects.link(o)
        o.parent = root
    return root


def build_intro_07():
    sc, c = _scene("Intro_07")
    _world(sc, "SF7_World", _srgb(14, 14, 18), _srgb(26, 26, 34))
    M = dict(
        floor=_mat("SF7_Concrete", _srgb(110, 108, 102)),
        wall=_mat("SF7_Wall", _srgb(120, 124, 120)),
        rib=_mat("SF7_Rib", _srgb(96, 100, 96)),
        steel=_mat("SF7_Steel", _srgb(70, 72, 74)),
        phone=_mat("SF7_Phone", _srgb(40, 40, 40)),
        shade=_mat("SF7_Shade", _srgb(60, 80, 64)),
        glow=_mat("SF7_Glow", _srgb(255, 232, 180), flat=True),
        crate=_mat("SF7_Crate", _srgb(110, 100, 66)),
        drum=_mat("SF7_Drum", _srgb(90, 60, 40)),
        door=_mat("SF7_Night", _srgb(40, 50, 76), flat=True),
    )
    box(c, "SF7_Floor", M["floor"], (30, 20, 0.1), (0, 2, -0.05))
    # The back wall, corrugated; a doorway to the night on the right.
    box(c, "SF7_BackWall", M["wall"], (30, 0.2, 8), (0, 6.1, 4))
    for i in range(60):
        box(c, "SF7_Rib%d" % i, M["rib"], (0.12, 0.08, 8), (-15 + i * 0.5, 5.98, 4))
    box(c, "SF7_Door", M["door"], (3.4, 0.05, 3.6), (7.5, 5.92, 1.8))
    for i in range(5):
        box(c, "SF7_Truss%d" % i, M["steel"], (30, 0.25, 0.35), (0, -2 + i * 2.0, 7.4))
    # The emblem over him, the telephone on the wall at his side.
    _emblem(c, (0.0, 5.86, 3.6), EMBLEM_SIZE)
    box(c, "SF7_WallPhone", M["phone"], (0.24, 0.12, 0.34), (1.45, 5.95, 1.55), bevel=0.02)
    box(c, "SF7_Hook", M["phone"], (0.05, 0.08, 0.14), (1.45, 5.86, 1.62))
    # Badger, fifties, grey crew cut, under the lamp, turned a little to the
    # phone, the receiver at his right ear.
    yaw = -15.0
    _, bone = _person(c, 80, (0.75, 4.95, 0.0), yaw, "Listen",
                      dict(vest=(96, 104, 70), clothes=(92, 96, 70), trousers=(84, 80, 64), hair=(170, 168, 160)))
    head = bone("head_09")
    f = math.radians(yaw)
    right = Vector((-math.cos(f), -math.sin(f), 0.0))
    ear = head + Vector((0, 0, 0.12)) + right * 0.14
    rec = box(c, "SF7_Receiver", M["phone"], (0.05, 0.05, 0.22), ear, bevel=0.015)
    rec.rotation_euler = (0, math.radians(-15), f)
    _cord(c, M["phone"], [ear - Vector((0, 0, 0.11)), ear + Vector((0.15, 0.2, -0.6)),
                          Vector((1.4, 5.7, 0.9)), Vector((1.45, 5.88, 1.42))], "SF7_Cord")
    # The lamp: one industrial shade hanging over him.
    # In front of him enough to light his face, not only the top of his head.
    lamp = Vector((0.6, 3.5, 4.0))
    cyl(c, "SF7_LampWire", M["steel"], 0.01, 3.2, lamp + Vector((0, 0, 1.6)), seg=6)
    cyl(c, "SF7_LampShade", M["shade"], 0.08, 0.3, lamp, r2=0.4, rot=(180, 0, 0), seg=24)
    ball(c, "SF7_LampBulb", M["glow"], 0.07, lamp - Vector((0, 0, 0.14))).visible_shadow = False
    _lamp(c, "SF7_Lamp", "SPOT", lamp - Vector((0, 0, 0.2)), (0.7, 5.0, 1.3), 1800.0, _srgb(255, 220, 160),
          size=0.1, cone=80)
    # A small lamp on the beam, thrown up onto the emblem.
    _lamp(c, "SF7_EmblemLight", "SPOT", (0.0, 3.0, 6.8), (0.0, 5.86, 3.6), 1500.0, _srgb(255, 226, 180),
          size=0.1, cone=45)
    # The pickups behind, in the dark, one either side; the crews by them.
    root, _ = car(c, 0, "olive", (-4.6, 3.6, 0.0), 0.0)
    root.rotation_euler = (0, 0, math.radians(200))
    root.scale = (CAR_SCALE * 1.05,) * 3
    root, _ = car(c, 1, "blue", (5.0, 2.8, 0.0), 0.0)
    root.rotation_euler = (0, 0, math.radians(150))
    root.scale = (CAR_SCALE * 1.05,) * 3
    box(c, "SF7_Crate0", M["crate"], (0.9, 0.7, 0.6), (-2.6, 2.6, 0.3))
    box(c, "SF7_Crate1", M["crate"], (0.7, 0.7, 0.5), (3.2, 1.6, 0.25), rot=(0, 0, 20))
    cyl(c, "SF7_Drum", M["drum"], 0.3, 0.9, (-6.5, 1.6, 0.45), seg=16)
    crew = [((-2.6, 2.6, 0.0), 30.0, "Sit", (60, 70, 60), (60, 50, 40)),
            ((-3.4, 1.6, 0.0), 40.0, "Listen", (110, 100, 80), (40, 30, 24)),
            ((3.2, 1.6, 0.0), -40.0, "Sit", (70, 80, 110), (150, 110, 70)),
            ((3.9, 3.4, 0.0), -20.0, "Order", (80, 84, 66), (30, 26, 24)),
            ((-5.9, 4.6, 0.0), 10.0, "Listen", (90, 84, 70), (110, 70, 40))]
    for k, (at, yw, clip, cloth, hair) in enumerate(crew):
        _person(c, 81 + k, at, yw, clip, dict(vest=cloth, clothes=cloth, trousers=(70, 66, 56), hair=hair),
                part=0.5)
    # Night through the door: a cold rim on the crews and the pickups, the
    # wall and its ribs casting no shadow so that it reaches them.
    for o in c.objects:
        if o.name.startswith(("SF7_BackWall", "SF7_Rib", "SF7_Truss", "SF7_Door")):
            o.visible_shadow = False
    _sun(c, "SF7_Night", (-0.5, -0.6, -0.4), 5.0, _srgb(110, 130, 190))
    _camera(c, sc, (-0.8, -3.2, 1.5), (0.1, 5.0, 2.2), 24.0)
    toon(_mats_of(c.objects), _srgb(44, 44, 60), step=0.5)
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 8. Rapid Assault Team... -- the Chinook over the desert at dawn, flying
# away from us into the sun, its ramp down, the two pickups dark in its hold.

def _dunes(c, M):
    size, step = 6000.0, 15.0
    n = int(size / step)
    bm = bmesh.new()
    vs = []
    for j in range(n + 1):
        row = []
        for i in range(n + 1):
            x, y = -size / 2 + i * step, -size + 600 + j * step
            # Long ridges across the way it flies, broken by noise.
            w = noise.noise(Vector((x * 0.003, y * 0.003, 0.2)))
            h = 22.0 * abs(math.sin(x * 0.006 + y * 0.009 + 2.0 * w))
            h += 10.0 * noise.noise(Vector((x * 0.004, y * 0.004, 2.7)))
            row.append(bm.verts.new((x, y, h)))
        vs.append(row)
    for j in range(n):
        for i in range(n):
            bm.faces.new((vs[j][i], vs[j][i + 1], vs[j + 1][i + 1], vs[j + 1][i]))
    return _obj(c, "SF8_Desert", bm, [M["sand"]], True)


def _haze(m, rgb):
    """The far desert fading to the sky at the horizon."""
    nt = m.node_tree
    emit = nt.nodes["SF_Emit"]
    src = emit.inputs["Color"].links[0].from_socket
    cam = nt.nodes.new("ShaderNodeCameraData")
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value, mr.inputs["From Max"].default_value = HAZE_FROM, HAZE_TO
    nt.links.new(cam.outputs["View Distance"], mr.inputs["Value"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    nt.links.new(mr.outputs["Result"], mix.inputs[0])
    nt.links.new(src, _rgba(mix.inputs, "A"))
    _rgba(mix.inputs, "B").default_value = (*rgb, 1)
    nt.links.new(_rgba(mix.outputs, "Result"), emit.inputs["Color"])


CHINOOK_AT = Vector((0.0, 0.0, 120.0))
CHINOOK_PITCH = 4.0      # nose down, flying
# The ramp as a Chinook flies with it open: level with the hold's floor, not
# down on the ground -- this far through its Ramp.Open clip.
RAMP_LEVEL = 0.55
HAZE_FROM, HAZE_TO = 300.0, 4500.0
# The pickups in the hold, along it (metres from the Chinook's middle, +Y
# aft): the first one deep in, the second's tail at the ramp's hinge.
HOLD = (("olive", -2.4), ("blue", 1.8))


def build_intro_08():
    sc, c = _scene("Intro_08")
    _world(sc, "SF8_World", (_srgb(250, 176, 110), _srgb(78, 98, 150)), _srgb(80, 70, 90))
    M = dict(sand=_mat("SF8_Sand", _srgb(222, 160, 104)),
             sun=_mat("SF8_SunDisc", _srgb(255, 240, 200), flat=True))
    _dunes(c, M)
    objs = _import(CHINOOK_GLB, c, ".SF8")
    rig = next(o for o in objs if o.type == "ARMATURE")
    rig.location = CHINOOK_AT
    rig.rotation_euler = (math.radians(CHINOOK_PITCH), 0, 0)
    rig.scale = (CHINOOK_SCALE,) * 3
    _clip(rig, "Ramp.Open", RAMP_LEVEL)
    W = Matrix.LocRotScale(rig.location, rig.rotation_euler, rig.scale)
    dg = sc.view_layers[0].depsgraph
    dg.update()
    # The hold's floor, felt for down the middle from inside the cabin.
    floor = {}
    for y in (-4.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0):
        p = W @ Vector((0.0, y / CHINOOK_SCALE, 2.2 / CHINOOK_SCALE))
        hit, loc, *_ = sc.ray_cast(dg, p, Vector((0, 0, -1)), distance=4.0)
        floor[y] = round(loc.z - CHINOOK_AT.z, 3) if hit else None
    print("SF8 floor", floor)
    for k, (paint, y) in enumerate(HOLD):
        at = W @ Vector((0.0, y / CHINOOK_SCALE, 0.0))
        z = floor.get(float(round(y))) or floor[0.0] or 0.9
        root, _ = car(c, k, paint, (at.x, at.y, CHINOOK_AT.z + z), 0.0)
        root.rotation_euler = (math.radians(CHINOOK_PITCH), 0, 0)
    # A warm light at the front of the hold, so the pickups stand dark
    # against it.
    _lamp(c, "SF8_HoldLamp", "POINT", W @ Vector((0, -4.6 / CHINOOK_SCALE, 2.0 / CHINOOK_SCALE)),
          (0, 0, 0), 1500.0, _srgb(255, 190, 120), size=0.3)
    # The sun low ahead and a little left, in the frame: the Chinook's
    # back against it, the pickups dark in the hold.
    sun_dir = Vector((0.5, 1.0, -0.15)).normalized()
    _sun(c, "SF8_Sun", sun_dir, 2.6, _srgb(255, 206, 156))
    disc = ball(c, "SF8_SunDisc", M["sun"], 70.0, CHINOOK_AT - sun_dir * 4000, sub=4)
    disc.visible_shadow = False
    # Straight behind, level with the hold's floor, looking up a little:
    # the Chinook against the sky, the horizon low, into the hold over the
    # level ramp.
    _camera(c, sc, (3.0, 34.0, 121.7), (0.0, 0.0, 124.2), 36.0, roll=2)
    toon(_mats_of(c.objects), _srgb(150, 118, 136), step=0.4)
    _haze(M["sand"], _srgb(246, 186, 132))
    ink(sc)
    return sc


# ---------------------------------------------------------------------------
# 1, in 3D. The painted frame 1 (docs/story/paint/intro_01.webp, GPT image
# over Intro_01) made a scene again: the painting's map, taken back onto the
# sheet through Intro_01's camera by tools/story_paint_map.py (the props
# painted out of it), and the props as it painted them -- the mug, the
# loupe, the pencil, the pins and flags, the pickup. The same camera as
# Intro_01, so that a render lies over the painting.

PAINT_MAP = "//../../docs/story/paint/intro_01_map.jpg"
# The topographic sheet that replaces the painting on the briefing table:
# tools/blender/sahrun_map.py prints it from assets/story/sahrun_map.json.
SAHRUN_MAP = "//../../tools/blender/sahrun_map.py"
PAINT_FLAG = "//../../docs/story/paint/intro_01_junta_flag.png"
PAINT_SHEET = (-0.004, 1.0, 0.008, 1.017)   # the painted sheet's u0 u1 v0 v1 (story_paint_map.py's SHEET)


def _image(path):
    im = bpy.data.images.load(bpy.path.abspath(path), check_existing=True)
    if not im.packed_file:
        im.pack()
    return im


def _tex_mat(name, path, flat=False):
    m = _mat(name, (1, 1, 1))
    nt = m.node_tree
    tex = nt.nodes.get("SF_Tex") or nt.nodes.new("ShaderNodeTexImage")
    tex.name, tex.image = "SF_Tex", _image(path)
    tex.extension = "EXTEND"
    nt.links.new(tex.outputs["Color"], _bsdf(m).inputs["Base Color"])
    m["flat"] = flat
    return m


def _wood_mat(name, light, dark):
    """The desk: dark wood, its grain along X."""
    m = _mat(name, light)
    nt = m.node_tree
    tc = nt.nodes.new("ShaderNodeTexCoord")
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.wave_type, wave.bands_direction = "BANDS", "Y"
    wave.inputs["Scale"].default_value = 14.0
    wave.inputs["Distortion"].default_value = 9.0
    wave.inputs["Detail"].default_value = 4.0
    wave.inputs["Detail Scale"].default_value = 2.0
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    e = ramp.color_ramp.elements
    e[0].position, e[0].color = 0.0, (*dark, 1)
    e[1].position, e[1].color = 1.0, (*light, 1)
    # Stretched along the grain.
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.15, 1.0, 1.0)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    nt.links.new(wave.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], _bsdf(m).inputs["Base Color"])
    return m


def _painted_sheet(c):
    """The sheet as the painting has it (a little larger than Intro_01's),
    curled the same, the painting's map on it."""
    u0, u1, v0, v1 = PAINT_SHEET
    nx, ny = 150, 100
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = u0 + (u1 - u0) * i / nx, v0 + (v1 - v0) * j / ny
            curl = 0.045 * max(0.0, (u + v - 1.72) / 0.28) ** 2 \
                + 0.015 * max(0.0, (u - 0.88) / 0.12) ** 2 * max(0.0, (0.2 - v) / 0.2)
            row.append(bm.verts.new(((u - 0.5) * MAP_W, (v - 0.5) * MAP_H, 0.002 + curl)))
        grid.append(row)
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for lp in f.loops:
                u, v = lp.vert.co.x / MAP_W + 0.5, lp.vert.co.y / MAP_H + 0.5
                lp[uvl].uv = ((u - u0) / (u1 - u0), (v - v0) / (v1 - v0))
    return _obj(c, "SF1P_Map", bm, [_tex_mat("SF1P_Map", PAINT_MAP)], smooth=True)


def _lathe(c, name, mat, profile, seg=40):
    """A body of revolution about Z through `profile`'s (r, z) points, from
    the outside bottom round to the inside; an end at r 0 is left open."""
    bm = bmesh.new()
    rings = [[bm.verts.new((r * math.cos(2 * math.pi * i / seg), r * math.sin(2 * math.pi * i / seg), z))
              for i in range(seg)] for r, z in profile]
    for a, b in zip(rings, rings[1:]):
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((a[i], a[j], b[j], b[i]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(c, name, bm, [mat], True)


def _arc_tube(c, name, mat, r, tube, a0, a1, seg=20, sides=10):
    """Part of a torus standing in XZ: radius `r`, angles a0..a1 (degrees,
    0 along +X), its ends capped."""
    bm = bmesh.new()
    rows = []
    for i in range(seg + 1):
        a = math.radians(a0 + (a1 - a0) * i / seg)
        ca, sa = math.cos(a), math.sin(a)
        rows.append([bm.verts.new(((r + tube * math.cos(b)) * ca, tube * math.sin(b), (r + tube * math.cos(b)) * sa))
                     for b in (2 * math.pi * j / sides for j in range(sides))])
    for a, b in zip(rows, rows[1:]):
        for j in range(sides):
            bm.faces.new((a[j], b[j], b[(j + 1) % sides], a[(j + 1) % sides]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    return _obj(c, name, bm, [mat], True)


def _rod(c, name, mat, a, b, r, r2=None, seg=16, smooth=True):
    """A cylinder (or a cone, to `r2`) from `a` to `b`."""
    a, b = Vector(a), Vector(b)
    o = cyl(c, name, mat, r, (b - a).length, (a + b) / 2, r2=r2, seg=seg, smooth=smooth)
    o.rotation_euler = (b - a).to_track_quat("Z", "Y").to_euler()
    return o


def _cloth(c, name, mat, mid, w, h, wave=0.0018, uv=False):
    """A flag's cloth, square to the camera (in XZ), rippling a little."""
    bm = bmesh.new()
    nx, nz = 8, 3
    uvl = bm.loops.layers.uv.new("UVMap") if uv else None
    vs = [[bm.verts.new((-w / 2 + w * i / nx, wave * math.sin(math.pi * 1.6 * i / nx) * i / nx, -h / 2 + h * k / nz))
           for i in range(nx + 1)] for k in range(nz + 1)]
    for k in range(nz):
        for i in range(nx):
            f = bm.faces.new((vs[k][i], vs[k][i + 1], vs[k + 1][i + 1], vs[k + 1][i]))
            if uv:
                for lp in f.loops:
                    lp[uvl].uv = (lp.vert.co.x / w + 0.5, lp.vert.co.z / h + 0.5)
    o = _obj(c, name, bm, [mat], True)
    o.location = mid
    return o


def _pin_flag(c, name, cloth, pin, knob, at, size=1.0, uv=False):
    """A map pin, its cloth at the top, a pale knob on it."""
    h = 0.05 * size
    cyl(c, name + "Pin", pin, 0.0012 * size, h, at + Vector((0, 0, h / 2)), seg=8)
    ball(c, name + "Knob", knob, 0.0022 * size, at + Vector((0, 0, h + 0.001 * size)), sub=2)
    w, t = 0.024 * size, 0.016 * size
    return _cloth(c, name, cloth, at + Vector((w / 2 + 0.0012 * size, 0, h - t / 2 - 0.001 * size)), w, t, uv=uv)


def _glass_mat(name, rgb, alpha):
    """See-through, a little tinted: neither lit nor stepped."""
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    em = nt.nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*rgb, 1)
    mix = nt.nodes.new("ShaderNodeMixShader")
    mix.inputs[0].default_value = alpha
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs["Surface"])
    if hasattr(m, "surface_render_method"):
        m.surface_render_method = "BLENDED"
    return m


# The team on the map: a token for each player, the armoured pickup cast in
# one colour and cut down to its silhouette, on an oval stand -- the first
# player's in the game's olive, the second's in its blue (Level3DBtr.PAINTS:
# the olive turned 150 degrees), shown only with two players (PLAYERS).
# Its length nose to tail, metres -- grown with the sheet, as the pins are
# (PIN_SIZE); each from the landing: x, y and its yaw.
TOKEN = 0.056 * PIN_SIZE
TOKEN_PAINTS = ((0x58, 0x66, 0x36), (54, 64, 102))   # PAINT_OLIVE, and it turned
TOKENS_AT = ((-0.04, 0.02, 160.0), (0.042, -0.02, 146.0))
PLAYERS = "players"      # the scene's property the second token follows


def _token(c, name, mat, at, yaw):
    """A player's token, its nose down -Y at yaw 0 as the glb's: bonnet,
    the cab with its raked screen, the bed with the turret and its gun over
    the cab, four wheels -- all on SF1P_Token<n>, an empty at its stand."""
    k = TOKEN / 0.056
    L, W = TOKEN, 0.03 * k
    root = _empty(c, name, None, at)
    root.rotation_euler = (0, 0, math.radians(yaw))
    sh = 0.003 * k
    stand = cyl(c, name + "Stand", mat, 1.0, sh, (0, 0, sh / 2), seg=48)
    stand.scale = ((W + 0.016 * k) / 2, (L + 0.014 * k) / 2, 1.0)
    parts = [stand]
    r = 0.0068 * k
    for i, (x, y) in enumerate(((-1, -1), (1, -1), (-1, 1), (1, 1))):
        parts.append(cyl(c, "%sWheel%d" % (name, i), mat, r, 0.0058 * k,
                         (x * (W / 2 - 0.0015 * k), y * 0.018 * k, sh + r), rot=(0, 90, 0), seg=16))
    # The hull: its side's outline, nose to tail, drawn across its width.
    z0 = sh + 0.0065 * k
    side = [(-L / 2, z0), (-L / 2, z0 + 0.009 * k), (-L / 2 + 0.015 * k, z0 + 0.011 * k),
            (-L / 2 + 0.023 * k, z0 + 0.019 * k), (-L / 2 + 0.035 * k, z0 + 0.019 * k),
            (-L / 2 + 0.036 * k, z0 + 0.012 * k), (L / 2, z0 + 0.012 * k), (L / 2, z0)]
    bm = bmesh.new()
    face = bm.faces.new([bm.verts.new((-W / 2, y, z)) for y, z in side])
    out = bmesh.ops.extrude_face_region(bm, geom=[face])
    bmesh.ops.translate(bm, vec=(W, 0, 0), verts=[v for v in out["geom"] if isinstance(v, bmesh.types.BMVert)])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.bevel(bm, geom=bm.edges[:], offset=0.0007 * k, segments=1, affect="EDGES")
    parts.append(_obj(c, name + "Hull", bm, [mat]))
    # The turret on a post in the bed, its gun forward over the cab's roof.
    ty, top = 0.016 * k, z0 + 0.024 * k
    parts.append(cyl(c, name + "Post", mat, 0.0035 * k, top - z0 - 0.012 * k,
                     (0, ty, (z0 + 0.012 * k + top) / 2), seg=12))
    parts.append(cyl(c, name + "Turret", mat, 0.006 * k, 0.004 * k, (0, ty, top), seg=16))
    parts.append(_rod(c, name + "Gun", mat, Vector((0, ty, top)), Vector((0, ty - 0.026 * k, top)), 0.0013 * k, seg=8))
    for o in parts:
        o.parent = root
    return root


def _phone(c, M, at, yaw):
    """The desk telephone, a black rotary one of the 1980s: its housing,
    the dial on the sloping front, the handset on its cradle, the coiled
    cord down to the desk and the line cord out the back. Everything hangs
    off one empty, SF1P_Phone, so that it can be moved as one."""
    root = bpy.data.objects.new("SF1P_Phone", None)
    c.objects.link(root)
    root.location, root.rotation_euler = at, (0, 0, math.radians(yaw))
    parts = []
    parts.append(box(c, "SF1P_PhoneFoot", M["phone"], (0.205, 0.225, 0.01), (0, 0, 0.005), bevel=0.003))
    # The housing: a low base, the raised back under the cradle, and the
    # front sloping up from the base's edge to the back, the dial on it.
    # The slope's slab is thick so that no gap shows under it from the side.
    dial = Matrix.Translation((0, -0.05, 0.075)) @ Matrix.Rotation(math.radians(35), 4, "X")
    parts.append(box(c, "SF1P_PhoneBody", M["phone"], (0.2, 0.21, 0.03), (0, 0, 0.025), bevel=0.012))
    parts.append(box(c, "SF1P_PhoneBack", M["phone"], (0.19, 0.1, 0.07), (0, 0.05, 0.075), bevel=0.014))
    slope = box(c, "SF1P_PhoneSlope", M["phone"], (0.18, 0.125, 0.05), (0, 0, 0), bevel=0.008)
    slope.matrix_basis = dial @ Matrix.Translation((0, 0, -0.025))
    parts.append(slope)
    # The cradle: two forks on the top at the back, a chrome plunger in each.
    for s, x in (("L", -0.065), ("R", 0.065)):
        parts.append(box(c, "SF1P_PhoneFork" + s, M["phone"], (0.03, 0.05, 0.03), (x, 0.05, 0.12), bevel=0.008))
        parts.append(box(c, "SF1P_PhonePlunger" + s, M["chrome"], (0.012, 0.014, 0.014), (x, 0.05, 0.135)))
    # The handset across the forks: the earpiece on the left, the
    # mouthpiece on the right, both cups hanging over the housing's sides.
    # It is on a pivot of its own (SF1P_PhoneHandset), which rattles when
    # the telephone rings.
    hs = bpy.data.objects.new("SF1P_PhoneHandset", None)
    c.objects.link(hs)
    hs.empty_display_size = 0.03
    hs.parent, hs.location = root, (0, 0.05, 0.15)
    handset = [_rod(c, "SF1P_PhoneHandle", M["phone"], (-0.088, 0.05, 0.15), (0.088, 0.05, 0.15), 0.012)]
    for s, x in (("Ear", -0.1), ("Mouth", 0.1)):
        handset.append(cyl(c, "SF1P_Phone" + s, M["phone"], 0.03, 0.036, (x, 0.05, 0.134), r2=0.017))
        handset.append(ball(c, "SF1P_Phone" + s + "Neck", M["phone"], 0.0145, (x * 0.9, 0.05, 0.15), sub=2))
    for o in handset:
        o.parent = hs
        o.matrix_parent_inverse = Matrix.Translation((0, -0.05, -0.15))
    # The dial on the front, tilted up to whoever sits at the desk: a cream
    # number plate, the black finger wheel over it with its ten holes, the
    # cream card in the middle and the chrome finger stop.

    def on_dial(o, x, y, z):
        o.matrix_basis = dial @ Matrix.Translation((x, y, z))
        return o

    parts.append(on_dial(cyl(c, "SF1P_PhonePlate", M["card"], 0.045, 0.004, (0, 0, 0), seg=40), 0, 0, 0.0))
    parts.append(on_dial(cyl(c, "SF1P_PhoneWheel", M["phone"], 0.043, 0.004, (0, 0, 0), seg=40), 0, 0, 0.003))
    for k in range(10):
        a = math.radians(-60 - 30 * k)
        parts.append(on_dial(cyl(c, "SF1P_PhoneHole%d" % k, M["card"], 0.0068, 0.0046, (0, 0, 0), seg=12),
                             0.031 * math.cos(a), 0.031 * math.sin(a), 0.0034))
    parts.append(on_dial(cyl(c, "SF1P_PhoneCard", M["card"], 0.015, 0.005, (0, 0, 0), seg=24), 0, 0, 0.004))
    a = math.radians(-35)
    parts.append(on_dial(box(c, "SF1P_PhoneStop", M["chrome"], (0.012, 0.004, 0.006), (0, 0, 0)),
                         0.044 * math.cos(a), 0.044 * math.sin(a), 0.006))
    # The coiled cord: from under the mouthpiece down onto the desk on the
    # right and back into the housing's front corner.
    A, B, C = Vector((0.112, 0.045, 0.118)), Vector((0.2, -0.06, -0.03)), Vector((0.098, -0.095, 0.02))
    pts, turns, n = [], 34, 34 * 8
    for i in range(n + 1):
        u = i / n
        p = (1 - u) ** 2 * A + 2 * (1 - u) * u * B + u * u * C
        d = (2 * (1 - u) * (B - A) + 2 * u * (C - B)).normalized()
        e1 = d.cross(Vector((0, 0, 1)))
        e1 = e1.normalized() if e1.length > 1e-6 else Vector((1, 0, 0))
        e2 = d.cross(e1)
        w = 2 * math.pi * turns * u
        q = p + 0.0055 * (math.cos(w) * e1 + math.sin(w) * e2)
        q.z = max(q.z, 0.0028)
        pts.append(tuple(q))
    coil = _cord(c, M["phone"], pts, "SF1P_PhoneCoil")
    coil.data.bevel_depth = 0.0022
    parts.append(coil)
    # The line cord out of the back, across the desk to its far edge, over
    # it and down to the floor, and away along the floor -- in world terms
    # (the desk's back edge at y 1.0, its top at z 0), brought into the
    # phone's.
    to_local = root.matrix_basis.inverted()
    back = root.matrix_basis @ Vector((-0.02, 0.105, 0.012))
    ex = back.x - 0.12
    world = [back, Vector((back.x - 0.04, back.y + 0.12, 0.003)), Vector((ex, 0.9, 0.003)),
             Vector((ex - 0.01, 0.985, 0.004)), Vector((ex - 0.012, 1.008, -0.004)),
             Vector((ex - 0.014, 1.02, -0.05)), Vector((ex - 0.02, 1.035, -0.3)),
             Vector((ex - 0.03, 1.05, -0.6)), Vector((ex - 0.05, 1.12, HANGAR_FLOOR + 0.004)),
             Vector((ex - 0.12, 1.5, HANGAR_FLOOR + 0.003)), Vector((ex - 0.4, 2.4, HANGAR_FLOOR + 0.003))]
    line = _cord(c, M["phone"], [tuple(to_local @ p) for p in world], "SF1P_PhoneLine")
    line.data.bevel_depth = 0.0025
    parts.append(line)
    for o in parts:
        o.parent = root
    return root


# The briefing table's hangar (docs/story/frames.md): the R.A.T.E.L. hangar
# at night round the table -- an arched aircraft hangar, its section a
# segment of a circle, its length along the camera's view. The table stands
# in it, the floor the table's height below the desk's top (z 0); the big
# door is in the far end, straight across from the table, open on the
# night and the title's world beyond it (_outside), the jeeps out there;
# the emblem on the near end and on the floor. No people.
HANGAR_FLOOR = -0.78
HANGAR_W, HANGAR_RISE = 20.0, 8.0                    # span, height at the crown
HANGAR_Y = (-8.0, 10.0)                              # the near end, the far end (the door's)
HANGAR_DOOR = (8.0, 5.5)                             # width, height, centred on x 0
HANGAR_EMBLEM = 4.0                                  # metres across, on the near end
HANGAR_FLOOR_EMBLEM = 4.0                            # painted on the floor before the door
# The lamp over the middle of the table and the map, its pool straight
# under it: its bulb, the desk's light (SF1P_Lamp) in it, shining down.
TABLE_LAMP = Vector((0.0, 0.0, 1.6))
# The game's paints (Level3DBtr.PAINTS): the first player's olive brought to
# OLIVE's colour, the second's turned by the armoured pickup's blue -- its
# parts from 50 to 80 degrees of hue, saturation over 0.2, 150 degrees on.
PAINT_OLIVE = (0x58, 0x66, 0x36)
PAINT_HUES = (50.0, 80.0, 150.0)
# Beyond the door is the title's world (Level3DSplash3D, src/game3d/ui/
# level3d_splash3d.gd): the intro ends on the title's own shot -- its camera
# out of the door, the jeeps out there against its sun, its rocks and palms
# -- so that the title takes over without a cut (docs/story/frames.md).
# Its numbers are the title's own, in its terms: Godot's metres, y up, the
# camera looking down -z, from TITLE_AT, the title's origin a few metres out
# of the door (_title() turns them into Blender's).
TITLE_AT = Vector((0.0, HANGAR_Y[1] + 3.0, HANGAR_FLOOR))
TITLE_CAMERA_AT, TITLE_TILT = (0.0, 1.0, 0.0), 7.0          # CAMERA_AT, CAMERA_TILT
# The title renders its scene the whole screen big, CAMERA_FOV (34 deg)
# across the height of its frame at FOCUS_ZOOM (1.5) times its rest (960 px
# wide, ASPECT 1024/504: place()); it shows the middle of that render, and
# opens it out to the screen once a game is picked. The intro ends on the
# render whole, which the title then draws back into its frame.
TITLE_HFOV = 2 * math.degrees(math.atan(math.tan(math.radians(34.0) / 2) * 1024 / 504 * 2048 / (960 * 1.5)))
TITLE_JEEPS, TITLE_TOE = ((-2.8, 0.0, -21.0), (2.8, 0.0, -21.0)), 14.0    # JEEPS, JEEP_TOE
TITLE_ROCK_JITTER = 0.22                                                 # ROCK_JITTER
TITLE_ROCKS = [  # ROCKS: [position, radius, seed, squash, turn]
    [(-5.9, 0.0, -30.0), 1.2, 3, 0.75, 20.0], [(-7.0, 0.0, -31.2), 0.75, 7, 0.85, 140.0],
    [(-5.0, 0.0, -28.6), 0.45, 12, 0.8, 70.0], [(-7.5, 0.0, -29.3), 0.3, 21, 0.8, 10.0],
    [(-4.6, 0.0, -31.8), 0.28, 22, 0.9, 200.0], [(-8.2, 0.0, -32.6), 0.35, 23, 0.75, 90.0],
    [(-4.2, 0.0, -29.8), 0.22, 24, 0.85, 300.0],
    [(8.6, 0.0, -30.0), 1.25, 5, 0.7, 200.0], [(10.2, 0.0, -31.4), 0.75, 9, 0.9, 310.0],
    [(7.4, 0.0, -28.6), 0.45, 14, 0.8, 30.0], [(9.3, 0.0, -29.0), 0.3, 25, 0.85, 120.0],
    [(11.2, 0.0, -32.3), 0.33, 26, 0.75, 60.0], [(7.0, 0.0, -30.6), 0.25, 27, 0.9, 250.0],
    [(6.6, 0.0, -28.0), 0.2, 28, 0.8, 170.0],
    # Level3DSplashLanding's SCATTER, round the Chinook's line.
    [(-8.5, 0.0, -53.0), 0.85, 31, 0.7, 40.0], [(-9.6, 0.0, -54.2), 0.45, 32, 0.8, 160.0],
    [(-7.6, 0.0, -51.6), 0.25, 33, 0.85, 280.0], [(-21.0, 0.0, -42.0), 0.7, 34, 0.75, 110.0],
    [(-19.9, 0.0, -43.3), 0.3, 35, 0.8, 20.0], [(-17.0, 0.0, -66.0), 1.0, 36, 0.6, 250.0],
    [(-15.6, 0.0, -64.8), 0.4, 37, 0.85, 75.0], [(-18.4, 0.0, -64.9), 0.28, 38, 0.8, 190.0],
    [(9.8, 0.0, -57.5), 0.9, 39, 0.68, 300.0], [(11.1, 0.0, -56.4), 0.38, 40, 0.85, 130.0],
    [(19.5, 0.0, -38.5), 0.6, 41, 0.75, 220.0], [(20.6, 0.0, -39.6), 0.26, 42, 0.8, 50.0],
    [(20.0, 0.0, -71.0), 0.85, 43, 0.65, 15.0], [(18.7, 0.0, -70.2), 0.32, 44, 0.85, 140.0],
    [(-7.5, 0.0, -46.5), 0.55, 51, 0.75, 60.0], [(-8.4, 0.0, -45.6), 0.22, 52, 0.85, 230.0],
    [(8.5, 0.0, -45.5), 0.5, 53, 0.7, 330.0], [(9.3, 0.0, -46.6), 0.24, 54, 0.8, 100.0],
    [(-12.5, 0.0, -47.0), 0.22, 45, 0.85, 0.0], [(15.5, 0.0, -48.5), 0.25, 46, 0.8, 90.0],
    [(-4.8, 0.0, -73.0), 0.3, 47, 0.8, 200.0], [(6.5, 0.0, -76.0), 0.35, 48, 0.75, 310.0],
    [(26.0, 0.0, -58.0), 0.3, 49, 0.8, 60.0], [(-27.0, 0.0, -52.0), 0.28, 50, 0.85, 170.0],
]
# PALMS: [position, which mesh, turn, scale]; stand-ins for the stage's
# palms, 2.3 m at the level's scale times PALM_SCALE (4).
TITLE_PALMS = [[(-12.8, 0.0, -44.0), 0, 20.0, 1.0], [(-24.0, 0.0, -56.0), 2, 140.0, 0.78],
               [(18.0, 0.0, -48.0), 1, 250.0, 1.05],
               # SCATTER_PALMS
               [(-42.0, 0.0, -80.0), 3, 70.0, 0.8], [(41.0, 0.0, -82.0), 2, 300.0, 0.85]]
# The jeeps' fits as the title shows them (SHOWN_FIT, HIDDEN_FITS and
# Level3DBtr.hide_upgrades): the mortar, what a run starts with, and no
# other launcher, missile or upgrade.
TITLE_JEEP_HIDDEN = ("Launcher", "HeavyLauncher", "HeavyMissile", "StageLauncher", "StageMissile", "Grad", "Tube",
                     "Missile", "Rocket", "Rail", "Up", "Aerial", "Mine")
TITLE_PALM_HEIGHT = 2.3 * 4.0
TITLE_GROUND, TITLE_ROCK = (0.085, 0.036, 0.028), (0.2, 0.09, 0.06)    # GROUND_COLOUR, ROCK_COLOUR
# SKY_SHADER's sun: its radius and how far it is sunk under the horizon
# (radians); its heart and its edge, the glow round it out to 1.75 radii
# (radius, red, green; sRGB 0..255).
TITLE_SUN = (0.4, 0.187)
TITLE_SUN_HEART, TITLE_SUN_EDGE = (253, 227, 6), (246, 58, 1)
TITLE_GLOW = [(1.0, 235, 36), (1.06, 209, 25), (1.13, 146, 8), (1.2, 91, 6), (1.36, 40, 2), (1.55, 8, 0),
              (1.75, 0, 0)]
TITLE_SKY_R = 900.0        # the sky's sphere round the title's camera; the ground's disc inside it
# The night, then the title's dawn: daylight(sc, t) goes from one to the
# other, t 0 to 1, so that the animatic can key it -- the sky (the night's
# horizon and zenith, the stars; the title's sky taking over), the sun's
# light (towards, strength, colour). The title's comes straight at its
# camera, travelling a shade upward (SUN_ELEVATION -1.5), so that every face
# the camera sees is in the dark tone and the jeeps are silhouettes.
# The toon's lit tone is the surface's own colour whatever the light's, so
# what that light reaches -- outside, and the hangar's floor by the door --
# is lit in `lit` (its step's upper colour): moonlight, then the sunrise.
NIGHT = dict(sky=(_srgb(52, 66, 104), _srgb(12, 16, 34)),
             sun=((0.3, -1.0, -0.6), 6.0, _srgb(120, 140, 200)), lit=(0.42, 0.52, 0.8))
DAWN = dict(sun=((0.0, -1.0, math.tan(math.radians(1.5))), 6.0, _srgb(255, 158, 82)), lit=(1.3, 1.0, 0.72))


def _title(x, y, z):
    """A point of the title's (Godot's axes, from its origin) in Blender's."""
    return TITLE_AT + Vector((x, -z, y))


def _title_camera():
    """The title's camera as the intro ends on it: where, looking at, lens."""
    at = _title(*TITLE_CAMERA_AT)
    look = at + Vector((0.0, math.cos(math.radians(TITLE_TILT)), math.sin(math.radians(TITLE_TILT)))) * 10
    return (tuple(at), tuple(look), 18.0 / math.tan(math.radians(TITLE_HFOV) / 2))


def _to_srgb(c):
    return tuple(12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055 for v in c)


def _to_linear(c):
    return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


def _paint_car(objs, paint):
    """The pickup in the game's paint `paint` ("olive" or "blue"), as
    Level3DBtr.paint does it: its olive parts on copies of their materials."""
    import colorsys
    lo, hi, shift = PAINT_HUES
    mats = {s.material for o in objs if o.type == "MESH" for s in o.material_slots if s.material}

    def hsv(m):
        return colorsys.rgb_to_hsv(*_to_srgb(_bsdf(m).inputs["Base Color"].default_value[:3]))

    olive = [m for m in mats if _bsdf(m) and hsv(m)[1] > 0.2 and lo <= hsv(m)[0] * 360 <= hi]
    if not olive:
        return
    n = len(olive)
    base = [sum(hsv(m)[i] for m in olive) / n for i in range(3)]
    to = colorsys.rgb_to_hsv(*(v / 255 for v in PAINT_OLIVE))
    copies = {}
    for m in olive:
        h, sat, v = hsv(m)
        if paint == "blue":
            h = ((h * 360 + shift) % 360) / 360
        else:
            h = (to[0] + h - base[0]) % 1.0
            sat = min(max(to[1] * sat / max(base[1], 0.01), 0.0), 1.0)
            v = min(max(to[2] * v / max(base[2], 0.01), 0.0), 1.0)
        rgb = _to_linear(colorsys.hsv_to_rgb(h, sat, v))
        c = m.copy()
        c.name = m.name.split(".")[0] + "." + paint.capitalize()
        _bsdf(c).inputs["Base Color"].default_value = (*rgb, 1)
        mul = c.node_tree.nodes.get("SF_Mul")
        if mul:
            _rgba(mul.inputs, "B").default_value = (*rgb, 1)
        c.diffuse_color = (*rgb, 1)
        copies[m] = c
    for o in objs:
        if o.type == "MESH":
            for sl in o.material_slots:
                if sl.material in copies:
                    sl.material = copies[sl.material]


def _hangar_z(x):
    """The arch's height over x, as an absolute z."""
    W, H, F = HANGAR_W, HANGAR_RISE, HANGAR_FLOOR
    R = (W * W / 4 + H * H) / (2 * H)
    zc = F + H - R
    return zc + math.sqrt(max(R * R - x * x, 0.0))


def _hangar(c):
    F = HANGAR_FLOOR
    W, H = HANGAR_W, HANGAR_RISE
    y0, y1 = HANGAR_Y
    R = (W * W / 4 + H * H) / (2 * H)
    zc = F + H - R
    M = dict(
        floor=_mat("SF1H_Concrete", _srgb(104, 102, 96)),
        wall=_mat("SF1H_Wall", _srgb(116, 120, 116)),
        rib=_mat("SF1H_Rib", _srgb(92, 96, 92)),
        steel=_mat("SF1H_Steel", _srgb(66, 68, 70)),
        leg=_mat("SF1H_TableLeg", _srgb(60, 36, 22)),
        shade=_mat("SF1H_Shade", _srgb(60, 80, 64)),
        glow=_mat("SF1H_Glow", _srgb(255, 232, 180), flat=True),
        crate=_mat("SF1H_Crate", _srgb(110, 100, 66)),
        drum=_mat("SF1H_Drum", _srgb(90, 60, 40)),
        bench=_mat("SF1H_Bench", _srgb(80, 70, 56)),
    )
    # The table under the desk's top: four legs and an apron.
    for k, (x, y) in enumerate(((-1.38, -0.88), (1.38, -0.88), (-1.38, 0.88), (1.38, 0.88))):
        box(c, "SF1H_TableLeg%d" % k, M["leg"], (0.08, 0.08, -F - 0.06), (x, y, (F - 0.06) / 2))
    box(c, "SF1H_ApronX0", M["leg"], (2.7, 0.04, 0.12), (0, -0.9, -0.12))
    box(c, "SF1H_ApronX1", M["leg"], (2.7, 0.04, 0.12), (0, 0.9, -0.12))
    box(c, "SF1H_ApronY0", M["leg"], (0.04, 1.7, 0.12), (-1.4, 0, -0.12))
    box(c, "SF1H_ApronY1", M["leg"], (0.04, 1.7, 0.12), (1.4, 0, -0.12))
    box(c, "SF1H_Floor", M["floor"], (W + 2, y1 - y0, 0.1), (0, (y0 + y1) / 2, F - 0.05))
    # The vault: one sheet of the circle's segment from floor to floor, its
    # faces turned in; arched ribs along it, closer where the corrugation
    # would show, a heavier steel arch every few metres.
    a0 = math.asin((F - zc) / R)
    seg = 64
    bm = bmesh.new()
    rows = []
    for y in (y0, y1):
        rows.append([bm.verts.new((R * math.cos(a), y, zc + R * math.sin(a)))
                     for a in (a0 + (math.pi - 2 * a0) * k / seg for k in range(seg + 1))])
    for k in range(seg):
        bm.faces.new((rows[0][k], rows[0][k + 1], rows[1][k + 1], rows[1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    for f in bm.faces:
        if f.normal.dot(f.calc_center_median() - Vector((0, f.calc_center_median().y, zc))) > 0:
            f.normal_flip()
    _obj(c, "SF1H_Vault", bm, [M["wall"]], True)
    span = math.degrees(math.pi - 2 * a0)
    n = int((y1 - y0) / 0.5)
    for k in range(n + 1):
        y = y0 + k * (y1 - y0) / n
        heavy = k % 6 == 0
        o = _arc_tube(c, "SF1H_Rib%d" % k, M["steel" if heavy else "rib"], R - (0.12 if heavy else 0.04),
                      0.08 if heavy else 0.03, math.degrees(a0), math.degrees(a0) + span, seg=48, sides=6)
        o.location = (0, y, zc)
    # The ends: upright strips up to the arch -- the near one whole, the
    # far one round the door; the door's frame; the apron and the sky beyond.
    dw, dh = HANGAR_DOOR
    strip = 0.5
    x = -W / 2
    k = 0
    while x < W / 2 - 1e-6:
        xm = x + strip / 2
        top = _hangar_z(min(abs(x), abs(x + strip)))
        for end, y in (("Near", y0), ("Far", y1)):
            lo = F
            if end == "Far" and abs(xm) < dw / 2:
                lo = F + dh
            if top - lo > 0.01:
                box(c, "SF1H_End%s%d" % (end, k), M["wall" if k % 2 else "rib"], (strip, 0.12, top - lo),
                    (xm, y + (0.06 if end == "Far" else -0.06), (lo + top) / 2))
        x += strip
        k += 1
    box(c, "SF1H_DoorPostL", M["steel"], (0.3, 0.4, dh), (-dw / 2 - 0.15, y1 - 0.1, F + dh / 2))
    box(c, "SF1H_DoorPostR", M["steel"], (0.3, 0.4, dh), (dw / 2 + 0.15, y1 - 0.1, F + dh / 2))
    box(c, "SF1H_DoorHead", M["steel"], (dw + 0.6, 0.4, 0.3), (0, y1 - 0.1, F + dh + 0.15))
    _outside(c, M)
    # The emblem big on the near end's blank wall, facing down the hangar,
    # lit from the vault; and painted on the floor before the door, to be
    # read from the table.
    ez = F + 1.0 + HANGAR_EMBLEM / 2
    em = _emblem(c, (0.0, y0 + 0.2, ez), HANGAR_EMBLEM)
    em.name = "SF1H_Emblem"
    em.rotation_euler = (math.radians(90), 0, math.radians(180))
    _lamp(c, "SF1H_EmblemLight", "SPOT", (0.0, y0 + 4.5, F + 6.5), (0.0, y0 + 0.2, ez), 2500.0,
          _srgb(255, 226, 180), size=0.1, cone=50)
    fl = _emblem(c, (0.0, y1 - 4.0, F + 0.004), HANGAR_FLOOR_EMBLEM)
    fl.name = "SF1H_FloorEmblem"
    fl.rotation_euler = (0, 0, 0)
    fl.scale = (HANGAR_FLOOR_EMBLEM / 1.18, HANGAR_FLOOR_EMBLEM / 1.18, 0.004)
    # The lamp over the table: an enamelled pendant shade, open below, on
    # its wire from the vault, over the middle of the table; the desk's light
    # (SF1P_Lamp) is its bulb.
    lamp = TABLE_LAMP
    top = _hangar_z(lamp.x)
    wire_lo = lamp.z + 0.2
    cyl(c, "SF1H_LampWire", M["steel"], 0.005, top - wire_lo, Vector((lamp.x, lamp.y, (top + wire_lo) / 2)), seg=6)
    shade = _lathe(c, "SF1H_LampShade", M["shade"], [(0.24, 0.0), (0.22, 0.03), (0.14, 0.1), (0.06, 0.15),
                                                    (0.045, 0.16), (0.04, 0.155), (0.055, 0.14), (0.13, 0.092),
                                                    (0.21, 0.025), (0.23, 0.0), (0.24, 0.0)], seg=40)
    shade.location = lamp - Vector((0, 0, 0.06))
    cyl(c, "SF1H_LampSocket", M["steel"], 0.03, 0.1, lamp + Vector((0, 0, 0.14)), seg=12)
    bulb = ball(c, "SF1H_LampBulb", M["glow"], 0.045, lamp)
    bulb.visible_shadow = shade.visible_shadow = False
    # Stores along the sides.
    box(c, "SF1H_Crate0", M["crate"], (0.9, 0.7, 0.6), (-7.5, 7.5, F + 0.3))
    box(c, "SF1H_Crate1", M["crate"], (0.7, 0.7, 0.5), (-7.6, 7.6, F + 0.85), rot=(0, 0, 14))
    box(c, "SF1H_Crate2", M["crate"], (1.2, 0.8, 0.7), (8.0, 1.0, F + 0.35), rot=(0, 0, -8))
    for k, (x, y) in enumerate(((-8.4, -2.0), (-8.4, -1.3), (-7.8, -1.7))):
        cyl(c, "SF1H_Drum%d" % k, M["drum"], 0.3, 0.9, (x, y, F + 0.45), seg=16)
    box(c, "SF1H_Bench", M["bench"], (0.8, 3.0, 0.9), (8.6, -3.5, F + 0.45))
    return M


STARS = (12.0, 0.02, 0.55)   # cells a radian across the sky (Voronoi scale), a star's radius in them, the share left dark


def _title_sky_mat(name):
    """The sky round the title's camera: SKY_SHADER's sun and its glow (the
    angle to the sun over its radius, through the ramp SF_Sun), the night's
    sky under it -- graded up from the horizon (SF_Night) with stars, one in
    a cell of the sky's azimuth and elevation, as many as SF_Stars lets
    through -- and the one over the other by SF_Day (0 the night, 1 the
    title's dawn); daylight_drivers() drives the two. In the material, so
    the ink leaves the stars alone."""
    m = _mat(name, (1, 1, 1), flat=True)
    nt = m.node_tree
    if nt.nodes.get("SF_Sun"):
        return m

    def op(kind, a, b=None, vector=False):
        n = nt.nodes.new("ShaderNodeVectorMath" if vector else "ShaderNodeMath")
        n.operation = kind
        for i, v in enumerate((a, b)):
            if v is None:
                continue
            if isinstance(v, (float, tuple)):
                n.inputs[i].default_value = v
            else:
                nt.links.new(v, n.inputs[i])
        return n.outputs[1 if vector and kind == "DOT_PRODUCT" else 0]

    def ramp(name, stops):
        r = nt.nodes.new("ShaderNodeValToRGB")
        r.name = name
        e = r.color_ramp.elements
        while len(e) < len(stops):
            e.new(0.5)
        for el, (pos, rgb) in zip(e, stops):
            el.position, el.color = pos, (*rgb, 1)
        return r

    tc = nt.nodes.new("ShaderNodeTexCoord")
    d = op("NORMALIZE", tc.outputs["Object"], vector=True)
    radius, sink = TITLE_SUN
    sun = (0.0, math.cos(sink), -math.sin(sink))
    r = op("DIVIDE", op("ARCCOSINE", op("MINIMUM", op("DOT_PRODUCT", d, sun, vector=True), 1.0)), radius * 1.75)
    heart, edge = _srgb(*TITLE_SUN_HEART), _srgb(*TITLE_SUN_EDGE)
    stops = [(0.0, heart), (0.47 / 1.75, heart), (0.999 / 1.75, edge)]
    stops += [(min(g / 1.75, 1.0), _srgb(red, green, 0)) for g, red, green in TITLE_GLOW]
    disc = ramp("SF_Sun", stops)
    nt.links.new(r, disc.inputs["Fac"])
    xyz = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(d, xyz.inputs[0])
    night = ramp("SF_Night", [(0.0, NIGHT["sky"][0]), (0.4, NIGHT["sky"][1])])
    nt.links.new(xyz.outputs["Z"], night.inputs["Fac"])
    scale, star_r, dark = STARS
    az, el = op("ARCTAN2", xyz.outputs["X"], xyz.outputs["Y"]), op("ARCSINE", xyz.outputs["Z"])
    uv = nt.nodes.new("ShaderNodeCombineXYZ")
    nt.links.new(az, uv.inputs["X"])
    nt.links.new(el, uv.inputs["Y"])
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.voronoi_dimensions = "2D"
    vor.inputs["Scale"].default_value = scale
    nt.links.new(uv.outputs[0], vor.inputs["Vector"])
    lit = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(vor.outputs["Color"], lit.inputs[0])
    star = op("MULTIPLY", op("LESS_THAN", vor.outputs["Distance"], star_r), op("GREATER_THAN", lit.outputs[0], dark))
    star = op("MULTIPLY", star, op("GREATER_THAN", el, 0.06))     # none down in the horizon's haze
    on = nt.nodes.new("ShaderNodeValue")
    on.name = "SF_Stars"
    star = op("MULTIPLY", star, on.outputs[0])
    starry = nt.nodes.new("ShaderNodeMix")
    starry.data_type = "RGBA"
    nt.links.new(star, starry.inputs[0])
    nt.links.new(night.outputs["Color"], _rgba(starry.inputs, "A"))
    _rgba(starry.inputs, "B").default_value = (0.9, 0.92, 1.0, 1)
    day = nt.nodes.new("ShaderNodeValue")
    day.name = "SF_Day"
    sky = nt.nodes.new("ShaderNodeMix")
    sky.data_type = "RGBA"
    nt.links.new(day.outputs[0], sky.inputs[0])
    nt.links.new(_rgba(starry.outputs, "Result"), _rgba(sky.inputs, "A"))
    nt.links.new(disc.outputs["Color"], _rgba(sky.inputs, "B"))
    nt.links.new(_rgba(sky.outputs, "Result"), _bsdf(m).inputs["Base Color"])
    return m


def _rock(c, name, mat, at, r, seed, squash, turn):
    """One of the title's boulders (its _rock): a faceted ball, its corners
    pushed in and out, squashed and sunk in the ground."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=1, radius=r)
    rnd = random.Random(seed)
    for v in bm.verts:
        v.co *= 1.0 + rnd.uniform(-TITLE_ROCK_JITTER, TITLE_ROCK_JITTER)
    bmesh.ops.scale(bm, vec=(1, 1, squash), verts=bm.verts)
    o = _obj(c, name, bm, [mat])
    o.location = at - Vector((0, 0, r * squash * 0.25))
    o.rotation_euler = (0, 0, math.radians(turn))
    return o


def _palm(c, name, mat, at, height, turn, seed):
    """A stand-in for the stage's palm: a trunk bowed over and a crown of
    fronds, flat strips drooping from its top -- its silhouette on the glow."""
    rnd = random.Random(seed)
    lean = Vector((math.cos(math.radians(turn)), math.sin(math.radians(turn)), 0)) * height * 0.12
    pts = [at + lean * (s * s) + Vector((0, 0, height * s)) for s in (k / 6 for k in range(7))]
    for k in range(6):
        _rod(c, "%sTrunk%d" % (name, k), mat, pts[k], pts[k + 1], 0.3 - 0.022 * k, 0.3 - 0.022 * (k + 1), seg=8)
    top, L = pts[-1], height * 0.42
    bm = bmesh.new()
    for j in range(9):
        a = math.radians(turn + j * 40 + rnd.uniform(-12, 12))
        dr = Vector((math.cos(a), math.sin(a), 0))
        side = dr.cross(Vector((0, 0, 1)))
        lift, droop = rnd.uniform(0.25, 0.45), rnd.uniform(0.8, 1.1)
        row = []
        for i in range(8):
            u = i / 7
            mid = top + dr * (L * u) + Vector((0, 0, L * (lift * u - droop * u * u)))
            w = 0.5 * math.sin(math.pi * min(u * 1.15, 1.0)) + 0.03
            row.append((bm.verts.new(mid - side * w), bm.verts.new(mid + side * w)))
        for i in range(7):
            bm.faces.new((row[i][0], row[i][1], row[i + 1][1], row[i + 1][0]))
    return _obj(c, name + "Crown", bm, [mat])


def _outside(c, M):
    """Beyond the door, the title's world (TITLE_*): its ground out to the
    horizon, its rocks and palms, the two jeeps where it stands them, its
    sky round it all, and the sun's light in by the door (the hangar's shell
    casts its shadow, so it comes in no other way). Everything in it is
    marked "outside", for the light's tint (daylight_drivers)."""
    F = HANGAR_FLOOR
    before = set(c.objects)
    G = dict(ground=_mat("SF1T_Ground", _srgb(*(round(255 * v) for v in TITLE_GROUND))),
             rock=_mat("SF1T_Rock", _srgb(*(round(255 * v) for v in TITLE_ROCK))),
             palm=_mat("SF1T_Palm", _srgb(44, 24, 14)),
             sky=_title_sky_mat("SF1T_Sky"))
    eye = _title(*TITLE_CAMERA_AT)
    # The ground just under the hangar's floor, which hides it indoors.
    cyl(c, "SF1T_Ground", G["ground"], TITLE_SKY_R * 0.8, 0.1, (eye.x, eye.y, F - 0.055), seg=96, smooth=False)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=96, v_segments=48, radius=TITLE_SKY_R)
    sky = _obj(c, "SF1T_Sky", bm, [G["sky"]], True)
    sky.location = eye
    sky.visible_shadow = False
    for k, (at, r, seed, squash, turn) in enumerate(TITLE_ROCKS):
        _rock(c, "SF1T_Rock%d" % k, G["rock"], _title(*at), r, seed, squash, turn)
    for k, (at, kind, turn, scale) in enumerate(TITLE_PALMS):
        _palm(c, "SF1T_Palm%d" % k, G["palm"], _title(*at), TITLE_PALM_HEIGHT * scale, turn, 100 + k)
    # The jeeps at the glb's own scale, facing the camera, each turned out
    # from the middle; the title's own colours, which it does not repaint.
    for k, at in enumerate(TITLE_JEEPS):
        root, objs = car(c, 20 + k, "olive", _title(*at), TITLE_TOE * -math.copysign(1.0, at[0]))
        root.scale = (1.0,) * 3
        for o in objs:
            part = o.name.rsplit(".SF", 1)[0].split("_", 1)[-1]
            o.hide_render = o.hide_viewport = part.startswith(TITLE_JEEP_HIDDEN)
    for o in set(c.objects) - before:
        o["outside"] = True
    _sun(c, "SF1H_Sun", NIGHT["sun"][0], NIGHT["sun"][1], NIGHT["sun"][2])


DAYLIGHT = "daylight"     # the scene's property the world beyond the door follows


def _drive(idb, path, index, sc, expr, prop=None):
    """`idb`'s `path`[`index`] driven by `expr` of t, the scene's DAYLIGHT
    (or `prop`) --
    a simple expression, which Blender evaluates without running Python, so
    it holds with scripts untrusted, while the animatic plays, and renders."""
    fc = idb.driver_add(path, index) if index is not None else idb.driver_add(path)
    d = fc.driver
    d.type = "SCRIPTED"
    for v in list(d.variables):
        d.variables.remove(v)
    v = d.variables.new()
    v.name, v.type = "t", "SINGLE_PROP"
    v.targets[0].id_type = "SCENE"
    v.targets[0].id = sc
    v.targets[0].data_path = '["%s"]' % (prop or DAYLIGHT)
    d.expression = expr
    return fc


def _lerp_expr(a, b):
    return "%.6g + %.6g * t" % (a, b - a)


def _outside_lit(sc):
    """The materials the light beyond the door tints: those of what is
    outside (and the hangar's floor, lit by it in the doorway) and of
    nothing else -- the jeeps' shared with the token on the map stay out."""
    out, inside = set(), set()
    for o in sc.objects:
        if o.type not in ("MESH", "CURVE", "FONT"):
            continue
        mats = {s.material for s in o.material_slots if s.material}
        (out if o.get("outside") else inside).update(mats)
    mats = (out - inside) | {bpy.data.materials["SF1H_Concrete"]}
    return [m for m in mats if m.use_nodes and m.node_tree.nodes.get("SF_Step")]


def daylight_drivers(sc):
    """The world beyond the door, from the night (DAYLIGHT 0) to the title's
    dawn (1), on drivers: the sky (its stars out by halfway, the title's
    sky over the night's), the sun's light, and the lit tone of what it
    reaches. The property is keyable, so the animatic keys it."""
    if DAYLIGHT not in sc:
        sc[DAYLIGHT] = 0.0
    ui = sc.id_properties_ui(DAYLIGHT)
    ui.update(min=0.0, max=1.0, soft_min=0.0, soft_max=1.0, subtype="FACTOR",
              description="Beyond the hangar's door: 0 the night, 1 the title's dawn")
    sky = bpy.data.materials["SF1T_Sky"].node_tree
    _drive(sky, 'nodes["SF_Stars"].outputs[0].default_value', None, sc, "max(0.0, 1.0 - 2.0 * t)")
    _drive(sky, 'nodes["SF_Day"].outputs[0].default_value', None, sc, "t")
    sun = sc.objects["SF1H_Sun"]
    # The sun's turn, Euler to Euler: near enough the direction's between
    # the two.
    eu = [Vector(x["sun"][0]).to_track_quat("-Z", "Y").to_euler() for x in (NIGHT, DAWN)]
    for ch in range(3):
        _drive(sun, "rotation_euler", ch, sc, _lerp_expr(eu[0][ch], eu[1][ch]))
    _drive(sun.data, "energy", None, sc, _lerp_expr(NIGHT["sun"][1], DAWN["sun"][1]))
    for ch in range(3):
        _drive(sun.data, "color", ch, sc, _lerp_expr(NIGHT["sun"][2][ch], DAWN["sun"][2][ch]))
    for m in _outside_lit(sc):
        for ch in range(3):
            _drive(m.node_tree, 'nodes["SF_Step"].color_ramp.elements[1].color', ch, sc,
                   _lerp_expr(NIGHT["lit"][ch], DAWN["lit"][ch]))


def players_drivers(sc):
    """The second player's token shown with two players (PLAYERS, 1 or 2),
    by its rays as the outside's things are."""
    if PLAYERS not in sc:
        sc[PLAYERS] = 1
    sc.id_properties_ui(PLAYERS).update(min=1, max=2, soft_min=1, soft_max=2,
                                        description="Players: the second's token on the map with two")
    for o in sc.objects["SF1P_Token2"].children_recursive:
        if o.type == "MESH":
            _drive(o, "visible_camera", None, sc, "t >= 2", PLAYERS)
            _drive(o, "visible_shadow", None, sc, "t >= 2", PLAYERS)


def daylight(sc, t):
    """DAYLIGHT set to `t`, the drivers brought up to it."""
    sc[DAYLIGHT] = float(t)
    sc.frame_set(sc.frame_current)


# The slider: a panel in the 3D view's sidebar (Story), a text block
# registered on load (when the file's scripts are trusted; without them
# the property is still in Scene > Custom Properties).
STORY_UI = "jackal_story_ui.py"
STORY_UI_SRC = """# The briefing table's controls in the 3D view's sidebar, Story tab
# (written by tools/blender/story_frames.py's install_ui(); registered on load).
import bpy


class SF_PT_story(bpy.types.Panel):
    bl_space_type, bl_region_type = "VIEW_3D", "UI"
    bl_category, bl_label = "Story", "Briefing table"

    @classmethod
    def poll(cls, context):
        return "daylight" in context.scene

    def draw(self, context):
        sc = context.scene
        col = self.layout.column()
        col.prop(sc, '["daylight"]', text="Daylight", slider=True)
        if "players" in sc:
            col.prop(sc, '["players"]', text="Players")
        col.prop(sc, "camera")


if hasattr(bpy.types, "SF_PT_story"):
    bpy.utils.unregister_class(bpy.types.SF_PT_story)
bpy.utils.register_class(SF_PT_story)
"""


def install_ui():
    t = bpy.data.texts.get(STORY_UI) or bpy.data.texts.new(STORY_UI)
    t.from_string(STORY_UI_SRC)
    t.use_module = True
    exec(compile(STORY_UI_SRC, STORY_UI, "exec"), {"__name__": STORY_UI})


def build_intro_01_3d(dawn=0.0):
    sc, c = _scene("Intro_01_3D")
    _world(sc, "SF1_World", _srgb(20, 16, 14), _srgb(36, 30, 28))
    M = dict(
        desk=_wood_mat("SF1P_Desk", _srgb(92, 52, 28), _srgb(58, 32, 18)),
        black=_mat("SF1P_Black", _srgb(26, 24, 24)),
        knob=_mat("SF1P_Knob", _srgb(220, 220, 214)),
        red=_mat("SF1P_Red", _srgb(206, 28, 26), flat=True),
        mug=_mat("SF1P_Mug", _srgb(236, 232, 220)),
        coffee=_mat("SF1P_Coffee", _srgb(58, 34, 20)),
        brass=_mat("SF1P_Brass", _srgb(196, 152, 76)),
        handle=_mat("SF1P_Handle", _srgb(46, 34, 26)),
        lens=_glass_mat("SF1P_Lens", _srgb(200, 222, 226), 0.35),
        pencil=_mat("SF1P_Pencil", _srgb(232, 176, 40)),
        wood=_mat("SF1P_PencilWood", _srgb(226, 190, 140)),
        lead=_mat("SF1P_Lead", _srgb(40, 40, 44)),
        ferrule=_mat("SF1P_Ferrule", _srgb(190, 190, 184)),
        eraser=_mat("SF1P_Eraser", _srgb(226, 140, 140)),
        phone=_mat("SF1P_Phone", _srgb(30, 30, 32)),
        card=_mat("SF1P_DialCard", _srgb(232, 226, 206)),
        chrome=_mat("SF1P_Chrome", _srgb(196, 196, 190)),
        junta=_tex_mat("SF1P_JuntaFlag", PAINT_FLAG, flat=True),
        token1=_mat("SF1P_Token1", _srgb(*TOKEN_PAINTS[0])),
        token2=_mat("SF1P_Token2", _srgb(*TOKEN_PAINTS[1])),
    )
    box(c, "SF1P_Desk", M["desk"], (3.0, 2.0, 0.06), (0, 0, -0.03))
    _painted_sheet(c)
    # The pins: a red flag on each stage, the junta's black one with its
    # coiled snake (cut out of the painting) on the capital.
    for k, (u, v) in enumerate(STAGES[1:6], 1):
        _pin_flag(c, "SF1P_Flag%d" % k, M["red"], M["black"], M["knob"], _uv_world(u, v, 0.002), size=PIN_SIZE)
    _pin_flag(c, "SF1P_Junta", M["junta"], M["black"], M["knob"], _uv_world(*STAGES[6], 0.002), size=1.4 * PIN_SIZE,
              uv=True)
    # The team on the landing: a token a player, the second's shown only
    # with two (PLAYERS).
    land = _uv_world(*STAGES[0], 0.002)
    for n, (x, y, yaw) in enumerate(TOKENS_AT, 1):
        _token(c, "SF1P_Token%d" % n, M["token%d" % n], land + Vector((x, y, 0.0)), yaw)
    # The mug on the sea by the map's left edge, holding it down: a thick
    # lip, coffee in it, the handle to the left.
    mug = _uv_world(0.07, 0.33, 0.002)
    r, h = 0.047, 0.102
    _lathe(c, "SF1P_Mug", M["mug"], [(0.0, 0.0), (r - 0.004, 0.0), (r, 0.004), (r, h - 0.003), (r - 0.003, h),
                                      (r - 0.008, h - 0.002), (r - 0.008, 0.012), (0.0, 0.012)]).location = mug
    cyl(c, "SF1P_Coffee", M["coffee"], r - 0.008, 0.002, mug + Vector((0, 0, h - 0.016)), seg=40)
    _arc_tube(c, "SF1P_MugHandle", M["mug"], 0.03, 0.0075, 100, 260).location = mug + Vector((-r + 0.006, 0, h * 0.52))
    # The loupe lying flat on the empty desert in the south: a brass rim
    # round its glass, its dark handle between brass ends to the right.
    lc = _uv_world(0.5, 0.17, 0.0065)
    d = Vector((math.cos(math.radians(-18)), math.sin(math.radians(-18)), 0))
    rim = _lathe(c, "SF1P_LoupeRim", M["brass"], [(0.050, -0.006), (0.056, -0.006), (0.056, 0.006),
                                                   (0.050, 0.006), (0.050, -0.006)], seg=48)
    glass = cyl(c, "SF1P_LoupeGlass", M["lens"], 0.0505, 0.003, (0, 0, 0), seg=48)
    glass.visible_shadow = False
    for o in (rim, glass):
        o.location = lc
    a = lc + d * 0.056 + Vector((0, 0, 0.0025))
    b = a + d * 0.098 + Vector((0, 0, 0.002))
    _rod(c, "SF1P_LoupeCollar", M["brass"], a, a + d * 0.022, 0.008)
    _rod(c, "SF1P_LoupeHandle", M["handle"], a + d * 0.022, b, 0.0095, 0.011)
    _rod(c, "SF1P_LoupeCap", M["brass"], b, b + d * 0.012, 0.011, 0.009)
    # The pencil across the desert south of the river, its point up the
    # map: a yellow hexagon, the ferrule and the eraser at the near end.
    e = _uv_world(0.57, 0.09, 0.0055)
    t = e + Vector((math.cos(math.radians(28)), math.sin(math.radians(28)), 0)) * 0.19
    ax = (t - e).normalized()
    pr = 0.0045
    _rod(c, "SF1P_Eraser", M["eraser"], e, e + ax * 0.008, pr * 0.95)
    _rod(c, "SF1P_Ferrule", M["ferrule"], e + ax * 0.008, e + ax * 0.02, pr * 1.02)
    _rod(c, "SF1P_Pencil", M["pencil"], e + ax * 0.02, t - ax * 0.02, pr, seg=6, smooth=False)
    _rod(c, "SF1P_PencilWood", M["wood"], t - ax * 0.02, t - ax * 0.005, pr, r2=0.0012, seg=6, smooth=False)
    _rod(c, "SF1P_PencilLead", M["lead"], t - ax * 0.005, t, 0.0012, r2=0.0002, seg=6, smooth=False)
    # The telephone on the sea in the map's top left, clear of the stages:
    # the briefing
    # table's scene opens and closes on it ringing (docs/story/frames.md).
    _phone(c, M, _uv_world(0.085, 0.86, 0.0), 12)
    # The hangar round the table.
    _hangar(c)
    # The lamp over the middle of the table (TABLE_LAMP, hung in _hangar),
    # shining straight down, its pool on the map; a low fill from
    # our side. The flags' cloths are flat colour, red as painted whichever
    # way the light comes.
    _lamp(c, "SF1P_Lamp", "SPOT", TABLE_LAMP, TABLE_LAMP - Vector((0, 0, 1)), 100.0, _srgb(255, 226, 180), size=0.15, cone=110)
    _lamp(c, "SF1P_Fill", "SPOT", Vector((0.1, -0.9, 0.25)) * (MAP_W / 1.2), (0.0, 0.1, 0.03), 6.0 * (MAP_W / 1.2) ** 2, _srgb(255, 236, 210), size=0.2, cone=70)
    # The last shot's camera, out of the door (not the scene's: the
    # animatic cuts to it); then the table's, back far enough to hold the
    # whole sheet, as it held Intro_01's.
    title = _camera(c, sc, *_title_camera())
    title.name = title.data.name = sc.name + "_TitleCamera"
    _camera(c, sc, (0.0, -1.18 * MAP_W / 1.2, 0.78 * MAP_W / 1.2), (0.0, -0.02 * MAP_W / 1.2, 0.0), 40.0)
    # The intro played on it: the cards, the telephone, the moving camera
    # (the scene's camera; the table's and the door's stay for stills).
    animatic = build_intro_animatic(c, sc)
    toon(_mats_of(c.objects), _srgb(70, 62, 70), step=0.18)
    ink(sc)
    daylight_drivers(sc)
    players_drivers(sc)
    daylight(sc, dawn)
    intro_dawn(sc)
    install_ui()
    sc.camera = animatic
    sc.frame_set(1)
    # The painting's sheet takes the topographic print and the team's pencil
    # (the images as last printed; sahrun_map.build_print() prints them anew).
    sm = {"__name__": "sahrun_map"}
    path = bpy.path.abspath(SAHRUN_MAP)
    exec(compile(open(path, encoding="utf-8").read(), path, "exec"), sm)
    sm["apply_to_sheet"]()
    return sc


# ---------------------------------------------------------------------------
# The intro on the briefing table, as an animatic (docs/story/frames.md,
# "Вступление — досье"): its eight cards in the order and at the places the
# table there gives, one camera going from shot to shot, the telephone
# ringing at the start and the dawn at the end. Stand-ins: the photographs
# painted so far (docs/story/paint/2, 3, 4) taken to grey, plain grey with
# their number for the rest; the documents typeset roughly; every caption
# in a stand-in marker font that pops up whole (its drawing is a step of its
# own). Timings in seconds (FPS), the cards' starts in INTRO_CARDS.

FPS = 24
INTRO_END = 68.0
# Ink Free is Windows' own -- a stand-in for the marker, not for the game.
MARKER_FONT = r"C:\Windows\Fonts\Inkfree.ttf"
PRINT_FONT = r"C:\Windows\Fonts\bahnschrift.ttf"
PAINT_PHOTOS = {2: "//../../docs/story/paint/2.png", 3: "//../../docs/story/paint/3.png",
                5: "//../../docs/story/paint/4.png"}
INTRO_CARDS = ((0.0, "1 Sahrun. 1987."), (7.0, "2 Coup"), (15.0, "3 Vassar"), (22.0, "4 Forty-one"),
               (30.0, "5 Checkpoint"), (37.0, "6 No one's coming"), (44.0, "7 Contract"), (52.0, "8 The team"))
HIDE_Z = 4.0             # where a card waits before it falls, over the lamp, out of every shot
# A photograph: its width, the white border, the strip under the picture
# for the caption; the picture 16:9.
PHOTO_W, PHOTO_BORDER, PHOTO_STRIP = 0.40, 0.018, 0.075
PAPER_T = 0.0006
ID_STEP = 0.001          # the passport photographs' pitch in the pile: each is 0.9 mm with its face
# Where everything lands, x y on the desk (the sheet 2.6 x 1.73 round 0)
# and the yaw: clear of the pins, the mug, the loupe, the pencil and the
# pickup's token, and off the sheet's curled corners.
LAND = dict(folder=(0.92, -0.36, -6), tanks=(0.66, 0.40, -8), vassar=(0.57, 0.27, 7), ids=(0.30, -0.36, 0),
            hostages=(-0.28, -0.49, 4), clipping=(1.15, 0.1, 14), contract=(0.0, 0.0, -4),
            team=(-0.04, -0.34, 8))
# The camera's keys: (time, where, looking at, lens); a key held twice is a
# hold, the moves between them eased.
_TABLE = ((0.0, -1.18 * MAP_W / 1.2, 0.78 * MAP_W / 1.2), (0.0, -0.02 * MAP_W / 1.2, 0.0), 40.0)
_SHOTS = dict(
    push=((-0.6, -1.75, 0.75), (-0.75, -0.6, 0.0), 36.0),
    right=((1.15, -1.55, 1.25), (0.74, 0.0, 0.0), 34.0),
    tanks=((0.78, -0.2, 0.7), (0.67, 0.39, 0.0), 40.0),
    capital=((0.6, -0.36, 0.75), (0.6, 0.3, 0.0), 40.0),
    ids=((0.06, -0.78, 0.3), (0.31, -0.38, 0.0), 40.0),
    hostages=((-0.31, -1.16, 0.72), (-0.29, -0.47, 0.0), 40.0),
    clipping=((0.78, -0.56, 0.62), (1.12, 0.08, 0.0), 42.0),
    contract=((0.0, -0.36, 1.15), (0.0, 0.0, 0.0), 38.0),
    team=((-0.04, -0.77, 0.55), (-0.04, -0.32, 0.0), 42.0),
    rise=((0.0, -0.25, 1.3), (0.0, 5.0, 1.0), 30.0),
)
INTRO_CAMERA = [(0.0, _TABLE), (6.3, _SHOTS["push"]), (7.6, _SHOTS["right"]), (9.9, _SHOTS["right"]),
                (10.9, _SHOTS["tanks"]), (14.3, _SHOTS["tanks"]),
                (15.6, _SHOTS["capital"]), (21.3, _SHOTS["capital"]), (22.6, _SHOTS["ids"]), (29.3, _SHOTS["ids"]),
                (30.6, _SHOTS["hostages"]), (36.3, _SHOTS["hostages"]), (37.6, _SHOTS["clipping"]),
                (43.3, _SHOTS["clipping"]), (44.6, _SHOTS["contract"]), (51.3, _SHOTS["contract"]),
                (52.6, _SHOTS["team"]), (57.0, _SHOTS["team"]), (60.0, _SHOTS["rise"]), (63.5, _title_camera()),
                (INTRO_END, _title_camera())]
INTRO_DAWN = (58.0, 62.5)        # daylight from 0 to 1 while the camera leaves the table
# The telephone: rings of 0.4 s, two to a ring, three rings.
INTRO_RINGS = ((0.4, 0.8), (1.0, 1.4), (2.6, 3.0), (3.2, 3.6), (4.8, 5.2), (5.4, 5.8))


def _f(t):
    return 1 + round(t * FPS)


def _fcurves(idb):
    ad = idb.animation_data
    if not ad or not ad.action:
        return []
    cb = anim_utils.action_get_channelbag_for_slot(ad.action, ad.action_slot)
    return cb.fcurves if cb else []


def _key(o, t, loc=None, rot=None, scale=None, interp=None, easing="AUTO"):
    """Keys on `o` at `t` (seconds, or a frame as an int)."""
    f = _f(t) if isinstance(t, float) else t
    for path, v in (("location", loc), ("rotation_euler", rot), ("scale", scale)):
        if v is not None:
            setattr(o, path, v)
            o.keyframe_insert(path, frame=f)
    if interp:
        for fc in _fcurves(o):
            for kp in fc.keyframe_points:
                if abs(kp.co.x - f) < 0.5:
                    kp.interpolation, kp.easing = interp, easing
    return f


def _font(path):
    return bpy.data.fonts.load(path, check_existing=True)


def _words(c, name, mat, body, size, font, at, parent, rot_z=0.0, align="CENTER"):
    """Flat words on paper, facing up, in `parent`'s terms."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body, cu.size, cu.font = body, size, font
    cu.align_x, cu.align_y = align, "CENTER"
    cu.space_line = 0.95
    cu.materials.append(mat)
    o = bpy.data.objects.new(name, cu)
    c.objects.link(o)
    o.parent = parent
    o.location, o.rotation_euler = at, (0, 0, math.radians(rot_z))
    return o


def _plane(c, name, mat, w, h, at, parent, crop=(0.0, 0.0, 1.0, 1.0)):
    """A rectangle facing up, UV'd over `crop` (u0 v0 u1 v1) of its image."""
    bm = bmesh.new()
    uv = bm.loops.layers.uv.new()
    f = bm.faces.new([bm.verts.new((x * w / 2, y * h / 2, 0)) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))])
    u0, v0, u1, v1 = crop
    for loop, st in zip(f.loops, ((u0, v0), (u1, v0), (u1, v1), (u0, v1))):
        loop[uv].uv = st
    o = _obj(c, name, bm, [mat])
    o.parent, o.location = parent, at
    return o


def _empty(c, name, parent=None, at=(0, 0, 0)):
    o = bpy.data.objects.new(name, None)
    o.empty_display_size = 0.05
    c.objects.link(o)
    o.parent, o.location = parent, at
    return o


def _photo_mat(name, path):
    """A painted frame as a press photograph: taken to grey."""
    m = _mat(name, (1, 1, 1))
    nt = m.node_tree
    tex = nt.nodes.get("SF_Photo") or nt.nodes.new("ShaderNodeTexImage")
    tex.name = "SF_Photo"
    im = bpy.data.images.load(bpy.path.abspath(path), check_existing=True)
    im.filepath = path
    tex.image, tex.extension = im, "EXTEND"
    bw = nt.nodes.new("ShaderNodeRGBToBW")
    nt.links.new(tex.outputs["Color"], bw.inputs[0])
    nt.links.new(bw.outputs[0], _bsdf(m).inputs["Base Color"])
    return m


def _crop(im, aspect):
    """The middle of `im` at `aspect`, as u0 v0 u1 v1."""
    w, h = im.size
    a = w / h if h else aspect
    if a > aspect:
        k = aspect / a
        return ((1 - k) / 2, 0.0, (1 + k) / 2, 1.0)
    k = a / aspect
    return (0.0, (1 - k) / 2, 1.0, (1 + k) / 2)


def _photo(c, A, name, caption, n, size=0.028):
    """A big photograph: white paper, the picture (painted, or grey with its
    number), the caption on the strip under it, hidden till it is written."""
    W, b, s = PHOTO_W, PHOTO_BORDER, PHOTO_STRIP
    pw = W - 2 * b
    ph = pw * 9 / 16
    H = b + ph + s
    root = _empty(c, "SF1A_" + name)
    box(c, "SF1A_%sPaper" % name, A["paper"], (W, H, PAPER_T), (0, 0, 0)).parent = root
    at = (0, H / 2 - b - ph / 2, PAPER_T / 2 + 0.00005)
    if n in PAINT_PHOTOS:
        m = _photo_mat("SF1A_Photo%d" % n, PAINT_PHOTOS[n])
        _plane(c, "SF1A_%sPicture" % name, m, pw, ph, at, root, _crop(m.node_tree.nodes["SF_Photo"].image, 16 / 9))
    else:
        _plane(c, "SF1A_%sPicture" % name, A["grey"], pw, ph, at, root)
        _words(c, "SF1A_%sLabel" % name, A["label"], "%d  %s" % (n, name.upper()), 0.024, A["print"],
               (0, at[1], at[2] + 0.0001), root)
    cap = _words(c, "SF1A_%sCaption" % name, A["marker"], caption, size, A["marker_font"],
                 (0, -H / 2 + s / 2, PAPER_T / 2 + 0.0001), root)
    return root, cap


def _drop(o, at, z, yaw, t, come=(0.2, 1.0), spin=30.0, tilt=18.0):
    """Into the shot from above, down onto the desk a little short of its
    place, and slid into it: no hands, the same every time."""
    rest = Vector((at[0], at[1], z))
    d = Vector((come[0], come[1], 0)).normalized()
    f = _f(t)
    _key(o, f - 1, rest + Vector((0, 0, HIDE_Z)), (0, 0, math.radians(yaw + spin)), interp="CONSTANT")
    _key(o, f, rest + d * 0.4 + Vector((0, 0, 0.35)), (math.radians(tilt), 0, math.radians(yaw + spin)),
         interp="QUAD", easing="EASE_IN")
    _key(o, f + 9, rest + d * 0.07, (0, 0, math.radians(yaw + spin * 0.25)), interp="QUAD", easing="EASE_OUT")
    _key(o, f + 23, rest, (0, 0, math.radians(yaw)))


def _pop(o, t):
    """Written: there from `t` on (its drawing is a step of its own)."""
    f = _f(t)
    own = tuple(o.scale)
    _key(o, f - 1, scale=(0, 0, 0), interp="CONSTANT")
    _key(o, f, scale=own, interp="CONSTANT")


def _folder(c, A):
    """Arden Mutual's folder: its back with the tab, the sheets in it, the
    cover on a hinge down its left edge (SF1A_FolderHinge)."""
    w, h = 0.32, 0.44
    root = _empty(c, "SF1A_Folder")
    box(c, "SF1A_FolderBack", A["manila"], (w, h, 0.0015), (0, 0, 0.00075)).parent = root
    box(c, "SF1A_FolderTab", A["manila"], (0.09, 0.03, 0.0015), (w / 2 - 0.07, h / 2 + 0.014, 0.00075)).parent = root
    for k in range(3):
        box(c, "SF1A_FolderSheet%d" % k, A["paper"], (w - 0.03, h - 0.03, 0.0004),
            (0.004 * k, -0.003 * k, 0.0017 + 0.0005 * k), rot=(0, 0, 1.5 * k - 1)).parent = root
    hinge = _empty(c, "SF1A_FolderHinge", root, (-w / 2, 0, 0.0036))
    box(c, "SF1A_FolderCover", A["manila"], (w, h, 0.0012), (w / 2, 0, 0.0006)).parent = hinge
    _words(c, "SF1A_FolderName", A["ink_print"], "ARDEN MUTUAL", 0.03, A["print"], (w / 2, 0.15, 0.00125), hinge)
    _words(c, "SF1A_FolderStamp", A["stamp"], "CONFIDENTIAL", 0.032, A["print"], (w / 2, -0.04, 0.00125), hinge,
           rot_z=9)
    _words(c, "SF1A_FolderFile", A["ink_print"], "FILE 87/SAH/041", 0.014, A["print"], (w / 2, -0.17, 0.00125), hinge)
    return root, hinge


def _id_photos(c, A, n=8):
    """The passport photographs of the missing under a clip: each on its
    pivot at the clipped corner, so that the pile fans out round it; the tag
    on the clip for the count."""
    w, h = 0.085, 0.11
    root = _empty(c, "SF1A_IDs")
    rnd = random.Random(41)
    for k in range(n):
        pivot = _empty(c, "SF1A_IDPivot%d" % k, root, (0, 0, ID_STEP * k))
        z = PAPER_T / 2
        box(c, "SF1A_ID%dPaper" % k, A["paper"], (w, h, PAPER_T), (w / 2, -h / 2, 0)).parent = pivot
        bg = A["id_bg"][k % len(A["id_bg"])]
        _plane(c, "SF1A_ID%dPicture" % k, bg, w - 0.012, h - 0.028, (w / 2, -h / 2 + 0.008, z + 0.00005), pivot)
        hx = w / 2 + rnd.uniform(-0.004, 0.004)
        cyl(c, "SF1A_ID%dHead" % k, A["id_face"], 0.015 + rnd.uniform(-0.002, 0.002), 0.0002,
            (hx, -h / 2 + 0.018, z + 0.0002), seg=20).parent = pivot
        box(c, "SF1A_ID%dShoulders" % k, A["id_coat"], (0.056, 0.022, 0.0002),
            (hx, -h / 2 - 0.016, z + 0.0002)).parent = pivot
    clip = _empty(c, "SF1A_IDClip", root, (0.012, -0.01, ID_STEP * n))
    box(c, "SF1A_IDClipJaw", A["clip"], (0.034, 0.024, 0.005), (0, 0, 0.0025), rot=(0, 0, 45)).parent = clip
    tag = _empty(c, "SF1A_IDTag", clip, (-0.04, 0.035, 0.005))
    tag.rotation_euler = (0, 0, math.radians(30))
    box(c, "SF1A_IDTagCard", A["manila"], (0.06, 0.036, 0.0006), (0, 0, 0)).parent = tag
    count = _words(c, "SF1A_IDCount", A["marker"], "41", 0.03, A["marker_font"], (0, 0, 0.0004), tag)
    return root, count


def _clipping(c, A):
    """The newspaper clipping: a headline over two columns of grey lines."""
    w, h = 0.26, 0.34
    root = _empty(c, "SF1A_Clipping")
    box(c, "SF1A_ClippingPaper", A["newsprint"], (w, h, PAPER_T), (0, 0, 0)).parent = root
    _words(c, "SF1A_ClippingHead", A["ink_print"], "GOVERNMENTS\nEXPRESS CONCERN", 0.03, A["print"],
           (0, h / 2 - 0.05, PAPER_T / 2 + 0.0001), root)
    for col in (-1, 1):
        for k in range(10):
            lw = 0.105 if k % 5 != 4 else 0.06
            box(c, "SF1A_ClippingLine%d_%d" % (col, k), A["news_grey"], (lw, 0.0045, 0.0001),
                (col * 0.062 - (0.105 - lw) / 2, h / 2 - 0.11 - k * 0.0145, PAPER_T / 2 + 0.00005)).parent = root
    cap = _words(c, "SF1A_ClippingCaption", A["marker"], "No one's coming.", 0.033, A["marker_font"],
                 (0, -0.118, PAPER_T / 2 + 0.0004), root, rot_z=8)
    return root, cap


def _contract(c, A):
    """The contract on Arden Mutual's paper: the letterhead, the party, the
    lines, the rate (to be ringed) and the signatures."""
    w, h = 0.30, 0.42
    z = PAPER_T / 2 + 0.0001
    root = _empty(c, "SF1A_Contract")
    box(c, "SF1A_ContractPaper", A["paper"], (w, h, PAPER_T), (0, 0, 0)).parent = root
    _words(c, "SF1A_ContractHead", A["ink_print"], "ARDEN MUTUAL", 0.032, A["print"], (0, h / 2 - 0.035, z), root)
    box(c, "SF1A_ContractRule", A["ink_print"], (w - 0.04, 0.0015, 0.0001), (0, h / 2 - 0.058, z)).parent = root
    _words(c, "SF1A_ContractTitle", A["ink_print"], "CONTRACT FOR SERVICES", 0.016, A["print"],
           (0, h / 2 - 0.08, z), root)
    _words(c, "SF1A_ContractParty", A["ink_print"], "Rapid Assault Team for\nExtraction & Liberation, Ltd.", 0.014,
           A["print"], (0, h / 2 - 0.115, z), root)
    for k in range(6):
        box(c, "SF1A_ContractLine%d" % k, A["print_grey"], (w - 0.06 - (0.08 if k == 5 else 0), 0.004, 0.0001),
            (-(0.04 if k == 5 else 0), h / 2 - 0.16 - k * 0.014, z - 0.00005)).parent = root
    rate = (0.0, -0.035)
    _words(c, "SF1A_ContractRate", A["ink_print"], "PER PERSON DELIVERED ALIVE:   $ ______", 0.012, A["print"],
           (rate[0], rate[1], z), root)
    for k in range(2):
        box(c, "SF1A_ContractTerm%d" % k, A["print_grey"], (w - 0.06, 0.004, 0.0001),
            (0, -0.06 - k * 0.014, z - 0.00005)).parent = root
    for k, (x, who) in enumerate(((-0.07, "R. Callahan"), (0.07, "Everly"))):
        box(c, "SF1A_ContractSignLine%d" % k, A["ink_print"], (0.11, 0.001, 0.0001),
            (x, -h / 2 + 0.05, z)).parent = root
        _words(c, "SF1A_ContractSign%d" % k, A["marker"], who, 0.02, A["marker_font"], (x, -h / 2 + 0.062, z), root)
    ring = _annulus(c, "SF1A_ContractRing", A["marker"], (0.08, rate[1], z + 0.0002), 0.05, 0.004)
    ring.parent = root
    ring.scale = (1.0, 0.32, 1.0)
    cap = _words(c, "SF1A_ContractCaption", A["marker"], "Each one. Alive.", 0.03, A["marker_font"],
                 (0.04, -0.112, z + 0.0002), root, rot_z=-4)
    return root, ring, cap


def _ring_phone(sc):
    """The handset rattling on its cradle while the telephone rings."""
    hs = sc.objects["SF1P_PhoneHandset"]
    base = hs.location.copy()
    for t0, t1 in INTRO_RINGS:
        f0, f1 = _f(t0), _f(t1)
        _key(hs, f0 - 1, base, (0, 0, 0))
        for f in range(f0, f1):
            s = 1 if (f - f0) % 2 == 0 else -1
            _key(hs, f, base + Vector((0, 0, 0.0025 if s > 0 else 0.0)),
                 (math.radians(2.5 * s), math.radians(-1.5 * s), 0), interp="LINEAR")
        _key(hs, f1, base, (0, 0, 0))


def _intro_camera(c, sc):
    """The animatic's camera on INTRO_CAMERA: it and the point it looks at
    keyed, the lens with them."""
    cam = bpy.data.objects.new(sc.name + "_Animatic", bpy.data.cameras.new(sc.name + "_Animatic"))
    c.objects.link(cam)
    cam.data.sensor_fit = "HORIZONTAL"
    cam.data.clip_start, cam.data.clip_end = 0.02, 12000
    look = _empty(c, sc.name + "_AnimaticLook")
    tr = cam.constraints.new("TRACK_TO")
    tr.target, tr.track_axis, tr.up_axis = look, "TRACK_NEGATIVE_Z", "UP_Y"
    for t, (at, to, lens) in INTRO_CAMERA:
        _key(cam, float(t), loc=at)
        _key(look, float(t), loc=to)
        cam.data.lens = lens
        cam.data.keyframe_insert("lens", frame=_f(t))
    return cam


def build_intro_animatic(c, sc):
    """The intro's cards, their falls and captions, the telephone, the
    camera; the dawn is keyed after the drivers (intro_dawn())."""
    A = dict(
        paper=_mat("SF1A_Paper", _srgb(240, 238, 230)),
        newsprint=_mat("SF1A_Newsprint", _srgb(226, 220, 200)),
        manila=_mat("SF1A_Manila", _srgb(214, 186, 128)),
        grey=_mat("SF1A_Grey", _srgb(120, 120, 116)),
        label=_mat("SF1A_Label", _srgb(236, 236, 236), flat=True),
        marker=_mat("SF1A_Marker", _srgb(24, 24, 30)),
        ink_print=_mat("SF1A_InkPrint", _srgb(34, 32, 32)),
        print_grey=_mat("SF1A_PrintGrey", _srgb(150, 146, 136)),
        news_grey=_mat("SF1A_NewsGrey", _srgb(176, 170, 152)),
        stamp=_mat("SF1A_Stamp", _srgb(190, 40, 34)),
        clip=_mat("SF1A_Clip", _srgb(30, 30, 32)),
        id_face=_mat("SF1A_IDFace", _srgb(150, 150, 146)),
        id_coat=_mat("SF1A_IDCoat", _srgb(64, 64, 64)),
        id_bg=[_mat("SF1A_IDBg%d" % k, _srgb(v, v, v - 4)) for k, v in enumerate((214, 196, 226, 186))],
        print=_font(PRINT_FONT),
        marker_font=_font(MARKER_FONT),
    )
    starts = dict((name.split(" ", 1)[0], t) for t, name in INTRO_CARDS)
    for t, name in INTRO_CARDS:
        sc.timeline_markers.new(name, frame=_f(t))
    # 1. The table, the telephone ringing; on the sea by the sheet's bottom
    # left corner: Sahrun. 1987.
    sheet = _empty(c, "SF1A_Sheet")
    cap = _words(c, "SF1A_SheetCaption", A["marker"], "Sahrun. 1987.", 0.055, A["marker_font"],
                 (-0.98, -0.7, 0.0032), sheet, rot_z=-3)
    _pop(cap, 4.6)
    _ring_phone(sc)
    # 2. The folder falls, opens; the first photograph slides out of it on
    # to the capital.
    t = starts["2"]
    folder, hinge = _folder(c, A)
    x, y, yaw = LAND["folder"]
    _drop(folder, (x, y), 0.003, yaw, t + 0.7)
    _key(hinge, t + 2.0, rot=(0, 0, 0))
    _key(hinge, t + 2.7, rot=(0, math.radians(-180), 0))
    tanks, cap = _photo(c, A, "Tanks", "Coup. One night.", 2)
    x, y, yaw = LAND["tanks"]
    at = Vector((LAND["folder"][0], LAND["folder"][1], 0.0075))
    to = Vector((x, y, 0.0045))
    clear = at.lerp(to, 0.8)
    clear.z = at.z
    f = _f(t + 2.9)
    _key(tanks, f - 1, at + Vector((0, 0, HIDE_Z)), (0, 0, math.radians(LAND["folder"][2])), interp="CONSTANT")
    _key(tanks, f, at, (0, 0, math.radians(LAND["folder"][2])), interp="LINEAR")
    _key(tanks, f + 17, clear, (0, 0, math.radians(LAND["folder"][2] + 0.8 * (yaw - LAND["folder"][2]))))
    _key(tanks, f + 26, to, (0, 0, math.radians(yaw)))
    _pop(cap, t + 4.6)
    # 3. Vassar at the tribune, on the capital, over the tanks.
    t = starts["3"]
    vassar, cap = _photo(c, A, "Vassar", 'Gen. Tarek Vassar\n"the Mamba"', 3, size=0.026)
    x, y, yaw = LAND["vassar"]
    _drop(vassar, (x, y), 0.0057, yaw, t + 0.8, come=(-0.3, 1.0))
    _pop(cap, t + 2.8)
    # 4. The passport photographs under their clip, fanned out; 41 on the tag.
    t = starts["4"]
    ids, count = _id_photos(c, A)
    x, y, yaw = LAND["ids"]
    _drop(ids, (x, y), 0.0045, yaw, t + 0.8, come=(0.5, 1.0), spin=-20)
    for k in range(8):
        p = sc.objects["SF1A_IDPivot%d" % k]
        _key(p, t + 2.3, rot=(0, 0, 0))
        _key(p, t + 3.0, rot=(0, 0, math.radians(-12 * k + 6)), interp="QUAD", easing="EASE_OUT")
    _pop(count, t + 4.2)
    # 5. The hostages led to the truck, by the checkpoint.
    t = starts["5"]
    hostages, cap = _photo(c, A, "Hostages", "Ashra checkpoint.\n3 days ago.", 5, size=0.026)
    x, y, yaw = LAND["hostages"]
    _drop(hostages, (x, y), 0.0045, yaw, t + 0.8, come=(-0.2, 1.0))
    _pop(cap, t + 2.8)
    # 6. The clipping at the sheet's right edge; across it: No one's coming.
    t = starts["6"]
    clipping, cap = _clipping(c, A)
    x, y, yaw = LAND["clipping"]
    _drop(clipping, (x, y), 0.0035, yaw, t + 0.8, come=(-0.4, 1.0))
    _pop(cap, t + 3.0)
    # 7. The contract in the middle, over everything; the rate ringed.
    t = starts["7"]
    contract, ring, cap = _contract(c, A)
    x, y, yaw = LAND["contract"]
    _drop(contract, (x, y), 0.0085, yaw, t + 0.8, spin=-15)
    _pop(ring, t + 3.0)
    _pop(cap, t + 3.8)
    # 8. The team at the pickups, over the contract; then the camera leaves
    # the table for the door and the dawn.
    t = starts["8"]
    team, cap = _photo(c, A, "Team", "They don't do peace talks.", 8, size=0.026)
    x, y, yaw = LAND["team"]
    _drop(team, (x, y), 0.0102, yaw, t + 0.7, come=(0.3, 1.0))
    _pop(cap, t + 2.6)
    sc.render.fps = FPS
    sc.frame_start, sc.frame_end = 1, _f(INTRO_END)
    return _intro_camera(c, sc)


def intro_overlaps(sc):
    """What passes through what in the animatic: every frame, each moving
    card (an ID photograph and the folder's cover each on their own) tried
    against the desk's things -- the sheet, the desk, the pins, the props --
    and the other cards, triangle by triangle. Returns {"a | b": [(first
    frame, last frame), ...]}; empty when nothing does."""
    from mathutils.bvhtree import BVHTree

    def tree(o):
        return [o] + list(o.children_recursive)

    units = {}
    for r in [o for o in sc.objects if o.name.startswith("SF1A_") and o.parent is None and o.type == "EMPTY"]:
        taken = set()
        for sub in [o for o in r.children_recursive if o.name.startswith(("SF1A_IDPivot", "SF1A_FolderHinge"))]:
            ms = [o for o in tree(sub) if o.type == "MESH"]
            units[sub.name] = (r.name, ms)
            taken |= {o.name for o in ms}
        rest = [o for o in tree(r) if o.type == "MESH" and o.name not in taken]
        if rest:
            units[r.name] = (r.name, rest)
    carded = {o.name for _, ms in units.values() for o in ms}

    def on_desk(o):
        ws = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo, hi = Vector(map(min, *ws)), Vector(map(max, *ws))
        return lo.x > -1.7 and hi.x < 1.7 and lo.y > -1.2 and hi.y < 1.2 and hi.z > -0.05 and lo.z < 0.6

    def bvh(objs):
        dg = bpy.context.evaluated_depsgraph_get()
        verts, polys = [], []
        for o in objs:
            oe = o.evaluated_get(dg)
            me = oe.to_mesh()
            base = len(verts)
            verts += [oe.matrix_world @ v.co for v in me.vertices]
            polys += [[base + i for i in p.vertices] for p in me.polygons]
            oe.to_mesh_clear()
        return BVHTree.FromPolygons(verts, polys) if polys else None

    here = sc.frame_current
    sc.frame_set(sc.frame_start)
    props = {o.name: bvh([o]) for o in sc.objects if o.type in ("MESH", "CURVE") and o.name not in carded
             and not o.name.startswith("SF1H_") and on_desk(o)}
    prev, cache, hits = {}, {}, {}
    for f in range(sc.frame_start, sc.frame_end + 1):
        sc.frame_set(f)
        sig, shown = {}, {}
        for u, (_, ms) in units.items():
            sig[u] = tuple(round(x, 6) for o in ms[:2] for row in o.matrix_world for x in row)
            shown[u] = ms[0].matrix_world.translation.z < HIDE_Z / 4
        moving = [u for u in units if shown[u] and sig[u] != prev.get(u)]
        prev = sig
        for u in [u for u in units if shown[u]]:
            if moving and (u not in cache or cache[u][0] != sig[u]):
                cache[u] = (sig[u], bvh(units[u][1]))
        for u in moving:
            tu = cache[u][1]
            for name, t in props.items():
                if t and tu.overlap(t):
                    hits.setdefault("%s | %s" % (u, name), []).append(f)
            for v in units:
                if v == u or not shown[v]:
                    continue
                if tu.overlap(cache[v][1]):
                    hits.setdefault(" | ".join(sorted((u, v))), []).append(f)
    sc.frame_set(here)
    out = {}
    for k, fs in hits.items():
        fs = sorted(set(fs))
        spans = [[fs[0], fs[0]]]
        for x in fs[1:]:
            if x == spans[-1][1] + 1:
                spans[-1][1] = x
            else:
                spans.append([x, x])
        out[k] = [tuple(s) for s in spans]
    return out


def intro_dawn(sc):
    """daylight keyed: the night till the camera leaves the table, the dawn
    by the time it looks out of the door."""
    t0, t1 = INTRO_DAWN
    for t, v in ((t0, 0.0), (t1, 1.0)):
        sc[DAYLIGHT] = v
        sc.keyframe_insert('["%s"]' % DAYLIGHT, frame=_f(t))


BUILDERS = {1: build_intro_01, 2: build_intro_02, 3: build_intro_03, 4: build_intro_04, 5: build_intro_05, 6: build_intro_06, 7: build_intro_07, 8: build_intro_08,
            "01_3D": build_intro_01_3d}


def build_frame(n):
    return BUILDERS[n]()


def render_frame(n, path, percent=100, samples=32):
    sc = bpy.data.scenes["Intro_%02d" % n if isinstance(n, int) else "Intro_" + n]
    sc.render.resolution_percentage = percent
    sc.eevee.taa_render_samples = samples
    sc.render.filepath = bpy.path.abspath(path)
    bpy.ops.render.render(scene=sc.name, write_still=True)


# The text block each blend keeps in place of this file (LOADER_TEXT):
# it runs this file into the namespace it is run in.
LOADER_TEXT = "jackal_story_frames.py"
LOADER_SRC = """# The story's frames: tools/blender/story_frames.py builds them; this block
# only runs it here, so that after
#     exec(bpy.data.texts["jackal_story_frames.py"].as_string())
# build_frame(n) and the rest are at hand. Edit the file, not this block.
import bpy
_path = bpy.path.abspath("//../../tools/blender/story_frames.py")
exec(compile(open(_path, encoding="utf-8").read(), _path, "exec"), globals())
"""


def install_loader():
    t = bpy.data.texts.get(LOADER_TEXT) or bpy.data.texts.new(LOADER_TEXT)
    t.from_string(LOADER_SRC)
    t.use_module = False


if __name__ == "__main__" and "--" in sys.argv:
    _args = sys.argv[sys.argv.index("--") + 1:]
    if "--build" in _args:
        _n = _args[_args.index("--build") + 1]
        build_frame(int(_n) if _n.isdigit() else _n)
        if "--save" in _args:
            install_loader()
            bpy.ops.wm.save_mainfile()
