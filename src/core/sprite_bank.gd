# Name-addressed lookup over the per-object sprite atlases.
#
# Slick's XMLPackedSheet -- and Atlas, which ports it -- is one PNG plus one
# index, so every call site had to know which sheet held the sprite it wanted:
# load_sprites() opened sprites-1..9 and threaded pack1..pack9 through 400
# lines. That coupled the file layout to the code, so regrouping the art meant
# editing the loader.
#
# The atlases are per object now (assets/images/sprites/brown-tank.png), and
# this resolves a sprite name against all of them through the generated
# index.xml. Textures are loaded on first use, so opening 140 atlases costs one
# XML parse and nothing else until something is drawn.
#
# Atlas itself is unchanged and still used for the tile sheets, the large
# cutscene images and the font, none of which are per-object.
class_name SpriteBank
extends RefCounted

var _entries: Dictionary = {}    # String -> [file: String, region: Rect2]
var _textures: Dictionary = {}   # String -> Texture2D
var _sprites: Dictionary = {}    # String -> Spr
var _dir: String


func _init(dir_path: String) -> void:
	_dir = dir_path
	var p := XMLParser.new()
	var index := dir_path + "index.xml"
	if p.open(index) != OK:
		push_error("SpriteBank: missing index %s" % index)
		return
	var file := ""
	while p.read() == OK:
		if p.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		match p.get_node_name():
			"atlas":
				file = p.get_named_attribute_value("file")
			"sprite":
				_entries[p.get_named_attribute_value("name")] = [
					file,
					Rect2(
						float(p.get_named_attribute_value("x")),
						float(p.get_named_attribute_value("y")),
						float(p.get_named_attribute_value("width")),
						float(p.get_named_attribute_value("height")))]


# Returns null for an unknown name, matching Atlas.get_sprite: the extra large
# image loader walks its packs until one returns null, and Slick behaved the
# same way.
func get_sprite(name: String) -> Spr:
	var cached = _sprites.get(name)
	if cached != null:
		return cached
	var entry = _entries.get(name)
	if entry == null:
		return null
	var s := Spr.new(_texture(entry[0]), entry[1])
	_sprites[name] = s
	return s


func _texture(file: String) -> Texture2D:
	var tex = _textures.get(file)
	if tex == null:
		tex = load(_dir + file)
		if tex == null:
			push_error("SpriteBank: missing texture %s" % (_dir + file))
		_textures[file] = tex
	return tex


func sprite_count() -> int:
	return _entries.size()
