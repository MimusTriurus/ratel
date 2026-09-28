# One placed piece of scenery of a level being edited (Level3DEditRoot), drawn
# as the stage's glb draws it: a copy of the first piece of the same asset.
#
# A level object turns about the vertical and scales evenly and nothing else
# (Level3DIO.serialize), so whatever the gizmo does is brought back to that:
# the tilt dropped, the scale evened out to its x.
@tool
class_name Level3DEditObject
extends Node3D

@export var object_id := ""
@export var asset := "Palm_0":
	set(value):
		asset = value
		_rebuild()
# The entity it belongs to -- a bunker's gun -- or "".
@export var entity := ""

var root: Level3DEditRoot
var _fixing := false
var _model: Node3D


static func from_doc(o: Dictionary, level: Level3DEditRoot) -> Level3DEditObject:
	var node := Level3DEditObject.new()
	node.root = level
	node.object_id = o["id"]
	node.name = o["id"]
	node.asset = o["asset"]
	node.entity = o.get("entity", "")
	var p: Array = o["pos"]
	node.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	node.rotation_degrees = Vector3(0.0, float(o["yaw"]), 0.0)
	node.scale = Vector3.ONE * float(o["scale"])
	return node


func to_doc() -> Dictionary:
	var out := {
		"id": object_id, "asset": asset,
		"pos": [Level3DIO.round_mm(position.x), Level3DIO.round_mm(position.y),
				Level3DIO.round_mm(position.z)],
		"yaw": wrapf(rotation_degrees.y, -180.0, 180.0), "scale": scale.x,
	}
	if entity != "":
		out["entity"] = entity
	return out


func _validate_property(property: Dictionary) -> void:
	if property.name == "asset" and root and not root.catalog.is_empty():
		var names: Array = root.catalog["assets"].keys()
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
	if what == NOTIFICATION_TRANSFORM_CHANGED and not _fixing:
		_fixing = true
		var yaw := rotation.y
		var even := scale.x
		if not is_zero_approx(rotation.x) or not is_zero_approx(rotation.z) \
				or not scale.is_equal_approx(Vector3.ONE * even):
			basis = Basis(Vector3.UP, yaw).scaled(Vector3.ONE * even)
		_fixing = false


func _rebuild() -> void:
	if not is_inside_tree() or root == null or root.doc.is_empty():
		return
	if _model:
		remove_child(_model)
		_model.queue_free()
		_model = null
	else:
		Level3DEditEntity.clear_copies(self)
	var model := root.template(asset)
	if model == null:
		# Nothing in the stage draws this asset yet: a marker the size of a
		# tile, until the builder can place the real thing.
		var marker := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3.ONE * root.tile_m()
		marker.mesh = box
		var material := Level3DEditRoot._overlay_material(Color(1, 0, 1, 0.6), false)
		material.vertex_color_use_as_albedo = false
		marker.material_override = material
		model = marker
	else:
		model = model.duplicate() as Node3D
	_model = model
	add_child(model, false, INTERNAL_MODE_FRONT)
