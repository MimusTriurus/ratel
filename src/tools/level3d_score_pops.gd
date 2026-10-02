# The points a prisoner is worth as he boards the rescue helicopter, "+500"
# over it, white ringed in the colour of the player who brought him and a
# thin black line outside that, rising and fading
# (level3d_preview.gd, rescue.scored). Not the game's: its points only ever
# went to the score, and in the 3D frame, at the far end of the screen from
# the HUD, that went unseen.
#
# On the HUD's layer, in its 2048x1152 layout, as the HELP calls are
# (Level3DCallouts): the same size wherever it is in the tilted frame and
# whatever the zoom, at the HUD's size (Level3DSettings.hud_scale), in the
# game's font with the canvas' nearest filter. The font is the white one
# with its dark shadow; it has no "+", which is drawn as its hyphen is, the
# bar and its shadow, crossed. White and not the player's colour: the
# vehicle's olive all but went on stage 1's sand, and the ring says whose it
# is well enough. A white ring round the colour was tried too, and the dark
# digits read no better for it.
#
# Each pop is a CanvasGroup of its rings and its digits, faded as one: faded
# piece by piece, the rings' stamps would show through each other and
# through the digits.
class_name Level3DScorePops
extends Control

const GLYPH := 32.0             # at 100%
const LIFE := 1.2               # seconds
const RISE := 2.0               # glyphs it rises over LIFE, steadily: eased, the one after would catch it up
const FADE := 0.4               # the last seconds of LIFE it fades out over
const SPACING := 1.2            # glyphs a pop rises before the next shows
# The hyphen's bar and the shadow under it, in the glyph's 32 font pixels:
# the plus is it and the same bar stood upright through its middle.
const BAR := Rect2(0, 12, 28, 4)
const SHADOW_OFFSET := Vector2(3, 3)
const SHADOW_DEPTH := 3.0
const SHADOW_SAMPLE := Vector2(16, 17)
const RING := 4.0               # the player's ring, font pixels of the glyph's 32
const LINE := 2.0               # the black line outside it
# The glyphs as a silhouette in the colour they are drawn with: the font's
# own white and shadow alike, for the rings.
const OUTLINE_SHADER := """
shader_type canvas_item;
varying vec4 tint;
void vertex() { tint = COLOR; }
void fragment() { COLOR = vec4(tint.rgb, texture(TEXTURE, UV).a * tint.a); }
"""

var camera: Camera3D
var scale_factor := 1.0

var _glyphs := {}               # code point -> Spr
var _shadow := Color(0.2, 0.2, 0.2)
var _material: ShaderMaterial
var _pops: Array[Pop] = []


# One pop: its rings drawn by `rings`, under the silhouette shader, and its
# digits by `digits` over them.
class Pop:
	extends CanvasGroup

	var at: Vector3
	var text: String
	var colour: Color
	var age := 0.0              # seconds; < 0 waiting for the one before it
	var x := 0.0
	var y := 0.0
	var g := 32.0
	var rings: Node2D
	var digits: Node2D


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = OUTLINE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
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
	var pop := Pop.new()
	pop.at = at
	pop.text = "+%d" % points
	pop.colour = colour
	if not _pops.is_empty():
		var clear_at := LIFE * SPACING / RISE
		pop.age = minf(_pops.back().age - clear_at, 0.0)
	pop.rings = Node2D.new()
	pop.rings.material = _material
	pop.rings.draw.connect(_draw_rings.bind(pop))
	pop.add_child(pop.rings)
	pop.digits = Node2D.new()
	pop.digits.draw.connect(_draw_digits.bind(pop))
	pop.add_child(pop.digits)
	pop.visible = false
	add_child(pop)
	_pops.append(pop)


func clear() -> void:
	for pop in _pops:
		pop.queue_free()
	_pops.clear()


func _process(delta: float) -> void:
	var g := maxf(roundf(GLYPH * scale_factor / 8.0), 1.0) * 8.0     # whole font pixels
	for pop: Pop in _pops.duplicate():
		pop.age += delta
		if pop.age >= LIFE:
			_pops.erase(pop)
			pop.queue_free()
			continue
		pop.visible = pop.age >= 0.0 and camera != null and not camera.is_position_behind(pop.at)
		if not pop.visible:
			continue
		var t := pop.age / LIFE
		var rise := RISE * g * t
		var anchor := camera.unproject_position(pop.at)
		pop.g = g
		pop.x = roundf(anchor.x - g * pop.text.length() * 0.5)
		pop.y = roundf(anchor.y - g - rise)
		pop.self_modulate.a = clampf((LIFE - pop.age) / FADE, 0.0, 1.0)
		pop.rings.queue_redraw()
		pop.digits.queue_redraw()


# The rings as the glyphs' silhouette (OUTLINE_SHADER) stamped round them at
# every whole pixel out to each ring's reach, the outermost first.
func _draw_rings(pop: Pop) -> void:
	var unit := pop.g / GLYPH
	for ring in [[Color.BLACK, roundf((RING + LINE) * unit)], [pop.colour, roundf(RING * unit)]]:
		var reach: float = ring[1]
		for r in range(1, int(reach) + 1):
			for k in 16:
				var a := TAU * k / 16.0
				var offset := (Vector2(cos(a), sin(a)) * r).round()
				_glyph_line(pop.rings, pop.text, pop.x + offset.x, pop.y + offset.y, pop.g, ring[0])


func _draw_digits(pop: Pop) -> void:
	_glyph_line(pop.digits, pop.text, pop.x, pop.y, pop.g, Color.WHITE)


func _glyph_line(on: CanvasItem, text: String, x: float, y: float, g: float, tint: Color) -> void:
	for i in text.length():
		var c := text.unicode_at(i)
		if c == 0x2B:
			_plus(on, x, y, g, tint)
		else:
			var s: Spr = _glyphs.get(c)
			if s != null:
				on.draw_texture_rect_region(s.tex, Rect2(x, y, g, g), s.region, tint)
		x += g


# The "+" in a glyph's box at `x`, `y`: the hyphen's bar and one upright, the
# shadows first, each down and right of its bar as the font's are.
func _plus(on: CanvasItem, x: float, y: float, g: float, tint: Color) -> void:
	var unit := g / GLYPH
	var flat := BAR
	var upright := Rect2(BAR.position.x + (BAR.size.x - BAR.size.y) * 0.5,
			BAR.position.y + (BAR.size.y - BAR.size.x) * 0.5, BAR.size.y, BAR.size.x)
	var shade := Color(_shadow * tint, tint.a)
	for bar in [flat, upright]:
		var r := Rect2(Vector2(x, y) + (bar.position + SHADOW_OFFSET) * unit,
				(bar.size + Vector2.ONE * (SHADOW_DEPTH - SHADOW_OFFSET.x)) * unit)
		on.draw_rect(r, shade)
	for bar in [flat, upright]:
		on.draw_rect(Rect2(Vector2(x, y) + bar.position * unit, bar.size * unit), tint)
