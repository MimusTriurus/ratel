# The points a prisoner is worth as he boards the rescue helicopter, "+500"
# over it in the colour of the player who brought him, rising and fading
# (level3d_preview.gd, rescue.scored). Not the game's: its points only ever
# went to the score, and in the 3D frame, at the far end of the screen from
# the HUD, that went unseen.
#
# On the HUD's layer, in its 2048x1152 layout, as the HELP calls are
# (Level3DCallouts): the same size wherever it is in the tilted frame and
# whatever the zoom, at the HUD's size (Level3DSettings.hud_scale), in the
# game's font with the canvas' nearest filter. The font is the white one
# with its dark shadow, multiplied by the colour; it has no "+", which is
# drawn as its hyphen is, the bar and its shadow, crossed.
class_name Level3DScorePops
extends Control

const GLYPH := 32.0             # at 100%
const LIFE := 1.2               # seconds
const RISE := 2.0               # glyphs it rises over LIFE
const FADE := 0.4               # the last seconds of LIFE it fades out over
const SPACING := 1.2            # glyphs a pop rises before the next shows
# The hyphen's bar and the shadow under it, in the glyph's 32 font pixels:
# the plus is it and the same bar stood upright through its middle.
const BAR := Rect2(0, 12, 28, 4)
const SHADOW_OFFSET := Vector2(3, 3)
const SHADOW_DEPTH := 3.0
const SHADOW_SAMPLE := Vector2(16, 17)

var camera: Camera3D
var scale_factor := 1.0

var _glyphs := {}               # code point -> Spr
var _shadow := Color(0.2, 0.2, 0.2)
var _pops: Array[Dictionary] = []   # {"at" -- level metres, "text", "colour", "age" -- seconds, < 0 waiting}


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := Atlas.new(Main.IMAGES + "font.png", Main.IMAGES + "font.xml")
	for c in "0123456789":
		_glyphs[c.unicode_at(0)] = font.get_sprite("font-black-%s.png" % c)
	# The shadow's colour off the hyphen, under its bar.
	var hyphen: Spr = font.get_sprite("font-black-hyphen.png")
	if hyphen != null:
		var image := hyphen.tex.get_image()
		var p := hyphen.region.position + SHADOW_SAMPLE * hyphen.region.size.x / GLYPH
		_shadow = image.get_pixelv(Vector2i(p))


# A pop of `points` at `at`, in `colour`. With two players two prisoners can
# board on the same tick: a pop waits, unseen, until the one before it has
# risen SPACING glyphs, so that they read as two lines and not one smudge.
func add(at: Vector3, points: int, colour: Color) -> void:
	var age := 0.0
	if not _pops.is_empty():
		var clear_at := LIFE * (1.0 - sqrt(1.0 - SPACING / RISE))
		age = minf(_pops.back().age - clear_at, 0.0)
	_pops.append({"at": at, "text": "+%d" % points, "colour": colour, "age": age})


func clear() -> void:
	_pops.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if _pops.is_empty():
		return
	for pop in _pops:
		pop.age += delta
	_pops = _pops.filter(func(pop: Dictionary) -> bool: return pop.age < LIFE)
	queue_redraw()


func _draw() -> void:
	if camera == null:
		return
	var g := maxf(roundf(GLYPH * scale_factor / 8.0), 1.0) * 8.0     # whole font pixels
	for pop in _pops:
		var at: Vector3 = pop.at
		if pop.age < 0.0 or camera.is_position_behind(at):
			continue
		var t: float = pop.age / LIFE
		var rise := RISE * g * (1.0 - (1.0 - t) * (1.0 - t))
		var alpha := clampf((LIFE - pop.age) / FADE, 0.0, 1.0)
		var anchor := camera.unproject_position(at)
		var text: String = pop.text
		var x := roundf(anchor.x - g * text.length() * 0.5)
		var y := roundf(anchor.y - g - rise)
		var tint := Color(pop.colour, alpha)
		for i in text.length():
			var c := text.unicode_at(i)
			if c == 0x2B:
				_plus(x, y, g, tint)
			else:
				var s: Spr = _glyphs.get(c)
				if s != null:
					draw_texture_rect_region(s.tex, Rect2(x, y, g, g), s.region, tint)
			x += g


# The "+" in a glyph's box at `x`, `y`: the hyphen's bar and one upright, the
# shadows first, each down and right of its bar as the font's are.
func _plus(x: float, y: float, g: float, tint: Color) -> void:
	var unit := g / GLYPH
	var flat := BAR
	var upright := Rect2(BAR.position.x + (BAR.size.x - BAR.size.y) * 0.5,
			BAR.position.y + (BAR.size.y - BAR.size.x) * 0.5, BAR.size.y, BAR.size.x)
	var shade := Color(_shadow * tint, tint.a)
	for bar in [flat, upright]:
		var r := Rect2(Vector2(x, y) + (bar.position + SHADOW_OFFSET) * unit,
				(bar.size + Vector2.ONE * (SHADOW_DEPTH - SHADOW_OFFSET.x)) * unit)
		draw_rect(r, shade)
	for bar in [flat, upright]:
		draw_rect(Rect2(Vector2(x, y) + bar.position * unit, bar.size * unit), tint)
