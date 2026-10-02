# The 3D preview's bitmap font: Press Start 2P (assets/fonts/, SIL Open Font
# License 1.1), baked by tools/font3d_bake.py into assets/images/font3d.png in
# the layout of the game's font.png, a 32x32 cell a glyph, white letters with
# a shadow under them. The game's font is Konami's, as the rest of its art
# is, and had no "+" or "/"; this one is free and has them. The 2D game keeps
# the game's own.
#
# Every 3D overlay -- the HUD, the pops, the calls, the hints, the banners,
# the summary -- takes its glyphs from here, so the font is changed in one
# place, and draws them with `filter()`: the HUD's 2048x1152 layout is drawn
# into a smaller window, and with the canvas' nearest filter the font's
# pixels came out two screen pixels wide and three by turns, which reads as
# ragged steps. Smoothed (Level3DSettings.font_smooth), they are sampled
# filtered from the sheet's mipmaps: the same square letters, their edges
# soft at any window size. The icons stay nearest either way.
class_name Level3DFont
extends RefCounted

const PNG := "res://assets/images/font3d.png"
const XML := "res://assets/images/font3d.xml"
# What the sheet holds: tools/font3d_bake.py's CHARS.
const CHARS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ.,'-0123456789©!:()&`\" +/?%#"
# The two shadows: WHITE's black, GRAY's grey.
const WHITE := "black"
const GRAY := "gray"

# Level3DSettings.font_smooth: filtered rather than nearest.
static var smooth := true
static var _atlas: Atlas
static var _sets := {}           # colour -> {code point -> Spr}


# The glyphs of `colour`, code point -> Spr; lower case is drawn as upper.
static func glyphs(colour := WHITE) -> Dictionary:
	if _sets.has(colour):
		return _sets[colour]
	if _atlas == null:
		_atlas = Atlas.new(PNG, XML)
	var out := {}
	for i in CHARS.length():
		var c := CHARS.unicode_at(i)
		out[c] = _atlas.get_sprite("font-%s-%s.png" % [colour, name_of(c)])
		var lower := String.chr(c).to_lower().unicode_at(0)
		if lower != c:
			out[lower] = out[c]
	# The game's font has the copyright sign under @ too (Main._character_name).
	out[0x40] = out[0xA9]
	_sets[colour] = out
	return out


# The filter the font's glyphs are drawn with, for a CanvasItem that draws
# them and nothing else that wants nearest.
static func filter() -> CanvasItem.TextureFilter:
	return CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if smooth else CanvasItem.TEXTURE_FILTER_NEAREST


# A glyph's name in the sheet: font3d_bake.py's NAMES.
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
		_: return String.chr(c)
