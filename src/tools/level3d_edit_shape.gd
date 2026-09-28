# One polygon of a level's ground being edited (Level3DEditRoot): a piece of
# land, a body of water or a forest (Level3DTerrain). Its rings are Path3D
# children -- "outer", then "hole_0", "hole_1", ... -- whose points the
# editor's own path tools move, add and delete; the shape draws each ring in
# its kind's colour and keeps the curves closed and flat on the ground.
#
# A shape stands at the origin and its rings' points are level coordinates:
# moving the shape node itself would move nothing the file holds, so it is
# put back.
@tool
class_name Level3DEditShape
extends Node3D

const KINDS: Array[String] = ["land", "water", "forest"]
const COLOURS := {
	"land": Color(1.0, 0.75, 0.25), "water": Color(0.3, 0.7, 1.0),
	"forest": Color(0.3, 0.95, 0.4),
}
# The rings are drawn a little over the sand, where the camera sees them from
# above whatever the ground under them.
const LIFT := 0.06

@export var shape_id := ""
@export_enum("land", "water", "forest") var kind := "land":
	set(value):
		kind = value
		notify_property_list_changed()
		_redraw()
		_changed()
# land
@export var height := 0.0:
	set(value):
		height = value
		_changed()
@export var profile := "shore":
	set(value):
		profile = value
		_changed()
# water
@export_enum("sea", "river") var water_kind := "sea":
	set(value):
		water_kind = value
		_changed()
@export var level := -1.0:
	set(value):
		level = value
		_changed()
# forest
@export var spacing := 0.55:
	set(value):
		spacing = maxf(value, 0.05)
		_changed()
@export var jitter := 0.22:
	set(value):
		jitter = value
		_changed()
@export var pines := 0.12:
	set(value):
		pines = value
		_changed()
@export var tree_seed := 1:
	set(value):
		tree_seed = value
		_changed()

var root: Level3DEditRoot
var _lines: MeshInstance3D
var _fixing := false


static func from_doc(polygon: Dictionary, shape_kind: String, level_root: Level3DEditRoot) -> Level3DEditShape:
	var node := Level3DEditShape.new()
	node.root = level_root
	node.shape_id = polygon["id"]
	node.name = polygon["id"]
	node.kind = shape_kind
	match shape_kind:
		"land":
			node.height = float(polygon.get("height", 0.0))
			node.profile = polygon.get("profile", "shore")
		"water":
			node.water_kind = polygon.get("kind", "sea")
			node.level = float(polygon.get("level", -1.0))
		"forest":
			node.spacing = float(polygon["spacing"])
			node.jitter = float(polygon["jitter"])
			node.pines = float(polygon["pines"])
			node.tree_seed = int(polygon["seed"])
	node._add_ring("outer", polygon["outer"])
	var holes: Array = polygon.get("holes", [])
	for k in holes.size():
		node._add_ring("hole_%d" % k, holes[k])
	return node


func _add_ring(ring_name: String, points: Array) -> void:
	var curve := Curve3D.new()
	curve.closed = true
	for p in points:
		curve.add_point(Vector3(float(p[0]), LIFT, float(p[1])))
	var path := Path3D.new()
	path.name = ring_name
	path.curve = curve
	add_child(path)


func to_doc() -> Dictionary:
	var out := {"id": shape_id}
	match kind:
		"land":
			out["height"] = height
			out["profile"] = profile
		"water":
			out["kind"] = water_kind
			out["level"] = level
		"forest":
			out["spacing"] = spacing
			out["jitter"] = jitter
			out["pines"] = pines
			out["seed"] = tree_seed
	var holes: Array = []
	for path in rings():
		var points: Array = []
		for k in path.curve.point_count:
			var p := path.curve.get_point_position(k)
			points.append([Level3DIO.round_mm(p.x), Level3DIO.round_mm(p.z)])
		if path.name == &"outer":
			out["outer"] = points
		else:
			holes.append(points)
	out["holes"] = holes
	return out


func rings() -> Array[Path3D]:
	var out: Array[Path3D] = []
	var outer := get_node_or_null(^"outer") as Path3D
	if outer:
		out.append(outer)
	for child in get_children():
		if child is Path3D and child != outer:
			out.append(child)
	return out


func _validate_property(property: Dictionary) -> void:
	var only := {
		"height": "land", "profile": "land", "water_kind": "water", "level": "water",
		"spacing": "forest", "jitter": "forest", "pines": "forest", "tree_seed": "forest",
	}
	if only.has(property.name) and only[property.name] != kind:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _enter_tree() -> void:
	if root == null:
		var p := get_parent()
		while p and not p is Level3DEditRoot:
			p = p.get_parent()
		root = p as Level3DEditRoot
	set_notify_transform(true)
	for path in rings():
		if not path.curve.changed.is_connected(_on_curve_changed):
			path.curve.changed.connect(_on_curve_changed)
	_redraw()


# Deleted, or taken out by a reload: the proxy no longer has it.
func _exit_tree() -> void:
	_changed()


func _changed() -> void:
	if root and is_inside_tree():
		root.ground_changed()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and not _fixing \
			and not transform.is_equal_approx(Transform3D.IDENTITY):
		_fixing = true
		transform = Transform3D.IDENTITY
		_fixing = false


# A point dragged by the path tool comes up or down with the mouse; the rings
# are flat, so it is put back on LIFT, and the ground is rebuilt once the edit
# has settled.
func _on_curve_changed() -> void:
	if _fixing:
		return
	_fixing = true
	for path in rings():
		path.transform = Transform3D.IDENTITY
		for k in path.curve.point_count:
			var p := path.curve.get_point_position(k)
			if not is_equal_approx(p.y, LIFT):
				path.curve.set_point_position(k, Vector3(p.x, LIFT, p.z))
			if path.curve.get_point_in(k) != Vector3.ZERO or path.curve.get_point_out(k) != Vector3.ZERO:
				path.curve.set_point_in(k, Vector3.ZERO)
				path.curve.set_point_out(k, Vector3.ZERO)
		if not path.curve.closed:
			path.curve.closed = true
	_fixing = false
	_redraw()
	if root:
		root.ground_changed()


func _redraw() -> void:
	if not is_inside_tree():
		return
	if _lines == null:
		Level3DEditEntity.clear_copies(self)
		_lines = MeshInstance3D.new()
		_lines.mesh = ImmediateMesh.new()
		_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lines.material_override = Level3DEditRoot._overlay_material(Color.WHITE, true)
		add_child(_lines, false, INTERNAL_MODE_FRONT)
	var mesh := _lines.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var colour: Color = COLOURS.get(kind, Color.WHITE)
	for path in rings():
		var n := path.curve.point_count
		if n < 2:
			continue
		mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		mesh.surface_set_color(colour if path.name == &"outer" else colour.darkened(0.3))
		for k in n + 1:
			mesh.surface_add_vertex(path.curve.get_point_position(k % n))
		mesh.surface_end()
