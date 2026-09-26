class_name Level3DMarks
extends RefCounted

# What the rockets and the rounds leave on the walls and the buildings of the
# 3D preview: a rocket's soot (level3d_rocket.gd, _explode) and a round's
# pock (level3d_gun.gd, _impact). The ground takes a crater or a scorch; a
# wall used to take a crater as well, dug into its top, since its top is
# ground to the hull. Not in the game, whose walls show nothing.
#
# Painted by level3d_marks.gdshaderinc, in place of the surfaces' glb
# materials (level3d_marked.gdshader), one shader material to each of those,
# taking its colour: the walls, the bunkers, the sandbags, the rocks and the
# buildings, ruins and all (level3d_preview.gd, _add_marks). The contour is
# left as it is -- a mark does not change the shape.
#
# The last SOOT_KEPT soots and POCKS_KEPT pocks are kept, the oldest going
# first, the pocks apart so that a burst does not wipe out a rocket's soot.

const SHADER := preload("res://src/tools/level3d_marked.gdshader")
# What a round or a rocket that strikes them marks: the kinds of
# level3d_preview.gd's _kind_of and _add_targets.
const KINDS: Array[String] = ["wall", "building"]
# level3d_marks.gdshaderinc's MARKS, shared between the two.
const SOOT_KEPT := 24
const POCKS_KEPT := 40
# J_SootConcrete (jackal_bunker_dest.py), the soot on a bunker whose gun is
# gone: nearly black and cold. The scorches' brown, Level3DFx.SOOT, is for
# sand, and on grey concrete it reads as dirt.
const SOOT := Color(0.1601, 0.1559, 0.1473)

static var _materials: Array[ShaderMaterial] = []
static var _made := {}  # a glb's Material -> its ShaderMaterial
static var _soot: Array[Vector4] = []
static var _pocks: Array[Vector4] = []


static func apply(instance: MeshInstance3D) -> void:
	if instance.mesh == null:
		return
	for surface in instance.mesh.get_surface_count():
		var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
		if source == null or Level3DHull.is_hull(source) or source.resource_name.ends_with("Contour") \
				or source.emission_enabled:
			continue
		if not _made.has(source):
			var material := ShaderMaterial.new()
			material.shader = SHADER
			material.resource_name = source.resource_name
			material.set_shader_parameter("albedo", source.albedo_color)
			material.set_shader_parameter("soot", SOOT)
			_made[source] = material
			_materials.append(material)
			_push_to(material)
		instance.set_surface_override_material(surface, _made[source])


# A rocket's soot at `at`, `radius` metres round.
static func soot(at: Vector3, radius: float) -> void:
	_soot.append(Vector4(at.x, at.y, at.z, radius))
	if _soot.size() > SOOT_KEPT:
		_soot.remove_at(0)
	_push()


# A round's pock at `at`.
static func pock(at: Vector3, radius: float) -> void:
	_pocks.append(Vector4(at.x, at.y, at.z, -radius))
	if _pocks.size() > POCKS_KEPT:
		_pocks.remove_at(0)
	_push()


# All of them gone: the preview's R.
static func clear() -> void:
	_soot.clear()
	_pocks.clear()
	_push()


static func _push() -> void:
	for material in _materials:
		_push_to(material)


static func _push_to(material: ShaderMaterial) -> void:
	var places := PackedVector4Array(_soot + _pocks)
	var count := places.size()
	places.resize(SOOT_KEPT + POCKS_KEPT)
	material.set_shader_parameter("mark_count", count)
	material.set_shader_parameter("mark_place", places)
