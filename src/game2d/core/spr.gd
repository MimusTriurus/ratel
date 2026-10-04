# Equivalent of Slick2D's Image: a sub-rectangle of a packed sheet, or a
# standalone texture produced by getFlippedCopy().
class_name Spr
extends RefCounted

var tex: Texture2D
var region: Rect2
var w: float
var h: float
# Slick's Image carries its own alpha; drawBackground() relies on that for the
# animated water tiles, so it is modelled here rather than passed per draw.
var alpha: float = 1.0

func _init(p_tex: Texture2D, p_region: Rect2) -> void:
	tex = p_tex
	region = p_region
	w = p_region.size.x
	h = p_region.size.y


# Slick: Image.getSubImage(x, y, w, h)
func sub_image(x: int, y: int, sw: int, sh: int) -> Spr:
	return Spr.new(tex, Rect2(region.position + Vector2(x, y), Vector2(sw, sh)))


# Slick: Image.getFlippedCopy(flipHorizontal, flipVertical).
# Bakes a real flipped texture so the draw path never needs flip flags.
func flipped_copy(fh: bool, fv: bool) -> Spr:
	var src: Image = tex.get_image()
	if src.is_compressed():
		src.decompress()
	var img := Image.create_empty(int(w), int(h), false, Image.FORMAT_RGBA8)
	img.blit_rect(src, region, Vector2i.ZERO)
	if fh:
		img.flip_x()
	if fv:
		img.flip_y()
	return Spr.new(ImageTexture.create_from_image(img), Rect2(0, 0, w, h))


# Not in Slick: a baked copy with every coloured pixel whose hue is within
# [min_hue, max_hue] degrees turned by shift degrees, black, white and grey left
# alone. How the second player's jeep is made out of the first's, there being
# no second jeep in the sheets.
func hue_shifted_copy(min_hue: float, max_hue: float, shift: float) -> Spr:
	var src: Image = tex.get_image()
	if src.is_compressed():
		src.decompress()
	var img := Image.create_empty(int(w), int(h), false, Image.FORMAT_RGBA8)
	img.blit_rect(src, region, Vector2i.ZERO)
	for py in img.get_height():
		for px in img.get_width():
			var c := img.get_pixel(px, py)
			var hue := c.h * 360.0
			if c.a > 0.0 and c.s > 0.2 and hue >= min_hue and hue <= max_hue:
				c.h = fposmod(hue + shift, 360.0) / 360.0
				img.set_pixel(px, py, c)
	return Spr.new(ImageTexture.create_from_image(img), Rect2(0, 0, w, h))
