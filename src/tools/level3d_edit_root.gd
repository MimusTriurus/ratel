# The level being edited, in the Godot editor: src/tools/level3d_editor.tscn
# is this one node, and everything under it is built from the level file,
# assets/level3d/stage-N.json, when the scene opens. docs/level-editor-plan.md.
#
# The file is the source, not the scene. Entities and objects are real nodes
# of the edited scene -- owned, so that they can be picked in the viewport,
# moved with the gizmo, edited in the inspector and undone -- but saving the
# scene (Ctrl+S) writes them into the level file and leaves them out of the
# .tscn: they are disowned for the save and owned again after it. The .tscn
# stays the one node it is committed as.
#
# Under the nodes lies what the level looks like now, for reference and not
# for picking: the stage's glb with every piece the file places hidden, the
# destructible buildings, and the nav grid over the top in the map editor's
# colours. The addon (addons/level3d_editor) paints the grid and places
# nodes; without it the scene still opens, shows and saves.
@tool
class_name Level3DEditRoot
extends Node3D

const LEVEL_GLB := "res://resources/3d/jackal_stage1.glb"
const DESTRUCTIBLES := "res://resources/3d/jackal_dest_%s.glb"
# Level3DPreview's DESTRUCTIBLE_NAMES: the buildings that are glbs of their
# own, placed in level coordinates.
const DESTRUCTIBLE_NAMES: Array[String] = ["Barracks", "BarracksN", "BarracksN2",
		"BarracksN3", "Hangar_E", "Hangar_N", "Hangar_W", "Gate"]
# glTF prefixes a mesh's name with the file it came from.
const MESH_PREFIX := "jackal_stage1_"

# map_editor.gd's TYPE_COLORS, indexed by MapIO.TYPE_*, a little stronger:
# over a 3D level they sit on colour, not on the flat tiles.
const TYPE_COLORS: Array[Color] = [
	Color(0.90, 0.20, 0.20, 0.45),  # solid
	Color(0.30, 0.85, 0.35, 0.0),   # empty
	Color(0.95, 0.85, 0.20, 0.50),  # shield
	Color(0.20, 0.45, 0.95, 0.40),  # water
	Color(0.65, 0.30, 0.85, 0.45),  # swamp
	Color(0.95, 0.55, 0.15, 0.50),  # conveyor
]
const KIND_COLORS := {
	"enemy": Color(0.95, 0.25, 0.20), "gun": Color(1.0, 0.55, 0.10),
	"building": Color(0.25, 0.55, 1.0), "pickup": Color(1.0, 0.90, 0.20),
	"hazard": Color(0.75, 0.35, 1.0), "event": Color(0.30, 0.95, 0.45),
	"boss": Color(1.0, 0.25, 0.85),
}
const ROW_COLOR := Color(0.2, 1.0, 1.0)

@export var stage := 0
@export_tool_button("Reload from file", "Reload") var reload_button := reload
@export var show_nav := true:
	set(value):
		show_nav = value
		if _nav_mesh:
			_nav_mesh.visible = value
@export var show_level := true:
	set(value):
		show_level = value
		if _backdrop:
			_backdrop.visible = value
# Every entity's firing line, faint; the selected ones' are always drawn.
@export var show_all_rows := false:
	set(value):
		show_all_rows = value
		update_rows()
# What the ground under the nodes is drawn from: the stage's glb, as Blender
# built it, or the file's terrain, water and forest (Level3DTerrain.proxy),
# rebuilt as the shapes under Ground are edited.
@export_enum("glb", "file") var backdrop := "glb":
	set(value):
		backdrop = value
		_apply_backdrop()
# The proxy's cell, in metres: finer is closer to the file and slower to redo.
@export_range(0.05, 1.0, 0.05) var proxy_cell := 0.2
@export_tool_button("Rebuild ground", "Reload") var rebuild_button := rebuild_ground

# The glb's ground, water and forest, which the file's replace under
# backdrop "file"; its walls, bridge and gate stay.
const GLB_GROUND: Array[String] = ["Sand", "Beach_", "Cliff", "Terrain_", "Beyond_",
		"Forest_Floor", "ForestTree", "Ocean", "Shore_Lines", "Land_Base", "Skirt_"]
const REBUILD_DELAY := 0.5

var doc := {}
var catalog := {}
var sizes := {}             # trigger name -> footprint in tiles
var fire_rows := []         # Triggers index -> rows from the footprint's top to its firing row, + 1
var nav: Array = []         # Array[PackedByteArray], MapIO.TYPE_* per cell
var entities: Node3D
var objects: Node3D
var ground: Node3D          # Level3DEditShape per land, water and forest polygon
var selected: Array = []    # nodes whose firing line is drawn bright

var _backdrop: Node3D
var _level: Node3D
var _templates := {}        # asset -> Node3D to duplicate
var _nav_mesh: MeshInstance3D
var _nav_image: Image
var _nav_texture: ImageTexture
var _rows_mesh: MeshInstance3D
var _proxy: Node3D
var _rebuild_due := false


func _ready() -> void:
	if doc.is_empty():
		reload()
	if not Engine.is_editor_hint():
		_shot.call_deferred()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			save()
			_set_owned(false)
		NOTIFICATION_EDITOR_POST_SAVE:
			_set_owned(true)


# --- Checking by eye ------------------------------------------------------------
#
# Run as a scene rather than opened in the editor, it frames a piece of the
# level from straight above and writes it out, which is how it gets checked
# without anyone at the editor (a real window: --headless reads nothing back):
#
#     godot --path . --windowed --resolution 1280x720 src/tools/level3d_editor.tscn \
#         -- --shot out.png <x>,<z> <width m> [--file] [<entity id> ...]
#
# The entities named are drawn selected, their firing lines bright; --file
# draws the ground from the file (backdrop "file") instead of the glb.
func _shot() -> void:
	var args := OS.get_cmdline_user_args()
	var at := args.find("--shot")
	if at < 0 or args.size() < at + 4:
		return
	var centre := args[at + 2].split_floats(",")
	var picked: Array = []
	if args.has("--file"):
		backdrop = "file"
	for id in args.slice(at + 4):
		var node := entities.get_node_or_null(NodePath(id))
		if node:
			picked.append(node)
	select(picked)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = float(args[at + 3])
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.position = Vector3(centre[0], 60.0, centre[1])
	camera.rotation_degrees = Vector3(-90, 0, 0)
	camera.far = 200.0
	add_child(camera)
	camera.make_current()
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 135, 0)
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	add_child(environment)
	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(args[at + 1])
	print("Level3DEditRoot: shot %s -- %s" % [args[at + 1], "written" if error == OK else "FAILED"])
	get_tree().quit()


# --- Loading ------------------------------------------------------------------


func reload() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_templates.clear()
	selected.clear()
	doc = Level3DIO.read(stage)
	if doc.is_empty():
		return
	catalog = Level3DIO.read_catalog()
	sizes = Level3DIO.footprints()
	fire_rows = []
	for size in MapIO.load_trigger_sizes():
		fire_rows.append(size[1])

	_backdrop = Node3D.new()
	_backdrop.name = "Backdrop"
	_backdrop.visible = show_level
	add_child(_backdrop)
	_level = (load(LEVEL_GLB) as PackedScene).instantiate()
	_backdrop.add_child(_level)
	for building in DESTRUCTIBLE_NAMES:
		var scene: PackedScene = load(DESTRUCTIBLES % building)
		if scene == null:
			continue
		var root := scene.instantiate()
		_backdrop.add_child(root)
		# Frame 0 of the destruction is the building standing; the rest pose
		# is every state at once.
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player and player.has_animation("Scene"):
			player.play("Scene")
			player.seek(0.0, true)
			player.pause()

	nav = []
	for row in doc["nav"]:
		var cells := PackedByteArray()
		cells.resize((row as String).length())
		for x in cells.size():
			cells[x] = MapIO.TYPE_CHARS.get(row[x], MapIO.TYPE_EMPTY)
		nav.append(cells)
	_make_nav_mesh()

	_rows_mesh = MeshInstance3D.new()
	_rows_mesh.name = "FireRows"
	_rows_mesh.mesh = ImmediateMesh.new()
	_rows_mesh.material_override = _overlay_material(Color.WHITE, true)
	add_child(_rows_mesh)

	entities = Node3D.new()
	entities.name = "Entities"
	add_child(entities)
	for e in doc["entities"]:
		entities.add_child(Level3DEditEntity.from_doc(e, self))
	objects = Node3D.new()
	objects.name = "Objects"
	add_child(objects)
	for o in doc["objects"]:
		objects.add_child(Level3DEditObject.from_doc(o, self))
		var original := _level.get_node_or_null(NodePath(o["id"]))
		if original:
			original.visible = false
	ground = Node3D.new()
	ground.name = "Ground"
	add_child(ground)
	if doc.has("terrain"):
		for polygon in doc["terrain"]["land"]:
			ground.add_child(Level3DEditShape.from_doc(polygon, "land", self))
		for polygon in doc.get("water", []):
			ground.add_child(Level3DEditShape.from_doc(polygon, "water", self))
		for polygon in doc.get("forest", []):
			ground.add_child(Level3DEditShape.from_doc(polygon, "forest", self))
	_proxy = null
	_set_owned(true)
	update_rows()
	_apply_backdrop()


# Entities and objects belong to the edited scene, so that the editor lets
# them be picked and moved; the backdrop and the overlays do not.
func _set_owned(owned: bool) -> void:
	var scene_root := _scene_root()
	if scene_root == null:
		return
	for container in [entities, objects, ground]:
		if container == null:
			continue
		container.owner = scene_root if owned else null
		for child in container.get_children():
			child.owner = scene_root if owned else null
			# A shape's rings, which the path tools edit.
			for ring in child.get_children():
				if ring is Path3D:
					ring.owner = scene_root if owned else null


func _scene_root() -> Node:
	if not Engine.is_editor_hint():
		return null
	var edited := get_tree().edited_scene_root if is_inside_tree() else null
	return edited if edited and (edited == self or edited.is_ancestor_of(self)) else null


# A copy of what the stage's glb places for an asset: its first piece, at the
# origin. The instances of collections (Bunker, SandbagNest, ...) come whole.
func template(asset: String) -> Node3D:
	if _templates.has(asset):
		return _templates[asset]
	var found: Node3D = null
	for child in _level.get_children():
		var node := child as Node3D
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh and mesh.resource_name.trim_prefix(MESH_PREFIX) == asset:
				found = node
				break
		elif String(node.name).begins_with(asset):
			found = node
			break
	var copy: Node3D = null
	if found:
		copy = found.duplicate() as Node3D
		copy.transform = Transform3D.IDENTITY
		copy.visible = true
	_templates[asset] = copy
	return copy


# --- The grid -----------------------------------------------------------------


func grid() -> Dictionary:
	return doc["grid"]


func tile_m() -> float:
	return float(grid()["tile_px"]) * float(grid()["m_per_px"])


# The tile under a point of the level, or (-1, -1) off the map.
func tile_at(x: float, z: float) -> Vector2i:
	var p := Level3DIO.to_map(grid(), Vector2(x, z)) / float(grid()["tile_px"])
	var cell := Vector2i(floori(p.x), floori(p.y))
	if cell.x < 0 or cell.y < 0 or cell.y >= nav.size() or cell.x >= (nav[0] as PackedByteArray).size():
		return Vector2i(-1, -1)
	return cell


func cell_type(cell: Vector2i) -> int:
	return nav[cell.y][cell.x]


# The group whose cells include this one, or -1: what a building put down on
# it would set off (MapIO.GROUP_PROBES).
func group_at(cell: Vector2i) -> int:
	for g in doc["groups"]:
		for c in g["cells"]:
			if int(c[0]) == cell.x and int(c[1]) == cell.y:
				return int(g["index"])
	return -1


# Sets cells[i] to types[i]: the painting brush's do and undo both.
func set_cells(cells: Array, types: Array) -> void:
	for i in cells.size():
		var cell: Vector2i = cells[i]
		nav[cell.y][cell.x] = types[i]
		_nav_image.set_pixelv(cell, TYPE_COLORS[types[i]])
	_nav_texture.update(_nav_image)


func _make_nav_mesh() -> void:
	var height := nav.size()
	var width := (nav[0] as PackedByteArray).size()
	_nav_image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			_nav_image.set_pixel(x, y, TYPE_COLORS[nav[y][x]])
	_nav_texture = ImageTexture.create_from_image(_nav_image)
	var size := Vector2(width, height) * tile_m()
	var plane := PlaneMesh.new()
	plane.size = size
	_nav_mesh = MeshInstance3D.new()
	_nav_mesh.name = "Nav"
	_nav_mesh.mesh = plane
	_nav_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var corner := Level3DIO.to_level(grid(), Vector2.ZERO)
	_nav_mesh.position = Vector3(corner.x + size.x * 0.5, 0.02, corner.y + size.y * 0.5)
	var material := _overlay_material(Color.WHITE, true)
	material.albedo_texture = _nav_texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_nav_mesh.material_override = material
	_nav_mesh.visible = show_nav
	add_child(_nav_mesh)


static func _overlay_material(color: Color, see_through: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = see_through
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material


# The line the top of the frame crosses when an entity fires: the bottom of its
# footprint, or four rows short of it for a boss (MapIO.EARLY_BOSS_TRIGGERS).
# The whole row fires at once, whatever the x, so the line crosses the map.
func update_rows() -> void:
	if _rows_mesh == null:
		return
	var mesh := _rows_mesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var lines: Array = []
	for node in (entities.get_children() if entities else []):
		var entity := node as Level3DEditEntity
		if entity == null:
			continue
		var bright := selected.has(entity)
		if bright or show_all_rows:
			lines.append([entity.fire_z(), ROW_COLOR if bright else Color(ROW_COLOR, 0.25)])
	if lines.is_empty():
		return
	var corner := Level3DIO.to_level(grid(), Vector2.ZERO)
	var width := (nav[0] as PackedByteArray).size() * tile_m()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for line in lines:
		mesh.surface_set_color(line[1])
		mesh.surface_add_vertex(Vector3(corner.x, 0.05, line[0]))
		mesh.surface_add_vertex(Vector3(corner.x + width, 0.05, line[0]))
	mesh.surface_end()


func select(nodes: Array) -> void:
	selected = nodes
	update_rows()


# --- The ground -----------------------------------------------------------------


func _apply_backdrop() -> void:
	if _level == null:
		return
	var from_file := backdrop == "file" and doc.has("terrain")
	for child in _level.get_children():
		var name := String(child.name)
		if GLB_GROUND.any(func(prefix): return name.begins_with(prefix)):
			(child as Node3D).visible = not from_file
	if from_file and _proxy == null:
		rebuild_ground()
	if _proxy:
		_proxy.visible = from_file


# Level3DTerrain.proxy of the ground as the shapes have it now.
func rebuild_ground() -> void:
	_rebuild_due = false
	if _backdrop == null or not doc.has("terrain"):
		return
	var started := Time.get_ticks_msec()
	if _proxy:
		_backdrop.remove_child(_proxy)
		_proxy.queue_free()
	_proxy = Level3DTerrain.proxy(to_doc(), proxy_cell)
	_proxy.visible = backdrop == "file"
	_backdrop.add_child(_proxy)
	print("Level3DEditRoot: ground rebuilt in %d ms" % (Time.get_ticks_msec() - started))


# A shape was edited: the proxy is redone once the edits stop for a moment,
# not on every step of a drag.
func ground_changed() -> void:
	if backdrop != "file" or _rebuild_due or not is_inside_tree():
		return
	_rebuild_due = true
	get_tree().create_timer(REBUILD_DELAY).timeout.connect(func():
		if _rebuild_due:
			rebuild_ground())


# --- Saving -------------------------------------------------------------------


# The file as the nodes say it is now: the grid painted, the entities in the
# order they stand under Entities -- which is the order the game spawns a
# row's in -- and the objects in theirs. A node with no id, or with another's
# (a duplicate), is given the next free one.
func to_doc() -> Dictionary:
	var out := doc.duplicate()
	var rows: Array = []
	for cells in nav:
		var chars := ""
		for t in cells as PackedByteArray:
			chars += MapIO.TYPE_CHAR[t]
		rows.append(chars)
	out["nav"] = rows

	var taken := {}
	var list: Array = []
	for node in entities.get_children():
		if node is Level3DEditEntity:
			list.append((node as Level3DEditEntity).to_doc())
	var listed_objects: Array = []
	for node in objects.get_children():
		if node is Level3DEditObject:
			listed_objects.append((node as Level3DEditObject).to_doc())
	_assign_ids(list, "type", taken)
	_assign_ids(listed_objects, "asset", taken)
	out["entities"] = list
	out["objects"] = listed_objects
	if doc.has("terrain"):
		var shapes := {"land": [], "water": [], "forest": []}
		for node in ground.get_children():
			if node is Level3DEditShape:
				var shape := node as Level3DEditShape
				(shapes[shape.kind] as Array).append(shape.to_doc())
		for kind in shapes:
			_assign_ids(shapes[kind], "", taken, kind)
		var terrain: Dictionary = (doc["terrain"] as Dictionary).duplicate()
		terrain["land"] = shapes["land"]
		out["terrain"] = terrain
		out["water"] = shapes["water"]
		out["forest"] = shapes["forest"]
	return out


static func _assign_ids(items: Array, key: String, taken: Dictionary, fixed_stem := "") -> void:
	var pending: Array = []
	for item in items:
		var id: String = item["id"]
		if id == "" or taken.has(id):
			pending.append(item)
		else:
			taken[id] = true
	for item in pending:
		var stem := fixed_stem if fixed_stem != "" else (item[key] as String).to_lower()
		var n := 0
		while taken.has("%s_%d" % [stem, n]):
			n += 1
		item["id"] = "%s_%d" % [stem, n]
		taken[item["id"]] = true


func save() -> Error:
	if doc.is_empty():
		return FAILED
	var out := to_doc()
	var error := Level3DIO.save(out)
	if error == OK:
		doc = out
		# Give the nodes the ids the save settled on.
		var list: Array = out["entities"]
		var i := 0
		for node in entities.get_children():
			if node is Level3DEditEntity:
				(node as Level3DEditEntity).entity_id = list[i]["id"]
				i += 1
		list = out["objects"]
		i = 0
		for node in objects.get_children():
			if node is Level3DEditObject:
				(node as Level3DEditObject).object_id = list[i]["id"]
				i += 1
		if out.has("terrain"):
			var settled := {"land": out["terrain"]["land"], "water": out["water"], "forest": out["forest"]}
			var at := {"land": 0, "water": 0, "forest": 0}
			for node in ground.get_children():
				if node is Level3DEditShape:
					var shape := node as Level3DEditShape
					shape.shape_id = settled[shape.kind][at[shape.kind]]["id"]
					at[shape.kind] += 1
		print("Level3DEditRoot: wrote %s" % Level3DIO.path(stage))
	return error


func check() -> PackedStringArray:
	return Level3DIO.check(to_doc(), catalog)


# FlowField.build over the painted grid, into the level's own dirs-N.dat. It
# takes a while: every cell of the field to every other.
func build_flow_field() -> Error:
	var built := Stage.new()
	Level3DIO.load_stage(to_doc(), built, MapIO.load_trigger_sizes())
	FlowField.build(built)
	return FlowField.save(stage, built, Level3DIO.DIR)
