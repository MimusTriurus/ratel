class_name Level3DWind
extends RefCounted

# The palms of the 3D preview swaying in the wind: their materials swapped
# for ones that move the vertices (level3d_wind.gdshader), the contour's for
# one that moves the hull with them (level3d_hull_wind.gdshader). How they
# move is level3d_wind.gdshaderinc's; here is what each mesh tells it.
#
# Per mesh, not per palm: the stage's 150 palms are instances of four meshes,
# and a palm's phase comes from where it stands, in the shader. Each mesh has
# a material of its own for each surface, because the crown and its reach are
# the mesh's: the crown the top of the trunk surface, the reach the furthest
# a frond goes from it, level. The glb's materials are left as they were --
# the new ones take their names, which the trunk's collider looks for
# (level3d_preview.gd, _add_trunk).
#
# Run after the engine's contour (Level3DHull), whose mesh it changes, and
# after the shadows are set to both sides (_cast_both_sides_of_planes), which
# go by the glb's materials. --baked-contour's shell is left still: it is a
# comparison, not the look.
#
# Smooth, or stepped to STEPPED_FPS (stepped), for all of them at once.

const SHADER := preload("res://src/tools/level3d_wind.gdshader")
const HULL_SHADER := preload("res://src/tools/level3d_hull_wind.gdshader")
# Held poses, this many a second: a cartoon's twos at 24 would be 12; the
# palms are scenery, and slower reads as more deliberate.
const STEPPED_FPS := 8.0
# How far the frustum may miss a palm by: the wind moves a crown under 25 cm.
const CULL_MARGIN := 0.3

static var _materials: Array[ShaderMaterial] = []
static var _made := {}  # Mesh -> true
static var _stepped := false


static func apply(instance: MeshInstance3D) -> void:
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return
	instance.extra_cull_margin = CULL_MARGIN
	if _made.has(mesh):
		return
	_made[mesh] = true
	var crown := _crown(mesh)
	if crown.is_empty():
		push_warning("%s has no trunk surface; it will not sway" % instance.name)
		return
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_material(surface)
		var material := ShaderMaterial.new()
		if Level3DHull.is_hull(source):
			material.shader = HULL_SHADER
			material.set_shader_parameter("pixels", Level3DHull.PIXELS)
		elif source is BaseMaterial3D and not source.resource_name.ends_with("Contour"):
			material.shader = SHADER
			material.set_shader_parameter("albedo", (source as BaseMaterial3D).albedo_color)
		else:
			continue
		material.resource_name = source.resource_name
		material.set_shader_parameter("wind_crown", crown.at)
		material.set_shader_parameter("wind_radius", crown.reach)
		material.set_shader_parameter("wind_fps", STEPPED_FPS if _stepped else 0.0)
		mesh.surface_set_material(surface, material)
		_materials.append(material)


static func is_stepped() -> bool:
	return _stepped


static func set_stepped(stepped: bool) -> void:
	_stepped = stepped
	for material in _materials:
		material.set_shader_parameter("wind_fps", STEPPED_FPS if stepped else 0.0)


# 0 stills them all, 1 is the wind as tuned.
static func set_strength(strength: float) -> void:
	for material in _materials:
		material.set_shader_parameter("wind_strength", strength)


# {"at": the top of the trunk, "reach": the furthest a frond goes from it,
# level}, in the mesh's own space; empty if it has no trunk.
static func _crown(mesh: ArrayMesh) -> Dictionary:
	var trunk := PackedVector3Array()
	var rest := PackedVector3Array()
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material == null or Level3DHull.is_hull(material) or material.resource_name.ends_with("Contour"):
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		if material.resource_name.contains("Trunk"):
			trunk.append_array(vertices)
		else:
			rest.append_array(vertices)
	if trunk.is_empty():
		return {}
	var top := -INF
	for v in trunk:
		top = maxf(top, v.y)
	# The top ring's middle, not its highest corner.
	var at := Vector3.ZERO
	var n := 0
	for v in trunk:
		if v.y > top - 0.06:
			at += v
			n += 1
	at /= n
	var reach := 0.1
	for v in rest:
		reach = maxf(reach, Vector2(v.x - at.x, v.z - at.z).length())
	return {"at": at, "reach": reach}
