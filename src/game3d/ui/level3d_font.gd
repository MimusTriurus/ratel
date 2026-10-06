# The 3D preview's fonts (Level3DSettings.font), baked by tools/font3d_bake.py
# out of free fonts in assets/fonts/, each with its SIL Open Font License:
#
#   CLASSIC         Press Start 2P, an 8x8 pixel font, drawn sharp
#   CLASSIC_SMOOTH  the same, drawn filtered
#   MODERN          Black Ops One, a stencilled military face, its letters
#                   their own widths
#
# The game's own font is Konami's, as the rest of its art is, and had no "+"
# or "/"; these are free and have them. The 2D game keeps the game's own.
#
# Every 3D overlay -- the HUD, the pops, the calls, the hints, the banners,
# the summary -- writes through `draw` and measures through `width`, so the
# font is changed in one place. A glyph is `g` px tall: classic glyphs are
# `g` wide as well, modern ones as wide as each letter is. Both are white
# with a shadow under them, WHITE's black and GRAY's grey.
#
# `filter()` is what a CanvasItem drawing them is to be drawn with. The HUD's
# 2048x1152 layout is drawn into a smaller window, and with the canvas'
# nearest filter the classic font's pixels came out two screen pixels wide
# and three by turns, ragged steps; smoothed, and modern always, they are
# sampled filtered from the sheet's mipmaps. The icons stay nearest either
# way, on CanvasItems of their own.
class_name Level3DFont
extends RefCounted

enum Style { CLASSIC, CLASSIC_SMOOTH, MODERN }

const CLASSIC_PNG := "res://assets/images/font3d.png"
const CLASSIC_XML := "res://assets/images/font3d.xml"
const MODERN_PNG := "res://assets/images/font3d_modern.png"
const MODERN_XML := "res://assets/images/font3d_modern.xml"
const MODERN_JSON := "res://assets/images/font3d_modern.json"
# What the sheets hold: tools/font3d_bake.py's CHARS.
const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ.,'-0123456789©!:()&`\" +/?%#$"
const WHITE := "black"
const GRAY := "gray"

# Level3DSettings.font.
static var style := Style.CLASSIC_SMOOTH
# A sheet each: {"glyphs": {colour: {code point -> Spr}}, "advances":
# {code point -> px} or empty for a classic one, "cell": its glyphs' height}.
static var _sheets := {}


static func filter() -> CanvasItem.TextureFilter:
	return CanvasItem.TEXTURE_FILTER_NEAREST if style == Style.CLASSIC \
			else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


# How wide `text` is at `g` px tall.
static func width(text: String, g: float) -> float:
	var sheet := _sheet()
	var advances: Dictionary = sheet.advances
	if advances.is_empty():
		return g * text.length()
	var w := 0.0
	for i in text.length():
		w += advances.get(text.unicode_at(i), 0.0) * g / sheet.cell
	return w


# `text` from `x`, `y` its top, `g` px tall, in `colour`'s shadow, tinted;
# returns where it ends.
static func draw(on: CanvasItem, text: String, x: float, y: float, g: float, colour := WHITE,
		tint := Color.WHITE) -> float:
	var sheet := _sheet()
	var glyphs: Dictionary = sheet.glyphs[colour]
	var advances: Dictionary = sheet.advances
	var unit: float = g / sheet.cell
	for i in text.length():
		var c := text.unicode_at(i)
		var sp: Spr = glyphs.get(c)
		if advances.is_empty():
			if sp != null:
				on.draw_texture_rect_region(sp.tex, Rect2(x, y, g, g), sp.region, tint)
			x += g
		else:
			if sp != null:
				on.draw_texture_rect_region(sp.tex, Rect2(x, y, sp.w * unit, g), sp.region, tint)
			x += advances.get(c, 0.0) * unit
	return x


static func _sheet() -> Dictionary:
	var modern := style == Style.MODERN
	if _sheets.has(modern):
		return _sheets[modern]
	var atlas := Atlas.new(MODERN_PNG if modern else CLASSIC_PNG, MODERN_XML if modern else CLASSIC_XML)
	var sheet := {"glyphs": {}, "advances": {}, "cell": 32.0}
	var by_name := {}
	if modern:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MODERN_JSON))
		sheet.cell = float(data.cell)
		by_name = data.advances
	for colour in [WHITE, GRAY]:
		var out := {}
		for i in CHARS.length():
			var c := CHARS.unicode_at(i)
			var name := name_of(c)
			out[c] = atlas.get_sprite("font-%s-%s.png" % [colour, name])
			if modern:
				sheet.advances[c] = float(by_name.get(name, 0.0))
		_lower_and_at(out)
		sheet.glyphs[colour] = out
	_lower_and_at(sheet.advances)
	_sheets[modern] = sheet
	return sheet


# Lower case drawn as upper, and the copyright sign under @ as well, as the
# game's font has it (Main._character_name).
static func _lower_and_at(table: Dictionary) -> void:
	for c in table.keys():
		var lower := String.chr(c).to_lower().unicode_at(0)
		if lower != c:
			table[lower] = table[c]
	if table.has(0xA9):
		table[0x40] = table[0xA9]


# A glyph's name in the sheets: font3d_bake.py's NAMES.
static func name_of(c: int) -> String:
	match c:
		0x2E: return "period"
		0x2C: return "comma"
		0x27: return "apostrophe"
		0x21: return "exclamation"
		0x2D: return "hyphen"
		0xA9: return "copyright"
		0x20: return "space"
		0x3A: return "colon"
		0x28: return "left-paren"
		0x29: return "right-paren"
		0x26: return "ampersand"
		0x60: return "left-quote"
		0x22: return "right-quote"
		0x2B: return "plus"
		0x2F: return "slash"
		0x3F: return "question"
		0x25: return "percent"
		0x23: return "hash"
		0x24: return "dollar"
		_: return String.chr(c)
