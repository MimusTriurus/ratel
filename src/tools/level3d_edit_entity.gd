# One entity of a level being edited (Level3DEditRoot): a trigger of the game,
# drawn as its footprint in its kind's colour with its id over it.
#
# It stays on the game's grid. An entity is a trigger, and a trigger sits on
# a tile, so wherever the gizmo drags it, it snaps to the tile its footprint
# would cover -- the file could not hold it anywhere else, and it is better
# seen now than found moved after a save. It does not turn or scale either.
@tool
class_name Level3DEditEntity
extends Node3D

@export var entity_id := ""
@export var type := "GRAY_GUN":
	set(value):
		type = value
		_rebuild()
@export var normal := true
@export var hard := true
# The destruction group it sets off, for the types that have one
# (MapIO.GROUP_PROBES); -1 for the rest.
@export var group := -1

var root: Level3DEditRoot
var _snapping := false
var _box: MeshInstance3D
var _label: Label3D


static func from_doc(e: Dictionary, level: Level3DEditRoot) -> Level3DEditEntity:
	var node := Level3DEditEntity.new()
	node.root = level
	node.entity_id = e["id"]
	node.name = e["id"]
	node.type = e["type"]
	var difficulty: Array = e["difficulty"]
	node.normal = difficulty.has("normal")
	node.hard = difficulty.has("hard")
	node.group = int(e.get("group", -1))
	node.position = Vector3(float(e["pos"][0]), 0.0, float(e["pos"][1]))
	return node


func to_doc() -> Dictionary:
	var difficulty: Array = []
	if normal:
		difficulty.append("normal")
	if hard:
		difficulty.append("hard")
	# Snapped here as well as on the transform's notification, which comes a
	# frame late: a save straight after a drag must not write the drag.
	var p := Level3DIO.entity_pos(root.grid(), footprint(), tile())
	var out := {
		"id": entity_id, "type": type,
		"pos": [Level3DIO.round_mm(p.x), Level3DIO.round_mm(p.y)],
		"difficulty": difficulty,
	}
	if group >= 0:
		out["group"] = group
	return out


func _validate_property(property: Dictionary) -> void:
	if property.name == "type":
		var names := MapIO.trigger_constants().keys()
		names.sort()
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(names)


func _enter_tree() -> void:
	if root == null:
		var p := get_parent()
		while p and not p is Level3DEditRoot:
			p = p.get_parent()
		root = p as Level3DEditRoot
	set_notify_transform(true)
	_rebuild()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_snap()


func footprint() -> Vector2i:
	if root == null or not root.sizes.has(type):
		return Vector2i.ONE
	return root.sizes[type]


func tile() -> Vector2i:
	return Level3DIO.entity_tile(root.grid(), footprint(), Vector2(position.x, position.z))


# Where the top of the frame is when this fires: see Level3DEditRoot.update_rows.
func fire_z() -> float:
	var index: int = MapIO.trigger_constants().get(type, 0)
	var row: int = tile().y + int(root.fire_rows[index])
	return Level3DIO.to_level(root.grid(), Vector2(0, row * float(root.grid()["tile_px"]))).y


func _snap() -> void:
	if _snapping or root == null or root.doc.is_empty():
		return
	_snapping = true
	var p := Level3DIO.entity_pos(root.grid(), footprint(), tile())
	var snapped := Transform3D(Basis.IDENTITY, Vector3(p.x, 0.0, p.y))
	if not transform.is_equal_approx(snapped):
		transform = snapped
	_snapping = false
	root.update_rows()


func _rebuild() -> void:
	if not is_inside_tree() or root == null or root.doc.is_empty():
		return
	if _box == null:
		Level3DEditEntity.clear_copies(self)
		_box = MeshInstance3D.new()
		_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_box, false, INTERNAL_MODE_FRONT)
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.no_depth_test = true
		_label.fixed_size = true
		_label.pixel_size = 0.0008
		_label.font_size = 28
		_label.outline_size = 8
		_label.render_priority = 3
		add_child(_label, false, INTERNAL_MODE_FRONT)
	var kind: String = root.catalog["entities"].get(type, {}).get("kind", "enemy")
	var colour: Color = Level3DEditRoot.KIND_COLORS.get(kind, Color.WHITE)
	var size := Vector2(footprint()) * root.tile_m()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, 0.35, size.y)
	_box.mesh = box
	_box.position = Vector3(0, 0.175, 0)
	var material := Level3DEditRoot._overlay_material(Color(colour, 0.35), false)
	material.vertex_color_use_as_albedo = false
	_box.material_override = material
	_label.text = entity_id if entity_id != "" else type.to_lower()
	_label.modulate = colour.lightened(0.4)
	_label.position = Vector3(0, 0.6, 0)
	_snap()


# What a duplicate (Ctrl+D) brought along of the original's drawing: the
# box, the label or the model, which the copy draws for itself.
static func clear_copies(node: Node) -> void:
	for child in node.get_children(true):
		if child.owner == null:
			node.remove_child(child)
			child.queue_free()
