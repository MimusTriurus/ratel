# Renders a stage from straight above with its J_Camera_Top, or compares two
# such renders: how a level built from its file (build_level.py) is held to
# the one Blender built by hand. docs/level-editor-plan.md, stage 5.
#
#     blender -b <stage>.blend --python tools/blender/render_top.py -- --render out.png [percent]
#     blender -b --factory-startup --python tools/blender/render_top.py -- \
#         --compare a.png b.png diff.png [report.txt]
#
# The camera is the stage's own: orthographic, 50 px to the metre at 100 %,
# the whole level. The comparison writes the difference, bright where the two
# differ, and says how much of the frame differs by more than a few levels
# of grey -- in all, and block by block, so that a stretch that moved shows
# apart from trees that are only elsewhere.
import bpy, os, sys
import numpy as np

ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []


def render(out, percent):
    scene = bpy.context.scene
    scene.camera = bpy.data.objects["J_Camera_Top"]
    cam = scene.camera.data
    # The camera frames the level at 1560 x 8412 (jackal_stage1_full.png).
    scene.render.resolution_x = 1560
    scene.render.resolution_y = 8412
    scene.render.resolution_percentage = percent
    scene.frame_set(1)
    scene.render.image_settings.file_format = "PNG"
    scene.render.filepath = out
    bpy.ops.render.render(write_still=True)


def load(path):
    image = bpy.data.images.load(path)
    w, h = image.size
    pixels = np.empty(w * h * 4, np.float32)
    image.pixels.foreach_get(pixels)
    return pixels.reshape(h, w, 4)[:, :, :3], image


def compare(a_path, b_path, diff_path, report_path=None):
    a, image = load(a_path)
    b, _ = load(b_path)
    d = np.abs(a - b).max(axis=2)
    lines = []
    for level in (0.02, 0.1, 0.25):
        lines.append("differs by more than %3d/255: %5.2f%% of the frame" % (level * 255, 100.0 * (d > level).mean()))
    # Block by block, 50 px (a metre at 100 %) a side: the share of blocks
    # whose mean colour differs by more than 0.1.
    size = 50 * image.size[0] // 1560
    h, w = d.shape
    hb, wb = h // size, w // size
    ma = a[:hb * size, :wb * size].reshape(hb, size, wb, size, 3).mean(axis=(1, 3))
    mb = b[:hb * size, :wb * size].reshape(hb, size, wb, size, 3).mean(axis=(1, 3))
    block = np.abs(ma - mb).max(axis=2)
    lines.append("blocks of %d px whose mean differs by more than 25/255: %5.2f%% of %d"
                 % (size, 100.0 * (block > 0.1).mean(), block.size))
    out = np.zeros((h, w, 4), np.float32)
    out[:, :, 0] = np.clip(d * 4.0, 0, 1)
    out[:, :, 1] = a.mean(axis=2) * 0.35
    out[:, :, 2] = a.mean(axis=2) * 0.35
    out[:, :, 3] = 1.0
    result = bpy.data.images.new("diff", w, h)
    result.pixels.foreach_set(out.ravel())
    result.filepath_raw = diff_path
    result.file_format = "PNG"
    result.save()
    text = "\n".join(lines) + "\n"
    if report_path:
        open(report_path, "w").write(text)
    print(text)


if ARGV and ARGV[0] == "--render":
    render(os.path.abspath(ARGV[1]), int(ARGV[2]) if len(ARGV) > 2 else 50)
elif ARGV and ARGV[0] == "--compare":
    compare(*[os.path.abspath(p) for p in ARGV[1:4]], *(ARGV[4:5]))
