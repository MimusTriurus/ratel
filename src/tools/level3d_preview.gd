# A look at the low-poly 3D remake of stage 1 inside Godot, on its own scene
# rather than in the game, with the BTR driving on it:
#
#     godot --path . src/tools/level3d_preview.tscn
#
# Nothing here is part of the game, which stays 2D. The level is modelled in
# resources/3d/jackal_stage1_lowpoly.blend and comes in as jackal_stage1.glb,
# exported from Blender (visible objects, modifiers applied, no animation). It
# is a .glb rather than the .blend itself because project.godot keeps
# import/blender/enabled off, and the glTF route does not need Blender on the
# machine that imports it. The BTR is ratel_btr.glb; how it drives is
# level3d_btr.gd.
#
# The light is Blender's: the same sun direction, the scene's leftover 1000 W
# point light over the start area, the world colour as ambient light, and a
# linear tonemapper because the view transform was Standard. Strengths could
# not simply be converted -- Forward+ and Compatibility disagree with each
# other by about a factor of two -- so the sun's gain per renderer was measured
# against the same frame rendered in Blender (sand at the start of the stage).
# The project renders with Compatibility; add --rendering-method forward_plus
# for the closer match. The ocean's procedural Blender shader does not survive
# glTF; level3d_ocean.gdshader stands in for it, fed by the shore distance the
# export bakes into the ocean's vertex colours.
#
# The default view is the game's: straight down, orthographic, the frame exactly
# as wide as the level, 16:9, following the BTR up the stage. Tab switches to a
# tilted perspective view. The controls are the tank bench's in BlenderMCP/godot
# where the two overlap -- left click to send the vehicle somewhere, A/D and
# Q/E for hull and turret, M for mouse aim:
#
#   left click             drive there (shift: add a waypoint)
#   right click, Esc       stop
#   W / S, A / D           drive and steer by hand (cancels the order)
#   mouse                  aims the turret while mouse aim is on
#   Q / E                  turn the turret by hand; M toggles mouse aim
#   R                      put the BTR back at the start
#   wheel, arrows          scroll the camera off the BTR; C follows it again
#   + / -                  zoom
#   Tab                    top view / tilted view
#   Home / End             start / end of the level
#
# Like the map editor it can render one view and quit (a real window is needed,
# --headless has no framebuffer to read back):
#
#     godot --path . --windowed --resolution 1280x720 src/tools/level3d_preview.tscn \
#         -- --shot out.png <position 0-1> <zoom> <top|tilt> [<seconds> <x,z> ...]
#
# With seconds and waypoints the BTR is sent along them (level coordinates:
# x across, z up the stage is negative) and the frame is taken that many
# seconds later, the camera following it.
extends Node3D

const LEVEL_PATH := "res://resources/3d/jackal_stage1.glb"
const OCEAN_SHADER := preload("res://src/tools/level3d_ocean.gdshader")
const Btr := preload("res://src/tools/level3d_btr.gd")

# From the Blender scene: J_Sun points along this (Blender axes), strength 3.
const SUN_DIRECTION_BLENDER := Vector3(0.4265, -0.5212, -0.7392)
const SUN_STRENGTH := 3.0
# The scene's default point light, left in and rendered with.
const POINT_LIGHT_BLENDER := Vector3(4.076, 1.005, 5.904)
const POINT_LIGHT_WATTS := 1000.0
# Linear world colour and strength.
const WORLD_COLOR := Color(0.342, 0.552, 1.0)
const WORLD_STRENGTH := 0.12

const SUN_GAIN_COMPATIBILITY := 0.85
const SUN_GAIN_FORWARD := 1.75
const LAMP_GAIN := 0.3
# The top camera sits this far above the ground, which is as low as it can go
# over the tallest building; the shadow map only has to cover that depth.
const TOP_CAMERA_HEIGHT := 20.0

# Where the BTR starts: on the beach at the south end, facing up the stage, with
# nothing within four metres -- the obstacle map's say, not the eye's. It used
# to start at x = 0, a turning circle away from a clump of four palms, so every
# first turn east ended on a trunk.
const START := Vector3(-7.0, 0.0, 27.0)
const START_HEADING := PI / 2.0
# A ray from this high down to this low finds the top surface anywhere.
const RAY_TOP := 30.0
const RAY_BOTTOM := -5.0

const SCROLL_SPEED := 40.0
const ZOOM_STEP := 1.15

var camera: Camera3D
var sun: DirectionalLight3D
var btr: Level3DBtr
var level_aabb: AABB
var focus := Vector2.ZERO       # x, z the camera is centred on
var following := true
var mouse_aim := true
var zoom := 1.0
var tilted := false

var _live := false
var _kinds := {}        # body RID -> ground kind, see _add_collision
var _trunks := 0
var _markers: Array[MeshInstance3D] = []
var _marker_mesh: Mesh
var _marker_material: StandardMaterial3D


func _ready() -> void:
	var scene: PackedScene = load(LEVEL_PATH)
	if scene == null:
		push_error("Cannot load %s -- open the project in the editor once so it is imported" % LEVEL_PATH)
		return
	var level := scene.instantiate()
	add_child(level)
	_replace_ocean(level)
	level_aabb = _mesh_aabb(level)
	_cast_both_sides_of_planes(level)
	_add_collision(level)

	_add_environment()
	_add_lights()

	btr = Btr.new()
	btr.ground = _ground_at
	btr.solid = _solid_at
	add_child(btr)
	_make_markers()

	camera = Camera3D.new()
	add_child(camera)
	camera.current = true

	# The level's collision exists from the next physics frame on; the BTR is
	# placed after it, or it would sit on nothing.
	await get_tree().physics_frame
	await get_tree().physics_frame
	btr.place(START, START_HEADING)
	focus = Vector2(btr.position.x, btr.position.z)
	_update_camera()
	_live = true

	_screenshot_mode()


static func _is_compatibility() -> bool:
	return RenderingServer.get_current_rendering_method() == "gl_compatibility"


# Blender Z-up to Godot Y-up, which is what the glTF exporter did to the level.
static func _from_blender(v: Vector3) -> Vector3:
	return Vector3(v.x, v.z, -v.y)


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = (WORLD_COLOR * WORLD_STRENGTH).linear_to_srgb()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = WORLD_COLOR.linear_to_srgb()
	env.ambient_light_energy = WORLD_STRENGTH
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _add_lights() -> void:
	sun = DirectionalLight3D.new()
	add_child(sun)
	var direction := _from_blender(SUN_DIRECTION_BLENDER).normalized()
	sun.look_at_from_position(Vector3.ZERO, direction, Vector3.FORWARD)
	# The two renderers disagree by about a factor of two, so the gain is
	# measured rather than derived: sand at the start of the stage matched
	# against the same frame rendered in Blender.
	var gain := SUN_GAIN_COMPATIBILITY if _is_compatibility() else SUN_GAIN_FORWARD
	sun.light_energy = SUN_STRENGTH / PI * gain
	sun.shadow_enabled = true

	# Only a faint warm spot over the start area in Blender, and its shadows
	# there are lost under the sun's; here they come out as long radial streaks,
	# so the lamp casts none.
	var lamp := OmniLight3D.new()
	add_child(lamp)
	lamp.position = _from_blender(POINT_LIGHT_BLENDER)
	lamp.light_energy = POINT_LIGHT_WATTS / (4.0 * PI * PI) * LAMP_GAIN
	# Godot's omni falloff is 1 / d^attenuation; Blender's is inverse square.
	lamp.omni_attenuation = 2.0
	lamp.omni_range = 60.0


func _replace_ocean(level: Node) -> void:
	var ocean := level.find_child("Ocean", true, false) as MeshInstance3D
	if ocean == null:
		push_warning("No Ocean node in %s" % LEVEL_PATH)
		return
	var water := ShaderMaterial.new()
	water.shader = OCEAN_SHADER
	ocean.material_override = water
	# The water is drawn in the transparent pass, because it reads the screen;
	# it casts nothing either way.
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Palm fronds and the like are single planes, and Compatibility culls front
# faces in the shadow pass, which drops every plane that faces the sun -- their
# shadows vanish unless both sides cast. Only for those, though: the ground
# casting both ways shadows itself and comes out dark and striped.
func _cast_both_sides_of_planes(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box := mesh_instance.get_aabb()
		if box.size.x * box.size.z > 25.0:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and material.cull_mode == BaseMaterial3D.CULL_DISABLED:
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				break


# What the BTR may not drive into is decided here, by what each object of the
# level is -- its Blender name -- rather than by how tall it is. Four things
# stop it: water, palm trunks, the dense forest and walls. Everything else is
# ground or is not there at all for driving: bunkers, barracks, hangars,
# sandbags, rocks and the rest get no collision.
#
# Two layers, for two kinds of question. The ground layer is what a downward
# ray finds: its height, and which kind it is -- the sea, the forest floor
# (the forest is the seven Forest_Floor patches its 3412 trees stand on, 98% of
# them; a tree is a crown, not something to hit), a wall, or plain ground. The
# solid layer is what the hull's footprint is tested against: walls, and a
# cylinder round every palm trunk, since a trunk is thinner than the gap
# between two ground probes and a crown is not an obstacle at all.
const GROUND_LAYER := 1
const SOLID_LAYER := 2
const GROUND_NAMES: Array[String] = ["Land_Base", "Beach", "Cliff", "Skirt",
		"Terrain", "Bridge", "Helipad", "Gate_Sill"]
const WALL_NAMES: Array[String] = ["Wall", "Merlon", "GatePost", "Gate_"]
# A trunk is solid up to about the BTR's roof; above that it leans into the
# crown, which the hull passes under.
const TRUNK_REACH := 1.2
const TRUNK_FOOT := 0.4


static func _kind_of(object_name: String) -> String:
	if object_name.begins_with("Ocean"):
		return "water"
	if object_name.begins_with("Forest_Floor"):
		return "forest"
	if object_name.begins_with("Palm"):
		return "trunk"
	if object_name == "Sand":
		return "ground"     # not a prefix: Sandbag is not ground
	for prefix in GROUND_NAMES:
		if object_name.begins_with(prefix):
			return "ground"
	# A hangar's apron is ground; the hangar is not in the way.
	if object_name.begins_with("Hangar") and object_name.ends_with("_Pad"):
		return "ground"
	for prefix in WALL_NAMES:
		if object_name.begins_with(prefix):
			return "wall"
	return ""


func _add_collision(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var kind := _kind_of(mesh_instance.name)
		if kind == "":
			continue
		if kind == "trunk":
			_add_trunk(mesh_instance)
			continue
		mesh_instance.create_trimesh_collision()
		for child in mesh_instance.get_children():
			if child is StaticBody3D:
				child.collision_layer = GROUND_LAYER | (SOLID_LAYER if kind == "wall" else 0)
				_kinds[child.get_rid()] = kind
				# Both sides: the northern terrain's faces are wound downwards,
				# which its double-sided material hides from the eye and a
				# one-sided shape does not -- the ray went through the land
				# and found the sea under it.
				for shape_owner in child.get_children():
					if shape_owner is CollisionShape3D:
						(shape_owner.shape as ConcavePolygonShape3D).backface_collision = true


# A cylinder round the bottom of the trunk: the trunk surface's own vertices
# below TRUNK_REACH, measured rather than assumed, because palms lean.
func _add_trunk(palm: MeshInstance3D) -> void:
	var trunk := PackedVector3Array()
	var base := INF
	for surface in palm.mesh.get_surface_count():
		var material := palm.mesh.surface_get_material(surface)
		if material == null or not material.resource_name.contains("Trunk"):
			continue
		var vertices: PackedVector3Array = palm.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			var w := palm.global_transform * v
			base = minf(base, w.y)
			trunk.append(w)
	if trunk.is_empty():
		push_warning("%s has no trunk surface; it will not stop the BTR" % palm.name)
		return
	# Measured at the foot, not over the whole reach: a leaning trunk's lower
	# metre spans half a metre sideways, and a circle round all of it is a
	# post twice as thick as the one on screen.
	var low := PackedVector2Array()
	for w in trunk:
		if w.y < base + TRUNK_FOOT:
			low.append(Vector2(w.x, w.z))
	var box := Rect2(low[0], Vector2.ZERO)
	for p in low:
		box = box.expand(p)
	var shape := CylinderShape3D.new()
	shape.radius = maxf(box.size.x, box.size.y) * 0.5
	shape.height = TRUNK_REACH
	var body := StaticBody3D.new()
	body.collision_layer = SOLID_LAYER
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	var centre := box.get_center()
	body.global_position = Vector3(centre.x, base + TRUNK_REACH * 0.5, centre.y)
	_trunks += 1


# The top of the ground layer at x, z, and which kind it is.
func _ground_at(x: float, z: float) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, RAY_TOP, z), Vector3(x, RAY_BOTTOM, z),
			GROUND_LAYER)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {"height": 0.0, "kind": "", "hit": false}
	return {"height": hit.position.y, "kind": _kinds.get(hit.rid, "ground"), "hit": true}


# Whether a box at `pose` overlaps anything on the solid layer.
func _solid_at(pose: Transform3D, half: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.collision_mask = SOLID_LAYER
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _make_markers() -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 0.35
	ring.outer_radius = 0.5
	ring.rings = 24
	ring.ring_segments = 6
	_marker_mesh = ring
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.albedo_color = Color(1.0, 1.0, 1.0, 0.85)
	_marker_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _sync_markers() -> void:
	while _markers.size() < btr.waypoints.size():
		var marker := MeshInstance3D.new()
		marker.mesh = _marker_mesh
		marker.material_override = _marker_material
		marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(marker)
		_markers.append(marker)
	for i in _markers.size():
		var shown := i < btr.waypoints.size()
		_markers[i].visible = shown
		if shown:
			var at: Vector3 = btr.waypoints[i]
			var ground: Dictionary = _ground_at(at.x, at.z)
			_markers[i].position = Vector3(at.x, ground.height + 0.05, at.z)


func _mesh_aabb(root: Node) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _update_camera() -> void:
	var width := level_aabb.size.x / zoom
	var half_width := width * 0.5
	var half_height := width * 9.0 / 32.0
	# The frame stays on the level: at zoom 1 it is exactly the level's width,
	# so x is pinned to the middle, as the game's camera_x is.
	focus.x = clampf(focus.x, level_aabb.position.x + half_width, level_aabb.end.x - half_width)
	focus.y = clampf(focus.y, level_aabb.position.z + half_height, level_aabb.end.z - half_height)
	if tilted:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 40.0
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		var distance := width * 1.2
		var target := Vector3(focus.x, 0.0, focus.y)
		camera.look_at_from_position(target + Vector3(0.0, distance * 0.8, distance * 0.6), target)
		camera.near = 0.5
		camera.far = 1000.0
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
		sun.directional_shadow_max_distance = 250.0
	else:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.size = width
		camera.position = Vector3(focus.x, TOP_CAMERA_HEIGHT, focus.y)
		camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		camera.near = 1.0
		camera.far = TOP_CAMERA_HEIGHT * 2.0
		# Straight down, every ground point is at the same depth, so cascades
		# buy nothing and a single map over the whole depth is sharpest.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = TOP_CAMERA_HEIGHT * 2.0


func _cursor_on_ground():
	var mouse := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse)
	var normal := camera.project_ray_normal(mouse)
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + normal * 500.0))
	if hit.is_empty():
		return null
	return hit.position


func _physics_process(delta: float) -> void:
	if not _live:
		return
	btr.throttle = _axis(KEY_S, KEY_W)
	btr.steer = _axis(KEY_D, KEY_A)
	btr.turret_input = _axis(KEY_E, KEY_Q)
	if btr.turret_input != 0.0:
		mouse_aim = false
	btr.aim_point = _cursor_on_ground() if mouse_aim else null
	btr.step(delta)
	_sync_markers()


func _process(delta: float) -> void:
	if not _live:
		return
	var scroll := _axis(KEY_DOWN, KEY_UP)
	if scroll != 0.0:
		following = false
		focus.y -= scroll * SCROLL_SPEED / zoom * delta
	if following:
		focus = Vector2(btr.position.x, btr.position.z)
	_update_camera()


static func _axis(negative: Key, positive: Key) -> float:
	return (1.0 if Input.is_key_pressed(positive) else 0.0) \
			- (1.0 if Input.is_key_pressed(negative) else 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not _live:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom = maxf(zoom / ZOOM_STEP, 1.0)
			KEY_EQUAL, KEY_KP_ADD:
				zoom = minf(zoom * ZOOM_STEP, 8.0)
			KEY_TAB:
				tilted = not tilted
			KEY_HOME:
				following = false
				focus.y = level_aabb.end.z
			KEY_END:
				following = false
				focus.y = level_aabb.position.z
			KEY_C:
				following = true
			KEY_M:
				mouse_aim = not mouse_aim
			KEY_R:
				btr.place(START, START_HEADING)
				following = true
			KEY_ESCAPE:
				btr.stop()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var at = _cursor_on_ground()
				if at != null:
					btr.order(at, event.shift_pressed)
			MOUSE_BUTTON_RIGHT:
				btr.stop()
			MOUSE_BUTTON_WHEEL_UP:
				following = false
				focus.y -= 2.0 / zoom
			MOUSE_BUTTON_WHEEL_DOWN:
				following = false
				focus.y += 2.0 / zoom


# What the BTR's two questions answer over the whole level, one pixel per
# OBSTACLE_STEP metres, north up: ground grey, water blue, forest green, walls
# red, trunks orange, off the level black. Needs no window -- physics runs
# headless -- so it is the check for _add_collision:
#
#     godot --path . --headless src/tools/level3d_preview.tscn -- --obstacle-map out.png
const OBSTACLE_STEP := 0.25
const OBSTACLE_COLOURS := {
	"ground": Color(0.62, 0.58, 0.50), "water": Color(0.15, 0.35, 0.85),
	"forest": Color(0.10, 0.50, 0.20), "wall": Color(0.85, 0.15, 0.10),
	"trunk": Color(1.0, 0.55, 0.0), "": Color.BLACK,
}


func _obstacle_map(path: String) -> void:
	var width := int(level_aabb.size.x / OBSTACLE_STEP)
	var height := int(level_aabb.size.z / OBSTACLE_STEP)
	var image := Image.create(width, height, false, Image.FORMAT_RGB8)
	var cell := Vector3(OBSTACLE_STEP, 2.0, OBSTACLE_STEP) * 0.5
	var counts := {}
	for py in height:
		for px in width:
			var x := level_aabb.position.x + (px + 0.5) * OBSTACLE_STEP
			var z := level_aabb.position.z + (py + 0.5) * OBSTACLE_STEP
			var there := _ground_at(x, z)
			var kind: String = there.kind if there.hit else ""
			if kind == "ground" and _solid_at(Transform3D(Basis(), Vector3(x, there.height + 1.0, z)), cell):
				kind = "trunk"
			counts[kind] = counts.get(kind, 0) + 1
			image.set_pixel(px, py, OBSTACLE_COLOURS[kind])
	image.save_png(path)
	print("obstacle map %dx%d, %d trunks: %s" % [width, height, _trunks, counts])
	# And the forest the other way round: what the ground under each forest
	# tree says it is. Anything but "forest" is a tree the BTR drives under.
	var under := {}
	var loose := []
	for tree in find_children("ForestTree*", "MeshInstance3D", true, false):
		var at: Vector3 = tree.global_position
		var kind: String = _ground_at(at.x, at.z).kind
		under[kind] = under.get(kind, 0) + 1
		if kind != "forest" and loose.size() < 12:
			loose.append(Vector2(snappedf(at.x, 0.1), snappedf(at.z, 0.1)))
	print("ground under forest trees: %s, e.g. %s" % [under, loose])


func _screenshot_mode() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--obstacle-map":
		_obstacle_map(args[1])
		get_tree().quit()
		return
	if args.size() < 2 or args[0] != "--shot":
		return
	if args.size() >= 3:
		following = false
		focus.y = lerpf(level_aabb.end.z, level_aabb.position.z, float(args[2]))
	if args.size() >= 4:
		zoom = float(args[3])
	if args.size() >= 5:
		tilted = args[4] == "tilt"
	mouse_aim = false
	if args.size() >= 6:
		for i in range(6, args.size()):
			var xz := args[i].split(",")
			btr.order(Vector3(float(xz[0]), 0.0, float(xz[1])), true)
		following = true
		await get_tree().create_timer(float(args[5])).timeout

	# Shadows and the first frame's pipeline compilation need a few frames.
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(args[1])
	if error != OK:
		push_error("Cannot write %s (error %d)" % [args[1], error])
	get_tree().quit()
