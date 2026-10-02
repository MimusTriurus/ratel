# The prisoners' HELP over the 3D preview, as a comic's shout: a white burst
# with a black line round it and a tail to where the call comes from, "HELP!"
# in it in the preview's font (Level3DFont), red (level3d_preview.gd, _make_hud). Where the calls
# are and when they show is Level3DFriends' (help_marks); this only draws them.
# A mark may say other words in another colour: the rescue helicopter's
# crewman's HERE! (Level3DRescueCrew.call_marks).
#
# On the HUD's layer, in its 2048x1152 layout, as the pad's arrow is
# (Level3DArrow), not in the level as a Label3D: a call is the same size
# wherever it is in the tilted frame and whatever the zoom, at the HUD's size
# (Level3DSettings.hud_scale), and its glyphs are the game's, whole pixels with
# the canvas' nearest filter. The burst pops as each blink comes on, bigger
# for a moment and settling; the glyphs do not, a glyph scaled by a fraction
# being a ragged one.
class_name Level3DCallouts
extends Control

const TEXT := "HELP!"             # a mark's words unless it has its own "text"
const GLYPH := 32.0             # a building's call at 100%; a prisoner's SMALL of it
const SMALL := 0.75
const TEXT_COLOUR := Color(0.9, 0.12, 0.08)
const LINE := 8.0               # the black line round the burst, layout px at 100%
const SPIKES := 16
const SPIKE_DEPTH := 0.22       # how far in the burst's notches come, of its radius
const SPIKE_JITTER := 0.12      # each point off its place, of the radius
const PADDING := 0.8            # glyphs round the text, inside the burst
const TAIL := 1.1               # glyphs from the burst's foot to the point it calls from
const TAIL_WIDTH := 0.7         # glyphs across where the tail leaves the burst
const POP := 1.3                # the burst's size as a blink comes on
const POP_TICKS := 8            # ticks it takes to settle

var camera: Camera3D
# `marks.call()`: Level3DFriends.help_marks.
var marks: Callable
var scale_factor := 1.0



func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	texture_filter = Level3DFont.filter()
	if camera == null or not marks.is_valid():
		return
	var frame := Rect2(Vector2.ZERO, size)
	for mark: Dictionary in marks.call():
		var at: Vector3 = mark.at
		if camera.is_position_behind(at):
			continue
		var tip := camera.unproject_position(at)
		if not frame.grow(GLYPH * 4.0).has_point(tip):
			continue
		_burst(tip, GLYPH * scale_factor * (SMALL if mark.small else 1.0), mark.age, mark.seed,
				mark.get("text", TEXT), mark.get("colour", TEXT_COLOUR))


# One call, its tail's tip at `tip`, its glyphs `g` px, `text` in `colour`.
func _burst(tip: Vector2, g: float, age: int, seed: int, text: String, colour: Color) -> void:
	g = maxf(roundf(g / 8.0), 1.0) * 8.0     # whole font pixels
	var text_w := Level3DFont.width(text, g)
	var radius := Vector2(text_w * 0.5 + g * PADDING, g * 0.5 + g * PADDING)
	var centre := tip - Vector2(0.0, radius.y + g * TAIL)
	var pop := 1.0 + (POP - 1.0) * clampf(1.0 - float(age) / POP_TICKS, 0.0, 1.0)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var line := maxf(roundf(LINE * scale_factor), 2.0)
	var points: Array[Vector2] = []     # each point's angle and reach
	for i in SPIKES * 2:
		var angle := TAU * i / (SPIKES * 2) + rng.randf_range(-0.5, 0.5) * TAU / (SPIKES * 4)
		var reach := 1.0 if i % 2 == 0 else 1.0 - SPIKE_DEPTH
		points.append(Vector2(angle, reach + rng.randf_range(-SPIKE_JITTER, SPIKE_JITTER)))
	# The tail: from the burst's foot, leaning a little to one side, to the tip.
	var lean := rng.randf_range(-0.6, 0.6) * g
	var foot := centre + Vector2(lean, radius.y * (1.0 - SPIKE_DEPTH) * pop - g * 0.5)
	var half := g * TAIL_WIDTH * 0.5
	var down := (tip - foot).normalized()
	var across := down.orthogonal()
	# The line first, as the same burst grown by it and a tail wider and
	# longer by it, then the white over: simpler than Geometry2D's offset,
	# which wants the winding minded and mitres the spikes to needles.
	draw_colored_polygon(_star(centre, radius * pop, points, line), Color.BLACK)
	draw_colored_polygon(PackedVector2Array([foot - across * (half + line), tip + down * line * 1.6,
			foot + across * (half + line)]), Color.BLACK)
	draw_colored_polygon(_star(centre, radius * pop, points, 0.0), Color.WHITE)
	draw_colored_polygon(PackedVector2Array([foot - across * half, tip, foot + across * half]), Color.WHITE)

	var x := roundf(centre.x - text_w * 0.5)
	var y := roundf(centre.y - g * 0.5)
	Level3DFont.draw(self, text, x, y, g, Level3DFont.WHITE, colour)



# The burst's points round `centre`: each Vector2(angle, reach) of `points`
# on the ellipse of `radius`, pushed out by `grow` px.
static func _star(centre: Vector2, radius: Vector2, points: Array[Vector2], grow: float) -> PackedVector2Array:
	var star := PackedVector2Array()
	for p in points:
		var d := Vector2(cos(p.x), sin(p.x))
		star.append(centre + Vector2(d.x * radius.x, d.y * radius.y) * p.y + d * grow)
	return star
