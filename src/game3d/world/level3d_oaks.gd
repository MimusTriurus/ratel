# BlenderMCP's oaks (resources/3d/oaks/, made by its pipeline/tree_gen.py) in a
# scene of the preview's own -- the game over's cemetery (Level3DGameOver) and
# the mission's end (Level3DVictory): planted, in the wind and outlined. Made
# for the cemetery and moved here when the mission's end took its oaks too.
#
#   * An oak is one of OAK_PATHS' meshes, turn and turn about, without the
#     surfaces it does not draw here (OAK_DROPPED: its root plate is under
#     its board's ground and its twigs show only once the crown has burnt),
#     keeping the levels of detail the import made: the mission's end has
#     hundreds of them, most far off (oak_mesh). Sunk into the ground down to
#     the lowest ground round its trunk's foot, so that no side of the foot
#     stands in the air (plant).
#   * The wind (sway): an oak sways as the stage's trees do, by the stage's
#     wind (level3d_wind.gdshaderinc, the same gusts from the same quarter),
#     the trunk in a soft-lit shader (level3d_wind_soft.gdshader), the crown
#     in one of its own (level3d_leaf_wind.gdshader), its palette turned by
#     `tint`. On its own clock (advance), which runs while its scene is
#     shown: the preview's, Level3DWind's, stops with the stage paused under
#     it. Stepped with the stage's (Level3DWind.is_stepped); still under
#     --no-wind. Its scene's other plants may go on the same clock
#     (wind_material), the cemetery's grass does.
#   * The outline (outline, ink): a leaf is an open plane, which
#     Level3DHull's shell cannot ring. So each oak has a double on MASK_LAYER,
#     flat in a colour of its own, seen by a camera of its scene's into
#     `mask`, and the scene's frame is drawn through level3d_oak_ink.gdshader,
#     which inks the mask's edges over it. The oaks themselves are on
#     OAK_LAYER, which the mask's camera leaves out; the scene's camera leaves
#     out MASK_LAYER.
class_name Level3DOaks
extends RefCounted

const OAK_PATHS: Array[String] = ["res://resources/3d/oaks/oak_001.glb", "res://resources/3d/oaks/oak_003.glb",
		"res://resources/3d/oaks/oak_006.glb"]
const OAK_DROPPED: Array[String] = ["TreeGame.Twig", "TreeGame.Soil", "TreeGame.Root"]
# Each oak turned OAK_TURN radians from the one before.
const OAK_TURN := 1.3
# The trunk's foot: how far up the bark it is measured, metres of the model,
# and how far under the lowest ground round it it is sunk, metres.
const OAK_FOOT := 0.3
const OAK_SINK := 0.05
# How much an oak gives to the wind, as a share of what a palm does on the
# stage: its model is in real metres, 7 m tall, and the wind bends by the
# square of the height, so a little goes a long way -- its top some 0.3 m.
const OAK_GIVE := 0.3
# The crown's colour, linear, per channel: the palette was picked for
# BlenderMCP's board light, and under the cemetery's low warm sun came out
# olive-brown, 41,38,5 on average -- the grass's colour, darker. Turned to a
# green between the stage's trees' and the uniforms': 27,66,28 on average,
# measured.
const OAK_TINT := Vector3(0.75, 1.55, 2.2)

const WIND_SOFT_SHADER := preload("res://src/game3d/shaders/level3d_wind_soft.gdshader")
const LEAF_WIND_SHADER := preload("res://src/game3d/shaders/level3d_leaf_wind.gdshader")
const OAK_MASK_SHADER := preload("res://src/game3d/shaders/level3d_oak_mask.gdshader")
const OAK_INK_SHADER := preload("res://src/game3d/shaders/level3d_oak_ink.gdshader")
const OAK_LAYER := 1 << 1
const MASK_LAYER := 1 << 2

# The mask the outline is drawn from, its scene's; the haze its scene has, 0
# for none (the ink and the mask are hazed by it too); the crown's tint.
var mask: SubViewport
var fog_density := 0.0
var tint := OAK_TINT
var planted := 0

var _wind: Array[ShaderMaterial] = []
var _wind_made := {}         # a mesh -> its surfaces' wind materials, null where none
var _clock := 0.0

static var _meshes: Array[ArrayMesh] = []


func _init(p_mask: SubViewport, p_fog_density := 0.0) -> void:
	mask = p_mask
	fog_density = p_fog_density


# The oak meshes, made once.
static func meshes() -> Array[ArrayMesh]:
	if _meshes.is_empty():
		for path in OAK_PATHS:
			_meshes.append(oak_mesh(load(path) as PackedScene))
	return _meshes


# An oak's glb as one mesh without the surfaces it does not draw here, each
# with its levels of detail.
static func oak_mesh(scene: PackedScene) -> ArrayMesh:
	var root := scene.instantiate()
	var source := (root.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh as ArrayMesh
	var out := ArrayMesh.new()
	for surface in source.get_surface_count():
		var material := source.surface_get_material(surface)
		if material != null and material.resource_name in OAK_DROPPED:
			continue
		# The leaves' burn ramp in their custom channels: their format given
		# again, or the arrays are refused.
		out.add_surface_from_arrays(source.surface_get_primitive_type(surface), source.surface_get_arrays(surface),
				[], _lods(source, surface), source.surface_get_format(surface) & ~Mesh.ARRAY_FORMAT_VERTEX)
		out.surface_set_material(out.get_surface_count() - 1, material)
		out.surface_set_name(out.get_surface_count() - 1, source.surface_get_name(surface))
	root.free()
	return out


# A surface's levels of detail as add_surface_from_arrays takes them: each
# one's edge length to its indices. The server holds them as bytes, two to
# an index or four, as the surface's own indices are.
static func _lods(mesh: ArrayMesh, surface: int) -> Dictionary:
	var data := RenderingServer.mesh_get_surface(mesh.get_rid(), surface)
	var count := int(data.get("index_count", 0))
	if count == 0:
		return {}
	var per := (data["index_data"] as PackedByteArray).size() / count
	var out := {}
	for lod in data.get("lods", []):
		var bytes := lod["index_data"] as PackedByteArray
		var indices := PackedInt32Array()
		if per == 4:
			indices = bytes.to_int32_array()
		else:
			indices.resize(bytes.size() / 2)
			for i in indices.size():
				indices[i] = bytes.decode_u16(i * 2)
		out[float(lod["edge_length"])] = indices
	return out


# How far the trunk's foot reaches from its middle, the model's metres: the
# bark's furthest vertex below OAK_FOOT, its root flare.
static func trunk_reach(mesh: ArrayMesh) -> float:
	var reach := 0.2
	for surface in mesh.get_surface_count():
		var material := mesh.surface_get_material(surface)
		if material == null or not material.resource_name.contains("Bark"):
			continue
		for v in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			if v.y < OAK_FOOT:
				reach = maxf(reach, Vector2(v.x, v.z).length())
	return reach


# The oak numbered `number` under `parent`, `height` metres tall, its trunk
# at `at` (x and z; its y is the ground's): sunk to `lowest.call(at, reach)`,
# the lowest ground within `reach` metres of `at`, less OAK_SINK. Named
# Oak_<number>, on OAK_LAYER, in the wind and outlined.
func plant(parent: Node, number: int, at: Vector3, height: float, lowest: Callable) -> MeshInstance3D:
	var all := meshes()
	var mesh := all[number % all.size()]
	var oak := MeshInstance3D.new()
	oak.name = "Oak_%d" % number
	oak.mesh = mesh
	var scale_by := height / mesh.get_aabb().end.y
	oak.basis = Basis(Vector3.UP, number * OAK_TURN).scaled(Vector3.ONE * scale_by)
	oak.position = Vector3(at.x, float(lowest.call(at, trunk_reach(mesh) * scale_by)) - OAK_SINK, at.z)
	oak.extra_cull_margin = Level3DWind.CULL_MARGIN
	oak.layers = OAK_LAYER
	parent.add_child(oak)
	sway(oak, OAK_GIVE)
	outline(oak)
	planted += 1
	return oak


# The material that draws its scene's frame with the oaks' outline over it,
# the haze's colour `fog_colour`; for the TextureRect the frame is shown on.
# The line `pixels` wide, or the stage's contour's (Level3DHull) by default.
func ink(fog_colour: Color, pixels := 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = OAK_INK_SHADER
	material.set_shader_parameter("mask", mask.get_texture())
	if pixels > 0.0:
		material.set_shader_parameter("pixels", pixels)
	else:
		Level3DHull.track(material)
	material.set_shader_parameter("fog_colour", fog_colour)
	return material


# An oak's double in the outline's mask (the header, and
# level3d_oak_ink.gdshader): its mesh again on MASK_LAYER, flat in its own
# colour -- its number in blue -- its leaves cut out and swaying as the
# oak's are, casting nothing.
func outline(oak: MeshInstance3D) -> void:
	var number := int(String(oak.name).trim_prefix("Oak_"))
	var double := MeshInstance3D.new()
	double.name = "Mask"
	double.mesh = oak.mesh
	double.layers = MASK_LAYER
	double.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	double.extra_cull_margin = oak.extra_cull_margin
	var crown := Level3DWind._crown(oak.mesh as ArrayMesh)
	for surface in oak.mesh.get_surface_count():
		var source := oak.mesh.surface_get_material(surface) as BaseMaterial3D
		var material := wind_material(OAK_MASK_SHADER)
		material.set_shader_parameter("mask_colour", Color(1.0, 0.0, (number % 16) / 16.0))
		material.set_shader_parameter("fog_density", fog_density)
		if source != null and source.albedo_texture != null:
			material.set_shader_parameter("albedo_tex", source.albedo_texture)
			material.set_shader_parameter("scissor", source.alpha_scissor_threshold)
		else:
			material.set_shader_parameter("scissor", 0.0)
		material.set_shader_parameter("wind_crown", crown.at)
		material.set_shader_parameter("wind_radius", crown.reach)
		material.set_shader_parameter("wind_flap", 0.0)
		material.set_shader_parameter("wind_give", OAK_GIVE)
		double.set_surface_override_material(surface, material)
	oak.add_child(double)


# A tree on level3d_wind.gdshaderinc: its crown the top of its trunk
# (Level3DWind's measure), or of its middle if it has none; no fronds to
# flap. An oak's leaves and its puffs' cores on level3d_leaf_wind.gdshader,
# the rest soft (level3d_wind_soft.gdshader); a contour, if it has one, goes
# with it (level3d_hull_wind.gdshader).
func sway(instance: MeshInstance3D, give: float) -> void:
	var mesh := instance.mesh as ArrayMesh
	if mesh == null:
		return
	instance.extra_cull_margin = Level3DWind.CULL_MARGIN
	if not _wind_made.has(mesh):
		var crown := Level3DWind._crown(mesh)
		if crown.is_empty():
			var box := mesh.get_aabb()
			crown = {"at": Vector3(0.0, box.end.y, 0.0), "reach": maxf(box.size.x, box.size.z) * 0.5}
		var made := []
		for surface in mesh.get_surface_count():
			var source := mesh.surface_get_material(surface)
			var material: ShaderMaterial = null
			if Level3DHull.is_hull(source):
				material = wind_material(Level3DWind.HULL_SHADER)
				Level3DHull.track(material)
			elif source is BaseMaterial3D and (source.resource_name.contains("Leaf")
					or source.resource_name.contains("Core")):
				var base := source as BaseMaterial3D
				material = wind_material(LEAF_WIND_SHADER)
				material.set_shader_parameter("albedo", base.albedo_color)
				if base.albedo_texture != null:
					material.set_shader_parameter("albedo_tex", base.albedo_texture)
				material.set_shader_parameter("scissor", base.alpha_scissor_threshold)
				material.set_shader_parameter("tint", tint)
			elif source is BaseMaterial3D and not source.resource_name.ends_with("Contour"):
				material = wind_material(WIND_SOFT_SHADER)
				material.set_shader_parameter("albedo", (source as BaseMaterial3D).albedo_color)
			if material != null:
				material.resource_name = source.resource_name
				material.set_shader_parameter("wind_crown", crown.at)
				material.set_shader_parameter("wind_radius", crown.reach)
				material.set_shader_parameter("wind_flap", 0.0)
				material.set_shader_parameter("wind_give", give)
			made.append(material)
		_wind_made[mesh] = made
	var materials: Array = _wind_made[mesh]
	for surface in materials.size():
		if materials[surface] != null:
			instance.set_surface_override_material(surface, materials[surface])


# A material on the oaks' wind and clock, for anything else in the scene that
# sways with them.
func wind_material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("wind_fps", Level3DWind.STEPPED_FPS if Level3DWind.is_stepped() else 0.0)
	material.set_shader_parameter("wind_clock", _clock)
	if OS.get_cmdline_user_args().has("--no-wind"):
		material.set_shader_parameter("wind_strength", 0.0)
	_wind.append(material)
	return material


# The wind `times` its strength; none under --no-wind.
func set_strength(times: float) -> void:
	if OS.get_cmdline_user_args().has("--no-wind"):
		return
	for material in _wind:
		material.set_shader_parameter("wind_strength", times)


# The wind's clock on by `delta` seconds.
func advance(delta: float) -> void:
	_clock += delta
	for material in _wind:
		material.set_shader_parameter("wind_clock", _clock)
