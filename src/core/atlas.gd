# Equivalent of Slick2D's XMLPackedSheet: a PNG plus an XML sprite index.
class_name Atlas
extends RefCounted

var tex: Texture2D
var sprites: Dictionary = {}   # String -> Spr

func _init(png_path: String, xml_path: String) -> void:
	tex = load(png_path)
	if tex == null:
		push_error("Atlas: missing texture %s" % png_path)
		return
	var p := XMLParser.new()
	if p.open(xml_path) != OK:
		push_error("Atlas: missing index %s" % xml_path)
		return
	while p.read() == OK:
		if p.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		if p.get_node_name() != "sprite":
			continue
		var name := p.get_named_attribute_value("name")
		var r := Rect2(
			float(p.get_named_attribute_value("x")),
			float(p.get_named_attribute_value("y")),
			float(p.get_named_attribute_value("width")),
			float(p.get_named_attribute_value("height")))
		sprites[name] = Spr.new(tex, r)


# Slick returns null for an unknown name; loadExtraLargeImage relies on that.
func get_sprite(name: String) -> Spr:
	return sprites.get(name)
