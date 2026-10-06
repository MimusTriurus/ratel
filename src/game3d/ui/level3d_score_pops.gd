# The points a prisoner is worth as he boards the rescue helicopter, "+500"
# over it, white ringed in the colour of the player who brought him and a
# thin black line outside that, rising and fading
# (level3d_preview.gd, rescue.scored). Not the game's: its points only ever
# went to the score, and in the 3D frame, at the far end of the screen from
# the HUD, that went unseen. And, longer, "1UP" and
# "POWER UP" over the jeep that got the life or the upgrade, going along with
# it (`add_text`): those come in the thick of things, anywhere on the stage,
# and the HUD's flash alone, at the frame's edge, goes by unseen there.
#
# On the HUD's layer, in its 2048x1152 layout, as the HELP calls are
# (Level3DCallouts): the same size wherever it is in the tilted frame and
# whatever the zoom, at the HUD's size (Level3DSettings.hud_scale), in the
# preview's font (Level3DFont) with the canvas' nearest filter, the white one
# with its dark shadow. White and not the player's colour: the
# vehicle's olive all but went on stage 1's sand, and the ring says whose it
# is well enough. A white ring round the colour was tried too, and the dark
# digits read no better for it.
#
# Each pop is a CanvasGroup of its rings and its digits, faded as one: faded
# piece by piece, the rings' stamps would show through each other and
# through the digits.
class_name Level3DScorePops
extends Control

# The glyphs at 100%, the points' and a jeep's alike: three quarters of the
# HUD's, which over the jeep and the helicopter read out of all proportion
# to them.
const GLYPH := 24.0
const FONT := 32.0              # a glyph's own pixels across, which RING and LINE are in
const LIFE := 1.2               # seconds
const RISE := 2.0               # glyphs it rises over LIFE, steadily: eased, one under would catch it up
const FADE := 0.4               # the last seconds of LIFE it fades out over
const SPACING := 1.2            # glyphs from a pop's top to the foot of one stacked over it
const BIG_LIFE := 1.6
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

var _material: ShaderMaterial
var _pops: Array[Pop] = []


# One pop: its rings drawn by `rings`, under the silhouette shader, and its
# digits by `digits` over them.
class Pop:
	extends CanvasGroup

	var at: Vector3
	var follow: Callable        # `follow.call()`, where it is now, for a jeep's; or `at`
	var big := false
	var life := LIFE
	var text: String
	var colour: Color
	var age := 0.0              # seconds
	var lift := 0.0             # px over where it would be, clear of those up before it (_push)
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


# A pop of `points` at `at`, in `colour`.
func add(at: Vector3, points: int, colour: Color) -> void:
	var pop := Pop.new()
	pop.at = at
	pop.text = "+$%d" % points
	pop.colour = colour
	_push(pop)


# A jeep's pop, `text` over `follow.call()` wherever that goes, longer,
# in `colour`.
func add_text(follow: Callable, text: String, colour: Color) -> void:
	var pop := Pop.new()
	pop.follow = follow
	pop.at = follow.call()
	pop.text = text
	pop.colour = colour
	pop.big = true
	pop.life = BIG_LIFE
	_push(pop)


# With two players two prisoners can board on the same tick, and a jeep can
# get a life and an upgrade on one: a pop that would cross one of its own
# kind already up starts over it instead, lifted clear of its top by SPACING
# of its glyphs, so that they read as lines and not one smudge. Lifted, not
# held back: each comes with its sound (the 1UP with extra_life, the POWER UP
# with upgrade), and one held back came half a second after it. A jeep's pop
# and the points are left to cross: the jeep's is over the jeep, where it was
# got, and drawn over the points (z_index); lifted clear of them, it was
# away up the frame from it. They all rise at the one speed, so a stack stays
# a stack.
func _push(pop: Pop) -> void:
	pop.g = _glyph(pop)
	var anchor := _anchor(pop)
	var width := Level3DFont.width(pop.text, pop.g)
	var moved := true
	while moved:
		moved = false
		for before in _pops:
			if before.big != pop.big:
				continue
			var g := _glyph(before)
			if absf(anchor.x - _anchor(before).x) >= (width + Level3DFont.width(before.text, g)) * 0.5:
				continue
			var b_foot := _anchor(before).y - _rise(before) - before.lift
			var b_top := b_foot - g
			var foot := anchor.y - pop.lift
			if foot > b_top - g * (SPACING - 1.0) and foot - pop.g < b_foot:
				pop.lift = anchor.y - b_top + g * (SPACING - 1.0)
				moved = true
	pop.rings = Node2D.new()
	pop.rings.material = _material
	pop.rings.draw.connect(_draw_rings.bind(pop))
	pop.add_child(pop.rings)
	pop.digits = Node2D.new()
	pop.digits.draw.connect(_draw_digits.bind(pop))
	pop.add_child(pop.digits)
	pop.visible = false
	pop.z_index = 1 if pop.big else 0
	add_child(pop)
	_pops.append(pop)


# How far it has risen: RISE of the points' glyphs over LIFE, whatever its
# own size and life.
func _rise(pop: Pop) -> float:
	return RISE * GLYPH * scale_factor * maxf(pop.age, 0.0) / LIFE


# Its glyphs' size: whole font pixels.
func _glyph(pop: Pop) -> float:
	return maxf(roundf(GLYPH * scale_factor / 8.0), 1.0) * 8.0


# Where it starts from on the screen, its foot's middle.
func _anchor(pop: Pop) -> Vector2:
	if camera == null or camera.is_position_behind(pop.at):
		return Vector2.ZERO
	return camera.unproject_position(pop.at)


func clear() -> void:
	for pop in _pops:
		pop.queue_free()
	_pops.clear()


func _process(delta: float) -> void:
	for pop: Pop in _pops.duplicate():
		pop.age += delta
		if pop.age >= pop.life:
			_pops.erase(pop)
			pop.queue_free()
			continue
		if pop.follow.is_valid():
			pop.at = pop.follow.call()
		pop.visible = pop.age >= 0.0 and camera != null and not camera.is_position_behind(pop.at)
		if not pop.visible:
			continue
		var g := _glyph(pop)
		var anchor := camera.unproject_position(pop.at)
		pop.g = g
		pop.x = roundf(anchor.x - Level3DFont.width(pop.text, g) * 0.5)
		pop.y = roundf(anchor.y - g - _rise(pop) - pop.lift)
		pop.self_modulate.a = clampf((pop.life - pop.age) / FADE, 0.0, 1.0)
		pop.rings.texture_filter = Level3DFont.filter()
		pop.digits.texture_filter = pop.rings.texture_filter
		pop.rings.queue_redraw()
		pop.digits.queue_redraw()


# The rings as the glyphs' silhouette (OUTLINE_SHADER) stamped round them at
# every whole pixel out to each ring's reach, the outermost first.
func _draw_rings(pop: Pop) -> void:
	var unit := pop.g / FONT
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
	Level3DFont.draw(on, text, x, y, g, Level3DFont.WHITE, tint)
