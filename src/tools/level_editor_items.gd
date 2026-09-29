# What the level editor (level_editor.gd) draws over the ground: the
# entities, the objects, the nav grid and the line the selected entity fires
# on. The level file is the truth; this is its picture, rebuilt an item at a
# time when one changes.
#
#   entity  its footprint, in its kind's colour, with its id over it. It sits
#           on the game's grid: a trigger is a tile.
#   object  what the stage's glb draws for its asset -- a copy of the first
#           piece of it in resources/3d/jackal_stage1.glb, which has one of
#           every asset the catalogue has -- or a magenta box for one it has
#           not. Its height in the file is over the ground, as the builder
#           has it.
#   wall    its box in its concrete, with its merlons; a bridge its deck,
#           curbs and piers (Level3DStructures). The gate is an object, and
#           is drawn as stage 1's frame, moved to where it stands.
#   nav     the grid in the map editor's colours, drawn through everything.
#   row     where the top of the frame is when the selected entity fires:
#           the bottom of its footprint, and the whole row fires at once.
class_name LevelEditorItems
extends Node3D

const LIBRARY := "res://resources/3d/jackal_stage1.glb"
const MESH_PREFIX := "jackal_stage1_"
# Level3DPreview.DESTRUCTIBLE_PATH: a building that is blown up.
const DESTRUCTIBLE_PATH := "res://resources/3d/jackal_dest_%s.glb"

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
const CONCRETE := {"wall": Color(0.62, 0.62, 0.6), "side": Color(0.78, 0.77, 0.74)}
const DECK := Color(0.45, 0.45, 0.44)
# The pieces of stage 1's gate frame in its glb, which a Gate object is drawn
# as (the catalogue's "base" is its collection in the base's .blend).
const GATE_FRAME_PREFIXES: Array[String] = ["GatePost", "Gate_Sill"]
const SELECTED := Color(1.0, 1.0, 1.0)
# How near an object's middle a click has to be to pick it.
const PICK := 0.35

var doc := {}
var catalog := {}
var sizes := {}                     # trigger name -> footprint in tiles
var fire_rows := []                 # Triggers index -> rows from the top of the footprint to its firing row, + 1
var height_at: Callable             # (Vector2) -> ground height, the picture's
var rise_at: Callable               # (Vector2) -> the rise, the builder's lift

var _entities := {}                 # id -> Node3D
var _objects := {}                  # id -> Node3D
var _structures := {}               # id -> Node3D, walls and bridges
var _templates := {}
var _library: Node3D
var _nav_mesh: MeshInstance3D
var _nav_image: Image
var _nav_texture: ImageTexture
var _row_mesh: MeshInstance3D
# The picked items' ids, the last the one the panel shows and whose row is
# drawn.
var _selected: Array = []


func setup(level: Dictionary, ground_height: Callable, ground_rise: Callable) -> void:
	doc = level
	height_at = ground_height
	rise_at = ground_rise
	if catalog.is_empty():
		catalog = Level3DIO.read_catalog()
		sizes = Level3DIO.footprints()
		for size in MapIO.load_trigger_sizes():
			fire_rows.append(size[1])
	for child in get_children():
		if child != _library:
			remove_child(child)
			child.queue_free()
	_entities.clear()
	_objects.clear()
	_structures.clear()
	_nav_mesh = null
	_row_mesh = MeshInstance3D.new()
	_row_mesh.mesh = ImmediateMesh.new()
	_row_mesh.material_override = _overlay(Color.WHITE, true)
	add_child(_row_mesh)
	for e in doc["entities"]:
		update_entity(e)
	for o in doc["objects"]:
		update_object(o)
	for w in doc.get("walls", []):
		update_wall(w)
	for b in doc.get("bridges", []):
		update_bridge(b)
	_selected = []
	active_point = -1
	for path in doc.get("paths", []):
		update_path(path)


# --- The grid ------------------------------------------------------------------


func grid() -> Dictionary:
	return doc["grid"]


func tile_m() -> float:
	return float(grid()["tile_px"]) * float(grid()["m_per_px"])


func rows() -> int:
	return int(grid()["height"])


func columns() -> int:
	return int(grid()["width"])


# The tile under a point of the level, or (-1, -1) off the map.
func tile_at(p: Vector2) -> Vector2i:
	var m := Level3DIO.to_map(grid(), p) / float(grid()["tile_px"])
	var cell := Vector2i(floori(m.x), floori(m.y))
	if cell.x < 0 or cell.y < 0 or cell.x >= columns() or cell.y >= rows():
		return Vector2i(-1, -1)
	return cell


func footprint(type: String) -> Vector2i:
	return sizes.get(type, Vector2i.ONE)


# Where an entity of `type` goes when put down at `p`: the middle of the
# footprint that covers the tiles round it, as the file holds it.
func snap_entity(type: String, p: Vector2) -> Vector2:
	var size := footprint(type)
	var tile := Level3DIO.entity_tile(grid(), size, p)
	tile = tile.clamp(Vector2i.ZERO, Vector2i(columns(), rows()) - size)
	var at := Level3DIO.entity_pos(grid(), size, tile)
	return Vector2(Level3DIO.round_mm(at.x), Level3DIO.round_mm(at.y))


func entity_tile(e: Dictionary) -> Vector2i:
	return Level3DIO.entity_tile(grid(), footprint(e["type"]),
			Vector2(float(e["pos"][0]), float(e["pos"][1])))


# The group whose cells include this one, or -1: what a building put down on
# it would set off (MapIO.GROUP_PROBES).
func group_at(cell: Vector2i) -> int:
	for g in doc["groups"]:
		for c in g["cells"]:
			if int(c[0]) == cell.x and int(c[1]) == cell.y:
				return int(g["index"])
	return -1


# The group a building of `type` at `tile` probes for, or -1 for a type that
# probes for none.
func probed_group(type: String, tile: Vector2i) -> int:
	var index: int = MapIO.trigger_constants().get(type, -1)
	if not MapIO.GROUP_PROBES.has(index):
		return -1
	return group_at(tile + MapIO.GROUP_PROBES[index])


# --- Entities -------------------------------------------------------------------


func find_entity(id: String) -> Dictionary:
	for e in doc["entities"]:
		if e["id"] == id:
			return e
	return {}


func find_object(id: String) -> Dictionary:
	for o in doc["objects"]:
		if o["id"] == id:
			return o
	return {}


func kind_of(type: String) -> String:
	return catalog["entities"].get(type, {}).get("kind", "enemy")


func update_entity(e: Dictionary) -> void:
	var id: String = e["id"]
	var node: Node3D = _entities.get(id)
	if node == null:
		node = Node3D.new()
		var box := MeshInstance3D.new()
		box.name = "Box"
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(box)
		var label := Label3D.new()
		label.name = "Label"
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.fixed_size = true
		label.pixel_size = 0.0008
		label.font_size = 28
		label.outline_size = 8
		label.render_priority = 3
		node.add_child(label)
		add_child(node)
		_entities[id] = node
	var colour: Color = KIND_COLORS.get(kind_of(e["type"]), Color.WHITE)
	var bright := is_selected(id)
	var size := Vector2(footprint(e["type"])) * tile_m()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.35, size.y)
	var box := node.get_node("Box") as MeshInstance3D
	box.mesh = mesh
	box.position = Vector3(0, 0.175, 0)
	box.material_override = _overlay(Color(SELECTED if bright else colour, 0.55 if bright else 0.35), false)
	var label := node.get_node("Label") as Label3D
	var difficulty: Array = e["difficulty"]
	label.text = id + ("" if difficulty.size() == 2 else " (%s)" % difficulty[0] if difficulty.size() == 1 else " (none)")
	label.modulate = SELECTED if bright else colour.lightened(0.4)
	label.position = Vector3(0, 0.6, 0)
	var p := Vector2(float(e["pos"][0]), float(e["pos"][1]))
	node.position = Vector3(p.x, height_at.call(p), p.y)
	if id == selected():
		_draw_row(e)


func remove_entity(id: String) -> void:
	var node: Node3D = _entities.get(id)
	if node:
		node.queue_free()
		_entities.erase(id)
	_unselect(id)


# The entity whose footprint is under `p`, the smallest of them if several.
func entity_under(p: Vector2) -> String:
	var best := ""
	var best_area := INF
	for e in doc["entities"]:
		var size := Vector2(footprint(e["type"])) * tile_m()
		var centre := Vector2(float(e["pos"][0]), float(e["pos"][1]))
		if absf(p.x - centre.x) <= size.x * 0.5 and absf(p.y - centre.y) <= size.y * 0.5:
			if size.x * size.y < best_area:
				best_area = size.x * size.y
				best = e["id"]
	return best


# --- Objects --------------------------------------------------------------------


func update_object(o: Dictionary) -> void:
	var id: String = o["id"]
	var node: Node3D = _objects.get(id)
	if node == null or node.get_meta("asset", "") != o["asset"]:
		if node:
			node.queue_free()
		node = Node3D.new()
		node.set_meta("asset", o["asset"])
		var model := _template(o["asset"])
		node.add_child(model.duplicate() if model else _marker())
		add_child(node)
		_objects[id] = node
	var p: Array = o["pos"]
	var at := Vector2(float(p[0]), float(p[2]))
	node.position = Vector3(at.x, float(p[1]) + rise_at.call(at), at.y)
	node.basis = Basis(Vector3.UP, deg_to_rad(float(o["yaw"]))).scaled(Vector3.ONE * float(o["scale"]))
	var ring: Node3D = node.get_node_or_null("Picked")
	if is_selected(id) and ring == null:
		node.add_child(_picked_ring())
	elif not is_selected(id) and ring:
		ring.free()


func remove_object(id: String) -> void:
	var node: Node3D = _objects.get(id)
	if node:
		node.queue_free()
		_objects.erase(id)
	_unselect(id)


func object_under(p: Vector2) -> String:
	var best := ""
	var best_d := PICK
	for o in doc["objects"]:
		var d := p.distance_to(Vector2(float(o["pos"][0]), float(o["pos"][2])))
		var reach := PICK * maxf(float(o["scale"]), 1.0)
		if d < reach and d < best_d + (reach - PICK):
			best_d = d
			best = o["id"]
	return best


# The piece the stage's glb draws for an asset, at the origin. The library is
# stage 1's glb, loaded the first time an object needs it, whatever level is
# open.
func _template(asset: String) -> Node3D:
	if _templates.has(asset):
		return _templates[asset]
	if _library == null:
		var scene: PackedScene = load(LIBRARY)
		_library = scene.instantiate() if scene else Node3D.new()
		_library.visible = false
		_library.process_mode = Node.PROCESS_MODE_DISABLED
		add_child(_library)
	var found: Node3D = null
	var asset_entry: Dictionary = catalog["assets"].get(asset, {})
	if asset_entry.has("base"):
		# Built of the base's pieces rather than placed: the frame's pieces in
		# the glb, round the catalogue's pivot.
		var pivot := Vector2(float(asset_entry["pivot"][0]), float(asset_entry["pivot"][1]))
		var frame := Node3D.new()
		for child in _library.get_children():
			var node := child as Node3D
			if node and GATE_FRAME_PREFIXES.any(func(p): return String(node.name).begins_with(p)):
				var piece := node.duplicate() as Node3D
				piece.position -= Vector3(pivot.x, 0.0, pivot.y)
				frame.add_child(piece)
		_templates[asset] = frame
		return frame
	if asset_entry.has("destructible"):
		# A building the preview blows up, which no level's glb has: its
		# jackal_dest_<kind>.glb, as it stands at rest -- the intact building,
		# the blast and the ruins shrunk to nothing -- round the pivot.
		var scene: PackedScene = load(DESTRUCTIBLE_PATH % asset_entry["destructible"])
		var building := Node3D.new()
		if scene:
			var pivot := Vector2(float(asset_entry["pivot"][0]), float(asset_entry["pivot"][1]))
			var root := scene.instantiate() as Node3D
			for player in root.find_children("*", "AnimationPlayer", true, false):
				player.free()
			root.position = -Vector3(pivot.x, 0.0, pivot.y)
			building.add_child(root)
		_templates[asset] = building
		return building
	for child in _library.get_children():
		var node := child as Node3D
		if node is MeshInstance3D:
			var mesh := (node as MeshInstance3D).mesh
			if mesh and mesh.resource_name.trim_prefix(MESH_PREFIX) == asset:
				found = node
				break
		elif node and String(node.name).begins_with(asset):
			found = node
			break
	var copy: Node3D = null
	if found:
		copy = found.duplicate() as Node3D
		copy.transform = Transform3D.IDENTITY
		copy.visible = true
	_templates[asset] = copy
	return copy


func _marker() -> Node3D:
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE * tile_m()
	marker.mesh = box
	marker.position.y = tile_m() * 0.5
	marker.material_override = _overlay(Color(1, 0, 1, 0.6), false)
	return marker


func _picked_ring() -> Node3D:
	var ring := MeshInstance3D.new()
	ring.name = "Picked"
	var torus := TorusMesh.new()
	torus.inner_radius = PICK * 0.9
	torus.outer_radius = PICK
	torus.ring_segments = 4
	ring.mesh = torus
	ring.material_override = _overlay(SELECTED, true)
	ring.position.y = 0.05
	return ring


# --- Walls and bridges -------------------------------------------------------------


const STRUCTURE_KEYS: Array[String] = ["walls", "bridges", "paths"]
# A point's handle on a picked wall, path or bridge: how near a click has to
# be to take it, and how big it is drawn.
const HANDLE_PICK := 0.4
const HANDLE_SIZE := 0.32
const HANDLE := Color(1.0, 0.85, 0.2)
const HANDLE_ACTIVE := Color(1.0, 0.35, 0.2)

# The picked path's point whose handle was taken last, or -1: what Del
# deletes before the path itself.
var active_point := -1


func find_structure(id: String) -> Dictionary:
	for key in STRUCTURE_KEYS:
		for s in doc.get(key, []):
			if s["id"] == id:
				return s
	return {}


# Which list of the file a wall, bridge or path is in.
func structure_key(s: Dictionary) -> String:
	return "paths" if Level3DStructures.is_path(s) else "walls" if s.has("style") else "bridges"


func is_wall(s: Dictionary) -> bool:
	return s.has("style")


func update_structure(s: Dictionary) -> void:
	match structure_key(s):
		"paths":
			update_path(s)
		"walls":
			update_wall(s)
		_:
			update_bridge(s)


# A path's wall as the builder builds it: each run a band `width` across and
# `height` up from the rise under each of its points, with its merlons; and,
# picked, a handle on each of its points.
func update_path(path: Dictionary) -> void:
	var node := _structure_node(path["id"])
	var bright := is_selected(path["id"])
	var colour: Color = SELECTED.lerp(CONCRETE[path["kind"]], 0.35) if bright else CONCRETE[path["kind"]]
	var height := float(path["height"])
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for run in path.get("runs", []):
		var points := Level3DStructures.points_of(run["points"])
		var closed: bool = run["closed"]
		var edges := Level3DStructures.ribbon(points, closed, float(path["width"]))
		var mesh := MeshInstance3D.new()
		mesh.mesh = _band(edges[0], edges[1], points, closed, height)
		mesh.material_override = material
		node.add_child(mesh)
	for m in path.get("merlon_at", []):
		var at := Vector2(float(m[0]), float(m[1]))
		var yaw := deg_to_rad(float(m[2]))
		_box(node, at, Vector2(cos(yaw), -sin(yaw)), Level3DStructures.MERLON_SIZE,
				rise_at.call(at) + height, colour.darkened(0.15))
	if bright and path["id"] == selected():
		_draw_handles(node, path)


# A band's mesh: its top, its two sides and, open, its two ends.
func _band(left: PackedVector2Array, right: PackedVector2Array, middle: PackedVector2Array,
		closed: bool, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := middle.size()
	var up := func(p: Vector2, lift: float) -> Vector3: return Vector3(p.x, float(rise_at.call(p)) + lift, p.y)
	var quad := func(a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
		for v in [a, b, c, a, c, d]:
			st.add_vertex(v)
	for k in (n if closed else n - 1):
		var m := (k + 1) % n
		quad.call(up.call(left[k], height), up.call(left[m], height), up.call(right[m], height), up.call(right[k], height))
		quad.call(up.call(left[k], 0.0), up.call(left[m], 0.0), up.call(left[m], height), up.call(left[k], height))
		quad.call(up.call(right[m], 0.0), up.call(right[k], 0.0), up.call(right[k], height), up.call(right[m], height))
	if not closed:
		for pair in [[0, true], [n - 1, false]]:
			var k: int = pair[0]
			var a: Vector3 = up.call(right[k] if pair[1] else left[k], 0.0)
			var b: Vector3 = up.call(left[k] if pair[1] else right[k], 0.0)
			quad.call(a, b, b + Vector3(0, height, 0), a + Vector3(0, height, 0))
	st.generate_normals()
	return st.commit()


# The handles of a wall's, path's or bridge's points, where they are drawn:
# [the index of the point in its list -- "points", or 0 and 1 for "from" and
# "to" -- and where it stands]. A gate in a path has none: the gate is moved.
func handles_of(s: Dictionary) -> Array:
	var out: Array = []
	if Level3DStructures.is_path(s):
		var elements: Array = s["points"]
		for k in elements.size():
			if not Level3DStructures.is_gate_point(elements[k]):
				out.append([k, Vector2(float(elements[k][0]), float(elements[k][1]))])
	else:
		out.append([0, Vector2(float(s["from"][0]), float(s["from"][1]))])
		out.append([1, Vector2(float(s["to"][0]), float(s["to"][1]))])
	return out


# The picked structure's handle under `p`, or -1.
func handle_under(p: Vector2) -> int:
	var s := find_structure(selected())
	if s.is_empty() or _selected.size() != 1:
		return -1
	var best := -1
	var best_d := HANDLE_PICK
	for h in handles_of(s):
		var d := p.distance_to(h[1])
		if d < best_d:
			best_d = d
			best = h[0]
	return best


func _draw_handles(node: Node3D, s: Dictionary) -> void:
	var lift := float(s.get("height", Level3DStructures.DECK_TOP)) + 0.15
	for h in handles_of(s):
		var at: Vector2 = h[1]
		var ball := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = HANDLE_SIZE * 0.5
		sphere.height = HANDLE_SIZE
		ball.mesh = sphere
		ball.material_override = _overlay(HANDLE_ACTIVE if h[0] == active_point else HANDLE, false)
		ball.position = Vector3(at.x, float(rise_at.call(at)) + lift, at.y)
		node.add_child(ball)


func update_wall(w: Dictionary) -> void:
	var node := _structure_node(w["id"])
	var bright := is_selected(w["id"])
	var colour: Color = SELECTED.lerp(CONCRETE[w["style"]], 0.35) if bright else CONCRETE[w["style"]]
	var a := Vector2(float(w["from"][0]), float(w["from"][1]))
	var b := Vector2(float(w["to"][0]), float(w["to"][1]))
	var base: float = rise_at.call((a + b) * 0.5)
	var height := float(w["height"])
	_box(node, (a + b) * 0.5, b - a, Vector3(maxf(a.distance_to(b), 0.05), height, float(w["width"])),
			base, colour)
	for m in Level3DStructures.merlons_of(w):
		_box(node, m, b - a, Level3DStructures.MERLON_SIZE, base + height, colour.darkened(0.15))
	if bright and w["id"] == selected():
		_draw_handles(node, w)


func update_bridge(br: Dictionary) -> void:
	var node := _structure_node(br["id"])
	var bright := is_selected(br["id"])
	var colour := SELECTED.lerp(DECK, 0.35) if bright else DECK
	var a := Vector2(float(br["from"][0]), float(br["from"][1]))
	var b := Vector2(float(br["to"][0]), float(br["to"][1]))
	var d := (b - a).normalized() if a != b else Vector2.RIGHT
	var left := Vector2(d.y, -d.x)
	var width := float(br["width"])
	var length := maxf(a.distance_to(b), 0.05)
	_box(node, (a + b) * 0.5, b - a, Vector3(length, Level3DStructures.DECK_TOP, width), 0.0, colour)
	for side in [1.0, -1.0]:
		_box(node, (a + b) * 0.5 + left * side * (width * 0.5 - Level3DStructures.CURB * 0.5), b - a,
				Vector3(length, 0.12, Level3DStructures.CURB), Level3DStructures.DECK_TOP, colour.darkened(0.2))
	for at in br["piers"]:
		_box(node, a + d * float(at), b - a, Vector3(0.56, -Level3DStructures.PIER_DEPTH, width - 0.6),
				Level3DStructures.PIER_DEPTH, colour.lightened(0.2))
	if bright and br["id"] == selected():
		_draw_handles(node, br)


func remove_structure(id: String) -> void:
	var node: Node3D = _structures.get(id)
	if node:
		node.queue_free()
		_structures.erase(id)
	_unselect(id)


# The wall, bridge or path whose box is under `p`, or "".
func structure_under(p: Vector2) -> String:
	var best := ""
	var best_d := 0.15
	for key in STRUCTURE_KEYS:
		for s in doc.get(key, []):
			var d := Level3DStructures.distance_to_path(s, p) if key == "paths" else Level3DStructures.distance_to(s, p)
			if d < best_d:
				best_d = d
				best = s["id"]
	return best


func _structure_node(id: String) -> Node3D:
	var node: Node3D = _structures.get(id)
	if node:
		for child in node.get_children():
			node.remove_child(child)
			child.queue_free()
		return node
	node = Node3D.new()
	add_child(node)
	_structures[id] = node
	return node


# A box `size` (along, up, across) on `centre`, turned along `along`, its
# bottom at `bottom`.
func _box(parent: Node3D, centre: Vector2, along: Vector2, size: Vector3, bottom: float, colour: Color) -> void:
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	box.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	box.material_override = material
	var angle := -along.angle() if along != Vector2.ZERO else 0.0
	box.transform = Transform3D(Basis(Vector3.UP, angle), Vector3(centre.x, bottom + size.y * 0.5, centre.y))
	parent.add_child(box)


# --- Selection -----------------------------------------------------------------


# The picked item the panel shows -- the last one picked -- or "".
func selected() -> String:
	return _selected[-1] if not _selected.is_empty() else ""


# All the picked items' ids.
func selection() -> Array:
	return _selected.duplicate()


func is_selected(id: String) -> bool:
	return _selected.has(id)


func select(id: String) -> void:
	select_many([] if id == "" else [id])


# Picks exactly `ids`, the last of them the one the panel shows.
func select_many(ids: Array) -> void:
	var was := _selected
	_selected = []
	for id in ids:
		if not _selected.has(id):
			_selected.append(id)
	if _selected != was:
		active_point = -1
	(_row_mesh.mesh as ImmediateMesh).clear_surfaces()
	var redraw := {}
	for which in was + _selected:
		redraw[which] = true
	for which in redraw:
		_redraw(which)


# Picks `id` as well as what is picked, or lets go of it if it is.
func toggle(id: String) -> void:
	var ids := selection()
	if ids.has(id):
		ids.erase(id)
	else:
		ids.append(id)
	select_many(ids)


func _unselect(id: String) -> void:
	if _selected.has(id):
		var ids := selection()
		ids.erase(id)
		select_many(ids)


func _redraw(id: String) -> void:
	var e := find_entity(id)
	if not e.is_empty():
		update_entity(e)
	var o := find_object(id)
	if not o.is_empty():
		update_object(o)
	var st := find_structure(id)
	if not st.is_empty():
		update_structure(st)


# Where each item of the kinds asked for stands, for picking them by a box
# drawn on the screen: an entity's footprint's middle, an object's foot, a
# wall's or a bridge's middle -- on the ground as the picture has it.
func anchors(kinds: Array) -> Dictionary:
	var out := {}
	var on_ground := func(p: Vector2) -> Vector3: return Vector3(p.x, height_at.call(p), p.y)
	if kinds.has("entities"):
		for e in doc["entities"]:
			out[e["id"]] = on_ground.call(Vector2(float(e["pos"][0]), float(e["pos"][1])))
	if kinds.has("objects"):
		for o in doc["objects"]:
			var p := Vector2(float(o["pos"][0]), float(o["pos"][2]))
			out[o["id"]] = Vector3(p.x, float(o["pos"][1]) + rise_at.call(p), p.y)
	if kinds.has("structures"):
		for key in ["walls", "bridges"]:
			for s in doc.get(key, []):
				var a := Vector2(float(s["from"][0]), float(s["from"][1]))
				var b := Vector2(float(s["to"][0]), float(s["to"][1]))
				out[s["id"]] = on_ground.call((a + b) * 0.5)
		# A path by the middle of its points' bounds: a ring's middle is
		# inside the ring, where the box has to reach.
		for path in doc.get("paths", []):
			var box := Rect2()
			var first := true
			for run in path.get("runs", []):
				for q in run["points"]:
					var v := Vector2(float(q[0]), float(q[1]))
					box = Rect2(v, Vector2.ZERO) if first else box.expand(v)
					first = false
			if not first:
				out[path["id"]] = on_ground.call(box.get_center())
	return out


# The line across the map where the top of the frame is when `e` fires.
func _draw_row(e: Dictionary) -> void:
	var index: int = MapIO.trigger_constants().get(e["type"], 0)
	var row: int = entity_tile(e).y + int(fire_rows[index] if index < fire_rows.size() else 1)
	var z := Level3DIO.to_level(grid(), Vector2(0, row * float(grid()["tile_px"]))).y
	var left := Level3DIO.to_level(grid(), Vector2.ZERO).x
	var mesh := _row_mesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_set_color(ROW_COLOR)
	mesh.surface_add_vertex(Vector3(left, 0.05, z))
	mesh.surface_add_vertex(Vector3(left + columns() * tile_m(), 0.05, z))
	mesh.surface_end()


# --- The nav grid --------------------------------------------------------------


func show_nav(rows_of: Array, visible_now: bool) -> void:
	if _nav_mesh == null:
		_nav_image = Image.create(columns(), rows(), false, Image.FORMAT_RGBA8)
		_nav_texture = ImageTexture.create_from_image(_nav_image)
		var size := Vector2(columns(), rows()) * tile_m()
		var plane := PlaneMesh.new()
		plane.size = size
		_nav_mesh = MeshInstance3D.new()
		_nav_mesh.mesh = plane
		_nav_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var corner := Level3DIO.to_level(grid(), Vector2.ZERO)
		_nav_mesh.position = Vector3(corner.x + size.x * 0.5, 0.02, corner.y + size.y * 0.5)
		var material := _overlay(Color.WHITE, true)
		material.albedo_texture = _nav_texture
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_nav_mesh.material_override = material
		add_child(_nav_mesh)
	_nav_mesh.visible = visible_now
	if not visible_now:
		return
	for y in rows():
		var row: String = rows_of[y]
		for x in columns():
			_nav_image.set_pixel(x, y, TYPE_COLORS[MapIO.TYPE_CHARS.get(row[x], MapIO.TYPE_EMPTY)])
	_nav_texture.update(_nav_image)


static func _overlay(color: Color, see_through: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.vertex_color_use_as_albedo = see_through
	material.no_depth_test = see_through
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	return material
