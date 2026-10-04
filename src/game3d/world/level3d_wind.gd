class_name Level3DWind
extends RefCounted

# The palms and the trees of the 3D preview swaying in the wind, and thrown
# about by the blasts and the rounds: their materials swapped for ones that
# move the vertices (level3d_wind.gdshader), the contour's for one that
# moves the hull with them (level3d_hull_wind.gdshader). How they move is
# level3d_wind.gdshaderinc's; here is what each mesh tells it, the clock it
# goes by, and the blasts.
#
# A plant is a mesh with a trunk: a surface in a *Trunk or *Bark material.
# Per mesh, not per plant: the stage's 150 palms and 5000 trees are instances
# of fourteen meshes, and a plant's phase comes from where it stands, in the
# shader. Each mesh has a material of its own for each surface, because the
# crown and its reach are the mesh's: the crown the top of the trunk surface,
# the reach the furthest the rest goes from it, level. A palm's fronds flap
# (a surface in a *Frond material says it is a palm); a tree bends less and
# its crown goes as one. The glb's materials are left as they were -- the new
# ones take their names, which the palms' colliders look for
# (level3d_preview.gd, _add_trunk), and so do the shadows' both sides.
#
# Run after the engine's contour (Level3DHull), whose mesh it changes, and
# after the shadows are set to both sides (_cast_both_sides_of_planes), which
# go by the glb's materials. --baked-contour's shell is left still: it is a
# comparison, not the look.
#
# The blasts are the last BLASTS set off, each where and when, how far it
# throws a crown two metres up and how far it reaches. A new one takes the
# slot of the one with least left of it, so that a burst of rounds in the
# trees does not put out a building's blast.
#
# Smooth, or stepped to STEPPED_FPS (stepped), for all of them at once.

const SHADER := preload("res://src/game3d/shaders/level3d_wind.gdshader")
const HULL_SHADER := preload("res://src/game3d/shaders/level3d_hull_wind.gdshader")
# Held poses, this many a second: a cartoon's twos at 24 would be 12; the
# plants are scenery, and slower reads as more deliberate.
const STEPPED_FPS := 8.0
# How far the frustum may miss a plant by: a big blast throws a crown half a
# metre.
const CULL_MARGIN := 0.7
# How much a tree gives to the wind, as a share of what a palm does: a palm's
# trunk is a long whip, a tree's crown sits low on a short one.
const TREE_GIVE := 0.55
# As level3d_wind.gdshaderinc has them: its slots, and how long a blast is
# followed and how fast its swinging dies.
const BLASTS := 8
const BLAST_LIFE := 1.8
const BLAST_DAMP := 3.0

static var _materials: Array[ShaderMaterial] = []
static var _made := {}  # Mesh -> whether it is a plant
static var _stepped := false
static var _clock := 0.0
static var _where := PackedVector4Array()
static var _size := PackedVector2Array()


static func apply(instance: MeshInstance3D) -> bool:
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return false
	if _made.has(mesh):
		if _made[mesh]:
			instance.extra_cull_margin = CULL_MARGIN
		return _made[mesh]
	var crown := _crown(mesh)
	_made[mesh] = not crown.is_empty()
	if crown.is_empty():
		return false
	instance.extra_cull_margin = CULL_MARGIN
	if _where.is_empty():
		reset()
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
		material.set_shader_parameter("wind_flap", 1.0 if crown.palm else 0.0)
		material.set_shader_parameter("wind_give", 1.0 if crown.palm else TREE_GIVE)
		material.set_shader_parameter("wind_fps", STEPPED_FPS if _stepped else 0.0)
		material.set_shader_parameter("wind_clock", _clock)
		material.set_shader_parameter("wind_blasts", _where)
		material.set_shader_parameter("wind_blast_size", _size)
		mesh.surface_set_material(surface, material)
		_materials.append(material)
	return true


# Once a frame, from the preview's _process: the clock the wind and the
# blasts go by.
static func tick(delta: float) -> void:
	_clock += delta
	for material in _materials:
		material.set_shader_parameter("wind_clock", _clock)


# A blast at `at`, `delay` seconds from now: it throws a crown two metres up
# `throw` metres, less further off, and nothing `reach` metres away.
static func blast(at: Vector3, throw: float, reach: float, delay := 0.0) -> void:
	if _where.is_empty():
		reset()
	var slot := 0
	var least := INF
	for i in BLASTS:
		var left := _left(i)
		if left < least:
			least = left
			slot = i
	_where[slot] = Vector4(at.x, at.y, at.z, _clock + delay)
	_size[slot] = Vector2(throw, reach)
	for material in _materials:
		material.set_shader_parameter("wind_blasts", _where)
		material.set_shader_parameter("wind_blast_size", _size)


# All blasts gone: the preview's R.
static func reset() -> void:
	_where.resize(BLASTS)
	_size.resize(BLASTS)
	_where.fill(Vector4.ZERO)
	_size.fill(Vector2.ZERO)
	for material in _materials:
		material.set_shader_parameter("wind_blasts", _where)
		material.set_shader_parameter("wind_blast_size", _size)


static func is_stepped() -> bool:
	return _stepped


static func set_stepped(stepped: bool) -> void:
	_stepped = stepped
	for material in _materials:
		material.set_shader_parameter("wind_fps", STEPPED_FPS if stepped else 0.0)


# 0 stills the wind, 1 is the wind as tuned; the blasts are not the wind's.
static func set_strength(strength: float) -> void:
	for material in _materials:
		material.set_shader_parameter("wind_strength", strength)


# What is left of slot i's blast: its throw, as far as it has died. One yet
# to go off has all of it.
static func _left(i: int) -> float:
	if _size[i].y <= 0.0:
		return 0.0
	var age := _clock - _where[i].w
	if age >= BLAST_LIFE:
		return 0.0
	return _size[i].x * exp(-BLAST_DAMP * maxf(age, 0.0))


# {"at": the top of the trunk, "reach": the furthest the rest goes from it,
# level, "palm": whether it has fronds}, in the mesh's own space; empty if it
# has no trunk.
static func _crown(mesh: ArrayMesh) -> Dictionary:
	var trunk := PackedVector3Array()
	var rest := PackedVector3Array()
	var palm := false
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material == null or Level3DHull.is_hull(material) or material.resource_name.ends_with("Contour"):
			continue
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		if material.resource_name.contains("Trunk") or material.resource_name.contains("Bark"):
			trunk.append_array(vertices)
		else:
			rest.append_array(vertices)
			palm = palm or material.resource_name.contains("Frond")
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
	return {"at": at, "reach": reach, "palm": palm}
