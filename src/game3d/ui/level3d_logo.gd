# The title screen's name, RATEL and under it SQUAD, over the splash's sun
# where the 2D game's title art had its own (Level3DTitle).
#
# Written in the font the settings pick (Level3DFont.style), from the .ttf
# files the HUD's sheets were baked from, since the sheets are 32 px glyphs
# and the name is several times that: modern is Black Ops One, its letters
# filled from the sun's colours -- yellow at their feet, nearest the sun,
# through its orange edge to the glow's red at their tops (an outline was
# tried, and on the black over the sun was not to be seen); 8-bit is Press
# Start 2P drawn sharp, the same colours in LOGO_BANDS flat bands, as a
# Famicom title screen's logo is, over a hard shadow a font pixel down and
# across.
# Both breathe with the sun (Level3DSplash3D's SKY_SHADER: once every
# BREATH seconds a little brighter), by the same clock.
#
# LOGO_SHADER fills what is drawn in white with the colours and leaves what
# is drawn in any other colour as it is -- the shadow and SQUAD.
class_name Level3DLogo
extends Control

const PIXEL_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const MODERN_FONT := "res://assets/fonts/BlackOpsOne-Regular.ttf"
const NAME := "RATEL"
const UNDER := "SQUAD"

# In the title's 2048x1152 layout: the name centred on the splash (x), its
# baseline and its size in px, SQUAD's baseline under it, its size and the
# space between its letters -- modern, then 8-bit, whose sizes are whole
# numbers of its 8 px grid.
const CENTRE_X := 1040.0
const MODERN := {"size": 150, "baseline": 162.0, "spacing": 4.0,
		"under_size": 40, "under_baseline": 212.0, "under_spacing": 22.0}
const PIXEL := {"size": 96, "baseline": 150.0, "spacing": 8.0,
		"under_size": 32, "under_baseline": 206.0, "under_spacing": 16.0}
const SHADOW_COLOUR := Color(0.35, 0.03, 0.0)
const UNDER_TINT := Color(0.82, 0.52, 0.33)
const LOGO_BANDS := 4
const BREATH := 7.0
const BRIGHTEN := 0.08

const LOGO_SHADER := """
shader_type canvas_item;
// The fill's top and bottom, in the layout's px; 0 bands is a smooth fill.
uniform float top = 0.0;
uniform float bottom = 1.0;
uniform float bands = 0.0;
uniform float breath = 7.0;
uniform float brighten = 0.08;
// sRGB: the glow's red, the sun's orange edge, its yellow heart
// (Level3DSplash3D's SKY_SHADER).
const vec3 TOP = vec3(196.0, 24.0, 0.0) / 255.0;
const vec3 MIDDLE = vec3(246.0, 96.0, 4.0) / 255.0;
const vec3 BOTTOM = vec3(253.0, 227.0, 6.0) / 255.0;
varying vec2 at;
varying vec4 drawn;
void vertex() {
	at = VERTEX;
	drawn = COLOR;
}
void fragment() {
	float t = clamp((at.y - top) / (bottom - top), 0.0, 1.0);
	if (bands > 0.0) {
		t = min(floor(t * bands) / (bands - 1.0), 1.0);
	}
	vec3 fill = t < 0.5 ? mix(TOP, MIDDLE, t * 2.0) : mix(MIDDLE, BOTTOM, t * 2.0 - 1.0);
	fill *= 1.0 + brighten * (0.5 - 0.5 * cos(TIME * TAU / breath));
	float white = step(0.99, min(drawn.r, min(drawn.g, drawn.b)));
	COLOR.rgb = mix(COLOR.rgb, fill, white);
}
"""

# How far down the title has moved the name, and the splash under it, from
# where these put it (Level3DTitle.SCENE_DROP).
var drop := 0.0
var _fonts := {}             # Level3DFont.Style -> FontFile


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = LOGO_SHADER
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = shader
	(material as ShaderMaterial).set_shader_parameter("breath", BREATH)
	(material as ShaderMaterial).set_shader_parameter("brighten", BRIGHTEN)


# Drawn again in the settings' font, with its filter.
func restyle() -> void:
	texture_filter = Level3DFont.filter()
	queue_redraw()


func _draw() -> void:
	var modern := Level3DFont.style == Level3DFont.Style.MODERN
	var font := _font(Level3DFont.style)
	var look: Dictionary = MODERN if modern else PIXEL
	var size: int = look.size
	var baseline: float = look.baseline + drop
	var top := baseline - font.get_ascent(size) * (0.72 if modern else 1.0)
	(material as ShaderMaterial).set_shader_parameter("top", top)
	(material as ShaderMaterial).set_shader_parameter("bottom", baseline)
	(material as ShaderMaterial).set_shader_parameter("bands", 0.0 if modern else float(LOGO_BANDS))
	var x := CENTRE_X - _width(font, NAME, size, look.spacing) * 0.5
	if not modern:
		var pixel := size / 8.0
		_line(font, NAME, Vector2(x + pixel, baseline + pixel), size, look.spacing, SHADOW_COLOUR)
	_line(font, NAME, Vector2(x, baseline), size, look.spacing, Color.WHITE)
	var under_size: int = look.under_size
	var under_x := CENTRE_X - _width(font, UNDER, under_size, look.under_spacing) * 0.5
	_line(font, UNDER, Vector2(under_x, look.under_baseline + drop), under_size, look.under_spacing, UNDER_TINT)


# `text` from `at`, its baseline, `spacing` px between its letters.
func _line(font: Font, text: String, at: Vector2, size: int, spacing: float, colour: Color) -> void:
	for i in text.length():
		var c := text.unicode_at(i)
		draw_char(font, at, String.chr(c), size, colour)
		at.x += font.get_char_size(c, size).x + spacing


func _width(font: Font, text: String, size: int, spacing: float) -> float:
	var w := spacing * (text.length() - 1)
	for i in text.length():
		w += font.get_char_size(text.unicode_at(i), size).x
	return w


func _font(style: Level3DFont.Style) -> FontFile:
	if not _fonts.has(style):
		var modern := style == Level3DFont.Style.MODERN
		var font := (load(MODERN_FONT if modern else PIXEL_FONT) as FontFile).duplicate() as FontFile
		if not modern:
			font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font.hinting = TextServer.HINTING_NONE
			font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		_fonts[style] = font
	return _fonts[style]
