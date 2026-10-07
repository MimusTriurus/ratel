# The 3D preview's mission's end: the arena at the top of stage 1 once the
# boss is beaten, seen from behind and over the players' jeeps -- one, or
# two side by side -- turned in towards its middle, a flank showing as well
# as the tail; up the clearing the four heavy tanks they beat, burnt black
# where they stopped, smoking and burning; the jungle round it all. The
# picture the user chose (docs/renders/victory_2p.png): the evening's light,
# the camera high over the shoulder, the jeeps turned in.
#
# Built from jackal_victory.glb, which resources/3d/jackal_victory.blend
# exports (export_victory() in its jackal_victory.py): the ground -- the
# tanks' tracks, the soot round the wrecks and the craters in its vertices'
# colours -- the four wrecks, each the boss's tank (jackal_heavy_tank.glb)
# posed and baked there, the rocks, the debris and both cameras,
# VS_Camera_1P and VS_Camera_2P; and markers for what is made here:
#
#   * Car_Solo, or Car_1P and Car_2P: each player's jeep, the preview's own
#     vehicle (Level3DBtr) in his paint, with what the shop has sold him and
#     his launcher's step -- the jeep he finished the stage in -- idling, its
#     exhaust puffing (Level3DPuffs);
#   * Smoke_<k> and Fire_<k>: a wreck's fire and its column of smoke
#     (Level3DBurn, BlenderMCP's CelBurn): flames out of its open turret ring
#     where it has a Fire_<k>, one cloud of smoke rising off them, or off the
#     deck with none -- the marker's scale the column's height in Blender,
#     COLUMN of it here;
#   * Oak_<n>: the jungle, an oak each (Level3DOaks), as the game over's
#     cemetery has, as tall as its scale.
#
# Lit as the stage is, in two tones, not softly as the cemetery: the preview's
# _toon and contour reach every mesh in its tree, a SubViewport's too, and
# here they are done for its own as well, for tools/victory_shot.gd, which
# has no preview (both pass by what has them). The light is the stage's
# Golden hour (Level3DLighting) with the sun low from the right, as
# jackal_victory.py's "evening" has it: the sun's energy is the preview's
# calibration (level3d_preview.gd, _day_sun_energy). The oaks are as the
# cemetery's: soft, in the wind, outlined.
#
# The camera eases in, DOLLY metres over DOLLY_TIME, as the scene stands,
# and comes to rest where the glb has it: the frame chosen.
# Its own world in a SubViewport, as the cemetery's (Level3DGameOver).
class_name Level3DVictory
extends TextureRect

const SCENE_PATH := "res://resources/3d/jackal_victory.glb"
# The jungle is 463 oaks, each drawn twice (the mask's double) and in the
# sun's shadow, their leaves 57 000 triangles at full detail: the levels of
# detail the import made (Level3DOaks.oak_mesh) taken this many pixels of
# error sooner than the default's one. 40 million triangles a frame at 1,
# measured; the crowns are a mass of leaves at any of them.
const LOD_THRESHOLD := 4.0
# And only the oaks this near the jeeps cast a shadow, metres: the further
# ones' fall on other oaks and on the hills behind, where they read as
# nothing. Half the triangles again.
const SHADOW_REACH := 22.0
const DOLLY := 0.7
const DOLLY_TIME := 9.0

# The light: the stage's Golden hour (Level3DLighting.Preset.GOLDEN), its sun
# travelling as jackal_victory.py's "evening" sun does, (-0.88, -0.15, -0.36)
# in Blender's axes -- low, from the right.
const SUN_BLENDER := Vector3(-0.88, -0.15, -0.36)
# level3d_preview.gd's calibration of the sun for the two-tone light
# (_day_sun_energy): SUN_STRENGTH, SUN_GAIN_*, SUN_DIRECTION_BLENDER.z, SHADE,
# SUN_SHARE_COMPATIBILITY and AMBIENT_ON_LIT_COMPATIBILITY. Its TOON_EDGE.
const SUN_STRENGTH := 3.0
const SUN_GAIN_COMPATIBILITY := 0.85
const SUN_GAIN_FORWARD := 1.75
const DAY_SUN_HEIGHT := 0.7392
const DAY_SHADE := 0.3
const SUN_SHARE_COMPATIBILITY := 0.34
const AMBIENT_ON_LIT_COMPATIBILITY := 1.5
const TOON_EDGE := 0.02
const SHADOW_DISTANCE := 60.0
# The sky, sRGB as the Compatibility renderer takes it (Level3DGameOver's sky
# shader): jackal_victory.py's evening, warm at the horizon, rose, then blue.
const SKY: Array[Vector3] = [Vector3(1.0, 0.81, 0.60), Vector3(0.98, 0.79, 0.70), Vector3(0.58, 0.68, 0.87)]
# The oaks' crowns: Level3DOaks.OAK_TINT is the cemetery's, under its own
# sun; here under the stage's light.
const OAK_TINT := Vector3(0.75, 1.55, 2.2)
# Their outline, pixels (Level3DOaks.ink): not the stage's contour's 3, which
# the cemetery's few big oaks take. Here hundreds stand far off, a crown a few
# dozen pixels wide, and at 3 every gap in it was inked: black lace.
const OAK_INK_PIXELS := 1.5

# The wrecks' fires (Level3DBurn): the boss's tank's length on the stage,
# metres (Level3DBoss.SCALE of its 4.4 m); the column's height, a share of the
# marker's (jackal_victory.py's columns were drawn taller than a column of
# puffs stands); the fire's two ports across the open ring, apart by
# RING_APART metres and RING_LIFT over the marker, which is in the hull, each
# burning RING_FIRE times a grille's (CelBurn's RingFire).
const HULL := 1.36
const COLUMN := 0.42
const RING_APART := 0.12
const RING_LIFT := 0.1
const RING_FIRE := 1.3

var viewport: SubViewport
var shown := false

var _world: Node3D
var _scene: Node3D
var _cameras := {}            # players -> the glb's Camera3D
var _camera: Camera3D
var _camera_rest := Transform3D.IDENTITY
var _markers := {}            # Car_*, Smoke_*, Fire_* -> Transform3D
var _ground_mesh: TriangleMesh
var _ground_xform := Transform3D.IDENTITY
var _mask: SubViewport
var _mask_camera: Camera3D
var _oaks: Level3DOaks
var _puffs: Level3DPuffs
var _jeeps: Array[Level3DBtr] = []
var _burns: Array[Level3DBurn] = []
var _time := 0.0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	viewport.mesh_lod_threshold = LOD_THRESHOLD
	add_child(viewport)
	texture = viewport.get_texture()
	# The oaks' outline's mask (Level3DOaks): the same world from the same
	# camera, without the smoothing.
	_mask = SubViewport.new()
	_mask.world_3d = viewport.find_world_3d()
	_mask.msaa_3d = Viewport.MSAA_DISABLED
	_mask.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_mask.mesh_lod_threshold = LOD_THRESHOLD
	add_child(_mask)
	_mask_camera = Camera3D.new()
	_mask_camera.cull_mask = 0xFFFFF & ~Level3DOaks.OAK_LAYER
	_mask.add_child(_mask_camera)
	_build()
	visible = false


func _build() -> void:
	_world = Node3D.new()
	viewport.add_child(_world)
	var spec := Level3DLighting.spec(Level3DLighting.Preset.GOLDEN)
	var shade: float = spec["shade"]
	var hold: float = spec["hold"]
	var exposure: float = spec["exposure"]

	var sky_shader := Shader.new()
	sky_shader.code = Level3DGameOver.SKY_SHADER
	var sky_material := ShaderMaterial.new()
	sky_material.shader = sky_shader
	sky_material.set_shader_parameter("HORIZON", SKY[0])
	sky_material.set_shader_parameter("ROSE", SKY[1])
	sky_material.set_shader_parameter("HIGH", SKY[2])
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var ambient: Color = spec["ambient"]
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = shade * Level3DLighting.keep(ambient, Level3DLighting.GREY, hold) * exposure
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_world.add_child(world_environment)

	var sun := DirectionalLight3D.new()
	var sun_colour: Color = spec["sun"]
	sun.light_color = sun_colour
	sun.light_energy = _sun_energy(shade) * Level3DLighting.keep(sun_colour, Level3DLighting.GREY, hold) * exposure
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	_world.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, _from_blender(SUN_BLENDER).normalized(), Vector3.UP)
	var fill := DirectionalLight3D.new()
	fill.light_color = spec["fill_colour"]
	fill.light_energy = _sun_energy(DAY_SHADE) * float(spec["fill"]) * exposure
	_world.add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, _from_blender(Level3DLighting.fill_direction(SUN_BLENDER)).normalized(),
			Vector3.UP)

	_scene = (load(SCENE_PATH) as PackedScene).instantiate() as Node3D
	var ground := _scene.find_child("VS_Ground", true, false) as MeshInstance3D
	if Level3DGameOver._is_compatibility():
		Level3DGameOver._colours_to_srgb(ground)
	_ground_mesh = ground.mesh.generate_triangle_mesh()
	_ground_xform = Level3DGameOver._transform_in(ground, _scene)
	for n in 2:
		var camera := _scene.find_child("VS_Camera_%dP*" % (n + 1), true, false) as Camera3D
		if camera != null:
			camera.cull_mask = 0xFFFFF & ~Level3DOaks.MASK_LAYER
			_cameras[n + 1] = camera
	# The markers, read and taken out; the oaks planted on theirs.
	_oaks = Level3DOaks.new(_mask)
	_oaks.tint = OAK_TINT
	var oaks: Array[Node3D] = []
	for node in _scene.find_children("*", "Node3D", true, false):
		var marker := String(node.name)
		if marker.begins_with("Car_") or marker.begins_with("Smoke_") or marker.begins_with("Fire_"):
			_markers[marker] = Level3DGameOver._transform_in(node, _scene)
		elif marker.begins_with("Oak_") and not node is MeshInstance3D:
			oaks.append(node)
	for key in _markers:
		var node := _scene.find_child(key, true, false)
		node.get_parent().remove_child(node)
		node.free()
	_look(_scene)
	var number := 0
	for marker in oaks:
		var at := Level3DGameOver._transform_in(marker, _scene)
		marker.get_parent().remove_child(marker)
		marker.free()
		var oak := _oaks.plant(_scene, number, at.origin, at.basis.get_scale().y, _foot_ground)
		if Vector2(at.origin.x, at.origin.z).length() > SHADOW_REACH:
			oak.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		number += 1
	if number > 0:
		material = _oaks.ink(Color.BLACK, OAK_INK_PIXELS)
	_world.add_child(_scene)
	_puffs = Level3DPuffs.new()
	_puffs.ground = func(_x: float, _z: float) -> Dictionary: return {"height": 0.0, "kind": "ground", "hit": true}
	_world.add_child(_puffs)


# level3d_preview.gd's _day_sun_energy: the sun's energy for white light
# under an ambient of `shade`, as the stage calibrates it for the two-tone
# light.
static func _sun_energy(shade: float) -> float:
	var gain := SUN_GAIN_COMPATIBILITY if Level3DGameOver._is_compatibility() else SUN_GAIN_FORWARD
	gain *= DAY_SUN_HEIGHT
	if Level3DGameOver._is_compatibility():
		gain *= SUN_SHARE_COMPATIBILITY - AMBIENT_ON_LIT_COMPATIBILITY * (shade - DAY_SHADE)
	else:
		gain *= 1.0 - shade
	return SUN_STRENGTH / PI * gain


static func _from_blender(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)


# The stage's look on every mesh under `root`: the engine's contour in place
# of the baked one (Level3DHull) at `kind`'s width, and the two-tone light --
# level3d_preview.gd's _toon, for what is not in the preview's tree. The
# ground takes its colours from its vertices.
static func _look(root: Node, kind := Level3DHull.Kind.STAGE) -> void:
	var meshes := root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for node in meshes:
		var instance := node as MeshInstance3D
		Level3DHull.apply(instance, kind)
		if instance.mesh == null:
			continue
		for surface in instance.mesh.get_surface_count():
			var base := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if base == null or base.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON \
					or base.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
					or base.emission_enabled or base.resource_name.ends_with("Contour"):
				continue
			if instance.mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
				base.vertex_color_use_as_albedo = true
			base.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			base.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
			base.roughness = TOON_EDGE
			base.metallic = 0.0
			base.metallic_specular = 0.0


# The ground's height at (x, z): where a ray down meets it.
func _ground_at(x: float, z: float) -> float:
	var inverse := _ground_xform.affine_inverse()
	var hit := _ground_mesh.intersect_ray(inverse * Vector3(x, 100.0, z), inverse.basis * Vector3.DOWN)
	if hit.is_empty():
		return 0.0
	return (_ground_xform * (hit["position"] as Vector3)).y


# The lowest ground under a foot at `at` reaching `reach` metres round.
func _foot_ground(at: Vector3, reach: float) -> float:
	var low := _ground_at(at.x, at.z)
	for i in 8:
		var a := TAU * i / 8.0
		low = minf(low, _ground_at(at.x + cos(a) * reach, at.z + sin(a) * reach))
	return low


# The mission's end for the players whose paints are `paints` (Level3DBtr.
# PAINTS' ids) and whose kits are `kits` (Level3DRun.Kit, or none: the stock
# jeep): one or two.
func show_victory(paints: Array[String], kits: Array) -> void:
	clear()
	var players := clampi(maxi(paints.size(), kits.size()), 1, 2)
	var spots: Array[String] = ["Car_Solo"]
	if players == 2:
		spots = ["Car_1P", "Car_2P"]
	for i in players:
		var jeep := Level3DBtr.new()
		jeep.player = i
		_world.add_child(jeep)
		# The marker is turned as the model's root is, its +Z the nose; the
		# vehicle's nose is its +X.
		var spot: Transform3D = _markers.get(spots[i], Transform3D.IDENTITY)
		jeep.transform = Transform3D(spot.basis.orthonormalized() * Basis(Vector3.UP, -PI / 2.0), spot.origin)
		if i < paints.size():
			jeep.paint(paints[i])
		if i < kits.size():
			_dress(jeep, kits[i] as Level3DRun.Kit)
		_look(jeep, Level3DHull.Kind.VEHICLES)
		_jeeps.append(jeep)
	_camera = _cameras.get(players, _cameras.get(2)) as Camera3D
	if _camera != null:
		_camera_rest = _camera.transform
		_camera.current = true
		_mask_camera.current = true
	_puffs.sources = _jeeps.map(func(j: Level3DBtr): return j.puffs)
	_light_wrecks()
	_time = 0.0
	shown = true
	visible = true
	_tick_burns(0.0)


# Bay.dress's, for what the player has: the shop's upgrades on it, the
# launcher's fit at his step, the spares' rack's round one down.
static func _dress(jeep: Level3DBtr, kit: Level3DRun.Kit) -> void:
	jeep.set_upgrades(kit.upgrades)
	var step := kit.weapon()
	jeep.set_weapon_level(step)
	var prefix: String = jeep.vehicle.prefix
	for k in Level3DLauncher.FITS.size():
		var base := jeep.launcher_node(prefix + String(Level3DLauncher.FITS[k].base).trim_prefix("BTR_"))
		if base != null:
			base.visible = k == step


# Each wreck's fire and smoke (Level3DBurn), off its markers: its ports
# across the open ring as the camera sees it.
func _light_wrecks() -> void:
	var right := _camera.global_basis.x.normalized() if _camera != null else Vector3.RIGHT
	for key in _markers:
		if not String(key).begins_with("Smoke_"):
			continue
		var k := String(key).trim_prefix("Smoke_")
		var smoke := _markers[key] as Transform3D
		var burn := Level3DBurn.new()
		burn.hull = HULL
		burn.seed = int(k)
		burn.column = smoke.basis.get_scale().y * COLUMN
		var fire = _markers.get("Fire_" + k)
		burn.flames = fire != null
		if fire != null:
			var ring := (fire as Transform3D).origin + Vector3.UP * RING_LIFT
			burn.ports = [ring - right * RING_APART * 0.5, ring + right * RING_APART * 0.5]
			burn.sizes = [RING_FIRE, RING_FIRE]
		else:
			burn.ports = [smoke.origin]
		_world.add_child(burn)
		burn.build()
		_burns.append(burn)


func _tick_burns(delta: float) -> void:
	if _camera == null:
		return
	var eye := _camera.global_basis
	for burn in _burns:
		burn.tick(delta, eye)


func clear() -> void:
	for jeep in _jeeps:
		jeep.queue_free()
	_jeeps.clear()
	for burn in _burns:
		burn.queue_free()
	_burns.clear()
	if _puffs != null:
		_puffs.sources = []
		_puffs.reset()
	if _camera != null:
		_camera.transform = _camera_rest
	shown = false
	visible = false


func _process(delta: float) -> void:
	if not shown:
		return
	# The render the size of the frame it fills, in the screen's pixels, not
	# the frame's (Level3DPixels): blown up, its edges stepped. Smoothed as
	# the settings say, the oaks' mask never.
	var want := Vector2i(size * Level3DPixels.scale(self))
	viewport.msaa_3d = Level3DPixels.msaa
	if want.x > 0 and want.y > 0 and viewport.size != want:
		viewport.size = want
		_mask.size = want
	_time += delta
	_oaks.advance(delta)
	if _camera != null:
		var k := 1.0 - pow(1.0 - clampf(_time / DOLLY_TIME, 0.0, 1.0), 2.0)
		_camera.transform = _camera_rest.translated_local(Vector3(0.0, 0.0, DOLLY * (1.0 - k)))
		_mask_camera.global_transform = _camera.global_transform
		_mask_camera.fov = _camera.fov
		_mask_camera.near = _camera.near
		_mask_camera.far = _camera.far
		_mask_camera.keep_aspect = _camera.keep_aspect
	_tick_burns(delta)


func _physics_process(_delta: float) -> void:
	if shown:
		_puffs.tick()
