class_name Level3DPixels
extends RefCounted

# How many of the screen's pixels a pixel of the 2048x1152 frame is. The
# preview scales its window's content as canvas items (level3d_preview.gd,
# _apply_resolution): its own 3D is drawn at the window's size, but a
# SubViewport sized in the frame's pixels -- the shop's bay, the title's
# splash -- was drawn at 2048x1152 and blown up to the screen, its edges'
# steps with it, a staircase on every model. Such a render is made this many
# times its frame size instead. 1 under a --shot, whose window is the frame.
#
# `msaa` is the settings' anti-aliasing (Level3DSettings.antialias), which
# the preview sets (_apply_resolution): the shop's and the splash's renders
# take it as their own, each frame they are drawn.
static var msaa := Viewport.MSAA_4X

static func scale(node: Node) -> float:
	var window := node.get_window()
	if window == null or window.content_scale_mode != Window.CONTENT_SCALE_MODE_CANVAS_ITEMS:
		return 1.0
	var base := Vector2(window.content_scale_size)
	if base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	return clampf(minf(window.size.x / base.x, window.size.y / base.y), 0.25, 4.0)
