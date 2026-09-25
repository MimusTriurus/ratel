# A look at the low-poly 3D remake of stage 1 inside Godot, on its own scene
# rather than in the game, with the BTR driving on it:
#
#     godot --path . src/tools/level3d_preview.tscn
#
# Nothing here is part of the game, which stays 2D. The level is modelled in
# resources/3d/jackal_stage1_lowpoly.blend and comes in as jackal_stage1.glb,
# exported from Blender (visible objects, modifiers applied, no animation; the
# buildings that can be destroyed come separately, see _add_destructibles). It
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
# The default view is a tilted perspective one, following the BTR up the
# stage; Tab switches to the game's, straight down, orthographic, the frame
# exactly as wide as the level, 16:9. The controls are the game's -- WASD to
# drive, the left button or L to fire the gun up the screen, the right button
# or P for the rocket, as the game's jeep does; M hands the aim to the mouse --
# with the tank bench's orders from BlenderMCP/godot moved to the middle
# button. WASD drives one of two ways
# (level3d_btr.gd): classic, the game's jeep, eight directions at its speed,
# or free, a throttle and a wheel:
#
#   W / A / S / D          classic: up, left, down, right, and the diagonals
#                          free: drive and steer by hand
#                          either: cancels the order
#   V                      classic / free driving, shown by the score
#   mouse                  aims the turret while mouse aim is on; with it off,
#                          classic fires the gun up the screen and the rocket
#                          the way the BTR drives, as the game's jeep does
#   left button (held), L  machine gun, level3d_gun.gd
#   right click, P         rocket, level3d_rocket.gd -- L and P are for
#                          classic driving with the mouse off, under the
#                          right hand while the left is on WASD. Classic,
#                          both are the game's weapons: the gun fires on the
#                          press and, held, slowly or at turbo's rate (T
#                          toggles; the game's setting to start with), and the
#                          rocket goes while the button is held, one at a time
#   middle click           drive there (shift: add a waypoint)
#   Esc                    stop
#   Q / E                  turn the turret by hand; M toggles mouse aim
#   R                      fly the BTR in again, rebuild what was blown up
#                          and bring the bunkers' guns, the soldiers, the boats,
#                          the tanks and the boss back
#   Space                  skip the Chinook: the BTR is simply there
#   wheel, arrows          scroll the camera off the BTR; C follows it again
#   + / -                  zoom
#   Tab                    tilted view / top view
#   Home / End             start / end of the level
#
# Like the map editor it can render one view and quit (a real window is needed,
# --headless has no framebuffer to read back):
#
#     godot --path . --windowed --resolution 1280x720 src/tools/level3d_preview.tscn \
#         -- --shot out.png <position 0-1 or x,z> <zoom> <top|tilt> [<seconds> <x,z> ...] \
#            [--destroy <name>,...] [--fire <x,z>] [--rocket <x,z>[@<seconds>]] [--immortal]
#            [--at <x,z>] [--free] [--hold <keys>@<from>-<to>[,...]] [--weapon <0-3>]
#            [--intro] [--pows <n>]
#
# The bunkers' guns, the enemy soldiers, the two boats on the river, the two
# brown tanks and the boss's four heavy tanks at the top of the stage fight back
# as they do in the game (level3d_guns.gd, level3d_soldiers.gd,
# level3d_boats.gd, level3d_tanks.gd, level3d_boss.gd, on the game's own map
# through level3d_map.gd); the boss takes the camera to its arena and keeps it
# there, as the game's does. One round kills the BTR, which comes back where
# it died after a pause, blinking while it cannot be hit. --immortal lets the
# enemies' rounds pass it (running into a gun or a tank still kills it), and a
# --shot prints what the enemies do.
#
# The frame is taken that many seconds later; with waypoints the BTR is sent
# along them first (level coordinates: x across, z up the stage is negative)
# and the camera follows it. --destroy sets the named buildings off at the
# start -- DESTRUCTIBLE_NAMES has the names -- --fire aims at x,z and holds
# the trigger down from the start, and --rocket aims at x,z and sends one
# rocket as soon as the launcher has come round, or that many seconds in.
# --at puts the BTR at x,z to begin with instead of at START. --free drives
# the free way; --hold holds WASD, L or P down from one second to another, as
# many spans as are given (wd@0-1.5,a@2-3), which is how the classic keys
# are checked. --weapon starts with what the prisoners would have given: 0 the
# grenade, 1 to 3 the missile and its two upgrades. --pows starts with that
# many prisoners aboard, for the rescue helicopter.
#
# The BTR's rear wheels and the tanks' tracks leave marks on the ground that
# fade in under seven seconds (level3d_tracks.gd); the game leaves none.
#
# The prisoners the BTR picks up go home by helicopter, as the game's do: one
# flies up the stage on row 161 and lands on the Helipad, and the prisoners
# get off by it and walk aboard while the BTR waits east of it
# (level3d_rescue.gd).
#
# The stage opens as the game's does: a Chinook flies the BTR in, backs it out
# down its ramp and flies off, and only then is it the player's, at
# IntroPlayer's spot rather than START (level3d_chinook.gd). A --shot starts
# without it, at START, unless --intro is given, when the seconds count from
# the Chinook's arrival.
#
# The vehicle is the jeep; --btr, with or without --shot, drives the BTR
# instead (level3d_btr.gd, VEHICLES): the same driving, stiffer springs and
# no aerials.
#
# The soldiers are the model sheet's trooper; --sprite-soldiers, with or
# without --shot, draws them as the figure made from the game's sprite
# (level3d_soldiers.gd, MODELS).
extends Node3D

const LEVEL_PATH := "res://resources/3d/jackal_stage1.glb"
const OCEAN_SHADER := preload("res://src/tools/level3d_ocean.gdshader")
const Btr := preload("res://src/tools/level3d_btr.gd")

# From the Blender scene: J_Sun points along this (Blender axes), strength 3.
const SUN_DIRECTION_BLENDER := Vector3(0.4265, -0.5212, -0.7392)
const SUN_STRENGTH := 3.0
# Linear world colour and strength.
const WORLD_COLOR := Color(0.342, 0.552, 1.0)
const WORLD_STRENGTH := 0.12

const SUN_GAIN_COMPATIBILITY := 0.85
const SUN_GAIN_FORWARD := 1.75
const WATER_GAIN_COMPATIBILITY := 1.1
# The top camera sits this far above the ground, which is as low as it can go
# over the tallest building; the shadow map only has to cover that depth.
const TOP_CAMERA_HEIGHT := 20.0
# Where the sea was cut off west when the level was built (level3d-pipeline.md,
# section 2), and the frame's west edge still; the water goes on past it.
const SEA_WEST := -27.0

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
var gun: Level3DGun
var launcher: Level3DLauncher
var guns: Level3DGuns
var soldiers: Level3DSoldiers
var friends: Level3DFriends
var rescue: Level3DRescue
var tracks: Level3DTracks
var boats: Level3DBoats
var tanks: Level3DTanks
var boss: Level3DBoss
var map: Level3DMap
var chinook: Level3DChinook     # while it is flying the BTR in
var level_aabb: AABB
var focus := Vector2.ZERO       # x, z the camera is centred on
var following := true
var mouse_aim := false  # M; off, classic fires as the game's jeep does
var zoom := 1.0
var tilted := true      # Tab; the top view is the game's

var _live := false
var _forced_aim = null  # --fire's or --rocket's target
var _hold_fire := false # --fire: the gun's trigger held throughout
# How much longer a right click waits to be a rocket; see _physics_process.
var _rocket_wanted := 0.0
const ROCKET_WAIT := 0.8
var _kinds := {}        # body RID -> ground kind, see _add_collision
var _trunks := 0
var _markers: Array[MeshInstance3D] = []
var _marker_mesh: Mesh
var _marker_material: StandardMaterial3D


func _ready() -> void:
	# Before anything is added: every mesh from here on, the level's and every
	# unit's, spawned now or later, is lit in two tones (_toon).
	get_tree().node_added.connect(_toon)
	var scene: PackedScene = load(LEVEL_PATH)
	if scene == null:
		push_error("Cannot load %s -- open the project in the editor once so it is imported" % LEVEL_PATH)
		return
	var level := scene.instantiate()
	add_child(level)
	_replace_ocean(level)
	# The level goes on past its edges, forest, beach and sea, for the tilted
	# camera to look over (jackal_level_edges.py); the frame stays where the
	# level was: at the map's end north, as the game's does at row 0, at the
	# sea's old edge west, and at the land's east, leaving out the strip past
	# it, Beyond_*, and the sea, which runs under that strip.
	level_aabb = _mesh_aabb(level, ["Beyond", "Ocean"])
	var corner := Vector3(SEA_WEST, level_aabb.position.y, maxf(level_aabb.position.z, Level3DMap.ORIGIN.y))
	level_aabb = AABB(corner, level_aabb.end - corner)
	_cast_both_sides_of_planes(level)
	_flat_ground_casts_nothing(level)
	_add_collision(level)
	_add_targets(level, false)
	_add_destructibles()

	_add_environment()
	_add_lights()

	btr = Btr.new()
	btr.ground = _hull_ground_at
	add_child(btr)
	gun = Level3DGun.new()
	gun.btr = btr
	gun.ground = _ground_at
	gun.surface = _surface_at
	# The game's own switch, as the game last saved it.
	var mapping := ButtonMapping.new()
	mapping.load_saved()
	gun.turbo = mapping.turbo
	add_child(gun)
	launcher = Level3DLauncher.new()
	launcher.btr = btr
	launcher.ground = _ground_at
	launcher.surface = _surface_at
	launcher.exploded = _on_exploded
	add_child(launcher)
	_add_guns(level)
	btr.map = map
	_make_markers()
	_make_hud()

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

	var args := OS.get_cmdline_user_args()
	if args.has("--intro") or not (args.has("--shot") or args.has("--obstacle-map")):
		_start_intro()
	_screenshot_mode()


# The Chinook's run, from the top: Triggers.CHINOOK, which the stage fires on
# its first row. Nothing is the player's until it is over.
func _start_intro() -> void:
	if chinook != null:
		chinook.queue_free()
	chinook = Level3DChinook.new()
	chinook.ground = _ground_at
	chinook.btr = btr
	chinook.enlarge = not tilted
	chinook.finished = func():
		chinook = null
		following = true
		# Player.make_invincible.
		_invincible = Player.INVINCIBLE_DELAY
		_blink = 0
	add_child(chinook)
	following = true


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
	# Measured with Lambert light, under which the sand took the sun times
	# N.L, the sun's height; _toon's lit side takes all of it, so the same
	# sand wants the sun that much weaker.
	gain *= -SUN_DIRECTION_BLENDER.z
	sun.light_energy = SUN_STRENGTH / PI * gain
	sun.shadow_enabled = true

	# No lamp. The Blender scene's default point light is still in it, and
	# was rendered with here as a faint warm spot over the start area; but a
	# point light falls off with distance, which is a gradient across the sand,
	# and the two-tone light (_toon) is there to have none.


func _replace_ocean(level: Node) -> void:
	var ocean := level.find_child("Ocean", true, false) as MeshInstance3D
	if ocean == null:
		push_warning("No Ocean node in %s" % LEVEL_PATH)
		return
	var water := ShaderMaterial.new()
	water.shader = OCEAN_SHADER
	# The sun _add_lights weakened for the two-tone light, given back to the
	# water, which is still Lambert: all of it under Forward+, where the water
	# is as bright as it was at 1 / N.L; Compatibility's, measured the same way,
	# needs less.
	water.set_shader_parameter("sun_gain", WATER_GAIN_COMPATIBILITY if _is_compatibility()
			else 1.0 / -SUN_DIRECTION_BLENDER.z)
	ocean.material_override = water
	# The water is drawn in the transparent pass, because it reads the screen;
	# it casts nothing either way.
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# Two-tone light, docs/cel-shading.md, section 5: a face is lit or it is not,
# with no gradient between. DIFFUSE_TOON steps N.L at zero, over a band as
# wide as the roughness, so the roughness goes down to TOON_EDGE -- at the
# glb's 0.5 to 1 the step is as soft as Lambert. The low roughness would turn
# every sunlit face into a highlight, the sand included (the camera looks
# down, the half vector is 20 degrees off the ground's normal), so there is no
# specular and no reflection -- the background's, which at that roughness is
# a sheen on every face -- and no metal, which trades diffuse for reflection.
#
# Not the contour's material, black whatever the light; not what glows, the
# flashes, the fire and the lamps; not a ShaderMaterial, the water and the
# boat's wake, whose light is their shaders' own. Materials are the glbs'
# shared resources, so each is changed once, and the copies the soldiers and
# prisoners make of theirs to blink are made after this and keep it.
const TOON_EDGE := 0.02

func _toon(node: Node) -> void:
	var mesh_instance := node as MeshInstance3D
	if mesh_instance == null:
		return
	var materials: Array[Material] = [mesh_instance.material_override]
	if mesh_instance.mesh != null:
		for surface in mesh_instance.mesh.get_surface_count():
			materials.append(mesh_instance.mesh.surface_get_material(surface))
			materials.append(mesh_instance.get_surface_override_material(surface))
	for material in materials:
		var base := material as BaseMaterial3D
		if base == null or base.diffuse_mode == BaseMaterial3D.DIFFUSE_TOON \
				or base.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL \
				or base.emission_enabled or base.resource_name.ends_with("Contour"):
			continue
		base.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		base.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		base.roughness = TOON_EDGE
		base.metallic = 0.0
		base.metallic_specular = 0.0


# Palm fronds and the like are single planes, and Compatibility culls front
# faces in the shadow pass, which drops every plane that faces the sun -- their
# shadows vanish unless both sides cast. Only for those, though: the ground
# casting both ways shadows itself and comes out dark and striped.
#
# Which those are is the foliage's materials to say. It used to be any small
# mesh with a double-sided material, but Blender exports every material
# double-sided, so that took in the bunkers, the rocks and every building --
# and a solid casting both ways shadows itself as the ground did: the hangars'
# curved roofs came out striped and cut into dark wedges, more or less as the
# camera, and the shadow map with it, moved. A solid casts its whole
# silhouette from one side of its faces, provided they are all wound outward.
# The hangars' were not -- eight of ten faces of each wound inward, all of
# the ruined shell -- and double-sided casting had been hiding it; they are
# wound outward in the stage file now.
const FOLIAGE_MATERIALS: Array[String] = ["Frond", "Leaf"]

func _cast_both_sides_of_planes(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null and material.cull_mode == BaseMaterial3D.CULL_DISABLED \
					and FOLIAGE_MATERIALS.any(func(part): return material.resource_name.contains(part)):
				mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				break


# The level's flat ground casts no shadow. A flat plane has nothing to shadow
# but itself, and does even that badly where it meets another: the stage is
# cut into 30 m pieces, some wound up and some down (Terrain_North to _North3
# face down, Sand and Terrain_North4 up), and along the edge between a piece
# that casts and one that does not the caster's edge left a dark line across
# the whole level -- at z = -105 and at z = -15. The pieces with a drop in them
# (the river's banks) are not flat and still cast.
#
# Nor does the slab under it all, Land_Base and Land_Base_North. It is buried
# -- Land_Base's top is 1 cm under the sand -- so it has nothing to shadow, but
# the edge of its shadow came up through the bias as a thin dashed line along
# the one seam it ends at, z = -15, across sand, beach and all.
#
# Nor do the black lines along the beach's bands, Shore_Lines (jackal_cel.py,
# shore_lines): 3 mm over the ground, and not flat by FLAT only because the
# green band slopes 4 cm to the cliff.
const FLAT := 0.02

func _flat_ground_casts_nothing(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box := mesh_instance.get_aabb()
		if box.size.x * box.size.z > 25.0 and box.size.y <= FLAT \
				or mesh_instance.name.begins_with("Land_Base") 				or mesh_instance.name == "Shore_Lines":
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# The scene's collision, decided by what each object of the level is -- its
# Blender name -- rather than by how tall it is. It is not what stops anything
# any more: the BTR, its rounds and its rockets all go by the game's grid, in
# both modes (level3d_btr.gd, level3d_gun.gd, level3d_rocket.gd). It is what
# the hull sits on, and where a round or a rocket is seen to strike: how high,
# and on what.
#
# Two layers, for two kinds of question. The ground layer is what a downward
# ray finds: its height, and which kind it is -- the sea, the forest floor
# (the forest is the eight Forest_Floor patches its 3678 trees stand on, 98% of
# them; a tree is a crown, not something to hit), a wall, or plain ground. The
# solid layer is what stands up out of it: walls, and a cylinder round every
# palm trunk, which a round aimed past the palm's crown should still meet.
const GROUND_LAYER := 1
const SOLID_LAYER := 2
# A third, for the gun only: what stops a round but not the BTR -- bunkers,
# sandbags, rocks and the buildings that can be blown up. Kind "building".
const TARGET_LAYER := 4
const TARGET_NAMES: Array[String] = ["Bunker", "Sandbag", "Rock"]
# A fourth, for the hull only: the ramp over a bunker whose gun is gone
# (_add_bunker_ramp). Kind "ruin".
const RAMP_LAYER := 8
# The parts of a destruction that are not there to be hit: the blast itself and
# what lies flat or flies.
const NOT_TARGET_PARTS: Array[String] = ["Blast_", "Flash", "Smoke", "Shard", "Debris", "Soot"]
const GROUND_NAMES: Array[String] = ["Land_Base", "Beach", "Cliff", "Skirt",
		"Terrain", "Bridge", "Helipad", "Gate_Sill"]
const WALL_NAMES: Array[String] = ["Wall", "Merlon", "GatePost", "Gate_"]
# What the gate leaves behind that is not a wall: the rubble, the soot and the
# blast itself. The stubs at either side are.
const NOT_WALL_NAMES: Array[String] = ["Gate_Debris", "Gate_Soot", "Gate_Flash",
		"Gate_Smoke", "Gate_Shard"]
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
	for prefix in NOT_WALL_NAMES:
		if object_name.begins_with(prefix):
			return ""
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
	_kinds[body.get_rid()] = "trunk"
	_trunks += 1


# The target layer, on every mesh under `root` that the gun should stop at and
# the BTR need not: named in TARGET_NAMES, or -- `all` -- any part with no
# other kind that is not a piece of the blast.
func _add_targets(root: Node, all: bool) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var object_name := String(mesh_instance.name)
		if _kind_of(object_name) != "":
			continue
		var wanted := TARGET_NAMES.any(func(prefix): return object_name.begins_with(prefix))
		if all:
			wanted = not NOT_TARGET_PARTS.any(func(part): return object_name.contains(part))
		if not wanted:
			continue
		mesh_instance.create_trimesh_collision()
		for child in mesh_instance.get_children():
			if child is StaticBody3D:
				child.collision_layer = TARGET_LAYER
				_kinds[child.get_rid()] = "building"


# The top of whatever stands at x, z -- a wall, a trunk, a building or the
# ground -- and which kind it is: where a round or a rocket the grid has
# stopped is seen to strike (level3d_gun.gd, level3d_rocket.gd).
func _surface_at(x: float, z: float) -> Dictionary:
	return _ground_at(x, z, GROUND_LAYER | SOLID_LAYER | TARGET_LAYER)


# The top of the ground layer at x, z, and which kind it is.
func _ground_at(x: float, z: float, mask := GROUND_LAYER) -> Dictionary:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, RAY_TOP, z), Vector3(x, RAY_BOTTOM, z),
			mask)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return {"height": 0.0, "kind": "", "hit": false}
	return {"height": hit.position.y, "kind": _kinds.get(hit.rid, "ground"), "hit": true}


# What the hull sits on: the ground, and the ramps over the bunkers that have
# lost their guns. Nothing else asks for the ramps -- a round, a crater or a
# soldier goes by the ground as it is.
func _hull_ground_at(x: float, z: float) -> Dictionary:
	return _ground_at(x, z, GROUND_LAYER | RAMP_LAYER)


# Whether a box at `pose` overlaps anything on the solid layer.
func _solid_at(pose: Transform3D, half: Vector3) -> bool:
	var shape := BoxShape3D.new()
	shape.size = half * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.collision_mask = SOLID_LAYER
	return not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# The buildings that can be blown up are not in the stage file: each is its own
# jackal_dest_<name>.glb, from export_destructibles() in the stage's Blender
# file, holding all three of its states -- intact, the blast, the ruins -- and
# one animation between them. glTF has no visibility, so the export folds it into
# the scale: whatever is hidden at a moment is shrunk to nothing then. Frame 0 of
# the animation is the intact building and its last frame the ruins, and the
# building is destroyed by playing it.
#
# Collision rides along. Each mesh gets its body as the stage's do, as a child,
# so a body follows its mesh's animated transform: the gate's leaves stop the
# BTR until they shrink away, and the stubs left at either side start to when
# they appear.
const DESTRUCTIBLE_NAMES: Array[String] = ["Barracks", "BarracksN", "BarracksN2",
		"BarracksN3", "Hangar_E", "Hangar_N", "Hangar_W", "Gate"]
const DESTRUCTIBLE_PATH := "res://resources/3d/jackal_dest_%s.glb"
const DESTRUCTION_ANIMATION := "Scene"
# Longer than any destruction animation (2.6 s).
const DESTRUCTION_SETTLE := 3.0

# name -> {root, player, centre, destroyed, bodies, footprint}; centre is
# where the flash goes off, footprint the intact building's Rect2 in x, z.
var destructibles := {}


func _add_destructibles() -> void:
	for building in DESTRUCTIBLE_NAMES:
		var path := DESTRUCTIBLE_PATH % building
		var scene: PackedScene = load(path)
		if scene == null:
			push_error("Cannot load %s -- run export_all() in the stage's Blender file" % path)
			continue
		var root := scene.instantiate()
		root.name = "Dest_" + building
		add_child(root)
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_sharpen_visibility(player.get_animation(DESTRUCTION_ANIMATION))
		_light_flashes(root, player)
		var flash := _find_by_prefix(root, FLASH_NAMES)
		_cast_both_sides_of_planes(root)
		_add_collision(root)
		_add_targets(root, true)
		var bodies := []
		for body in root.find_children("*", "StaticBody3D", true, false):
			bodies.append([body.get_parent(), body, body.collision_layer])
		destructibles[building] = {
			"root": root, "player": player, "destroyed": false, "bodies": bodies,
			"centre": flash.global_position if flash else _mesh_aabb(root).get_center(),
		}
		_set_destroyed(building, false)
		destructibles[building].footprint = _footprint(root)


const FLASH_NAMES: Array[String] = ["Blast_Flash", "Gate_Flash", "FX_Blast_Flash"]
# J_BlastFlash's emission strength over the destruction, keyed on its node tree
# in Blender: (frame, strength). Frame 1 is time 0, at 24 fps.
const FLASH_EMISSION := [[9, 0.0], [10, 14.0], [12, 9.0], [15, 4.0], [18, 0.0]]
const BLENDER_FPS := 24.0
# F0 in jackal_destruction_lib.py: the frame the intact building goes and the
# blast begins, as time into the animation.
const BLAST_FRAME := 10
const BLAST_START := (BLAST_FRAME - 1) / BLENDER_FPS


# The flash's glow is animated on its material in Blender, and glTF carries no
# material animation. It is one material there, shared by every flash, which
# works only because every building's timeline starts together; here each
# building gets its own copy and the glow as a track of its own animation. It
# casts no shadow either: it is a fireball, and the sun's shadow of it on the
# ground read as a hole.
func _light_flashes(root: Node, player: AnimationPlayer) -> void:
	var animation := player.get_animation(DESTRUCTION_ANIMATION)
	var base := player.get_node(player.root_node)
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var flash := node as MeshInstance3D
		if not FLASH_NAMES.any(func(prefix): return flash.name.begins_with(prefix)):
			continue
		var material := flash.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = material.albedo_color
		material.emission_energy_multiplier = 0.0
		flash.material_override = material
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var track := animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track, NodePath("%s:material_override:emission_energy_multiplier"
				% base.get_path_to(flash)))
		for key in FLASH_EMISSION:
			animation.track_insert_key(track, (key[0] - 1) / BLENDER_FPS, key[1])


# Scale at or below this is the export's "hidden".
const HIDDEN_SCALE := 1e-3


# Blender switches visibility from one frame to the next, and the export samples
# frames, so between a hidden key and a shown one the scale would ramp -- a
# piece growing out of its origin, which for most of them is the middle of the
# map, over a 24th of a second. A key just before the later one, holding the
# earlier value, makes the switch a switch.
static func _sharpen_visibility(animation: Animation) -> void:
	for track in animation.get_track_count():
		if animation.track_get_type(track) != Animation.TYPE_SCALE_3D:
			continue
		for i in range(animation.track_get_key_count(track) - 1, 0, -1):
			var before: Vector3 = animation.track_get_key_value(track, i - 1)
			var after: Vector3 = animation.track_get_key_value(track, i)
			if (before.x <= HIDDEN_SCALE) != (after.x <= HIDDEN_SCALE):
				animation.track_insert_key(track, animation.track_get_key_time(track, i) - 0.001, before)


# A hidden piece is shrunk to its origin, and so would its collision be: a wall
# too small to see but not to hit. Bodies are off while their mesh is hidden.
func _sync_bodies(entry: Dictionary) -> void:
	for item in entry.bodies:
		var mesh: Node3D = item[0]
		item[1].collision_layer = item[2] if mesh.scale.x > HIDDEN_SCALE else 0


static func _find_by_prefix(root: Node, prefixes: Array) -> Node3D:
	for node in root.find_children("*", "MeshInstance3D", true, false):
		for prefix in prefixes:
			if node.name.begins_with(prefix):
				return node
	return null


# Plays the destruction, or puts the building back as it was.
func _set_destroyed(building: String, destroyed: bool) -> void:
	var entry: Dictionary = destructibles[building]
	var player: AnimationPlayer = entry.player
	entry.destroyed = destroyed
	player.play(DESTRUCTION_ANIMATION)
	# Played from the blast, not from frame 1: the frames before it are the
	# intact building standing, and a rocket that hits it should not be seen to
	# go off a third of a second before the building does.
	player.seek(BLAST_START if destroyed else 0.0, true)
	if not destroyed:
		player.pause()
	elif friends != null:
		friends.building_destroyed(building)
	# Gate.attack: the gate's group opens the way on the grid, which is what
	# the BTR drives by.
	if destroyed and building == "Gate" and map != null and map.gate_group >= 0:
		map.trigger_group(map.gate_group)
	_sync_bodies(entry)


# What a rocket's explosion destroys: any building whose footprint is within
# BLAST_RADIUS of where it went off -- one stopped by the building's own solid
# tiles, and one that lands at the foot of a wall, as Jackal's grenade does.
const BLAST_RADIUS := 1.2


func _on_exploded(at: Vector3) -> bool:
	_shake(SHAKE_PIXELS)
	# The missile's own Explosion, which goes on to hit the guns it grows over.
	guns.explode(at)
	var any := false
	for building in destructibles:
		var entry: Dictionary = destructibles[building]
		if entry.destroyed:
			continue
		var box: Rect2 = entry.footprint
		var near := Vector2(clampf(at.x, box.position.x, box.end.x), clampf(at.z, box.position.y, box.end.y))
		if near.distance_to(Vector2(at.x, at.z)) <= BLAST_RADIUS:
			_set_destroyed(building, true)
			any = true
	return any


# A TravelingExplosion's box this tick (Level3DGuns): the barracks and hangars
# it overlaps go down, as Hut.attack and House.attack let it. The gate does
# not: Gate.attack answers the player's weapon only.
func _on_travel_hit(box: Rect2) -> void:
	for building in destructibles:
		var entry: Dictionary = destructibles[building]
		if not entry.destroyed and building != "Gate" and box.intersects(entry.footprint):
			_set_destroyed(building, true)


# The intact building from above, for the blast radius: what shows on frame 0.
func _footprint(root: Node) -> Rect2:
	var box := Rect2()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.scale.x <= HIDDEN_SCALE:
			continue
		var world := mesh_instance.global_transform * mesh_instance.get_aabb()
		var flat := Rect2(world.position.x, world.position.z, world.size.x, world.size.z)
		box = flat if first else box.merge(flat)
		first = false
	return box


# ----------------------------------------------------------------------------
# The bunkers' guns, and the BTR's dying to them: level3d_guns.gd has the rules.
#
# One jackal_dest_BunkerGun.glb (jackal_bunker_dest.py in jackal_assets.blend)
# on every bunker of the stage, which the stage file has without its gun. The
# yellow gun is the one YELLOW_GUN of stage-0.json; the rest are GRAY_GUN.
const GUN_BUNKERS: Array[String] = ["Bunker_0", "Bunker_1", "Bunker_2", "Bunker_3", "Bunker_4",
		"BunkerN_0", "BunkerN_1", "BunkerN3_0", "BunkerN3_1", "BunkerN3_2", "BunkerN3_3",
		"BunkerN3_4", "BunkerN3_5", "BunkerN3_6", "BunkerN3_7"]
const YELLOW_GUN_BUNKER := "BunkerN3_5"
const BLAST_PATH := "res://resources/3d/jackal_fx_blast.glb"

# Player.update's two counters, in ticks: while `_respawning` the BTR is gone
# and nothing it does happens; while `_invincible` rounds and mines pass it by.
var _respawning := 0
var _invincible := 0
var _immortal := false  # --immortal: rounds pass the BTR by, for --shot runs
var _blink := 0
var _score := 0
var _score_label: Label
var _blast_scene: PackedScene
# --hold: [key, from tick, to tick], and the ticks since the preview went live.
var _held: Array = []
var _ticks := 0
# Player's fire_released, for the classic rocket button.
var _fire_released := true


func _add_guns(level: Node) -> void:
	# The game's own map under the level: what walks, walks on it, and what
	# stops an enemy's round is its solid tiles (Level3DMap).
	map = Level3DMap.new()
	guns = Level3DGuns.new()
	guns.frame = _view_frame
	guns.solid = func(x: float, z: float):
		var p := Level3DMap.to_map(Vector2(x, z))
		return map.is_solid(p.x, p.y)
	guns.player_attack = _attack_player
	guns.player_position = func(): return Vector2(btr.position.x, btr.position.z)
	guns.blast = _spawn_blast
	guns.scored = func(points: int): _set_score(_score + points)
	add_child(guns)
	soldiers = Level3DSoldiers.new()
	soldiers.map = map
	soldiers.guns = guns
	soldiers.frame = _view_frame
	soldiers.ground = _ground_at
	soldiers.player_position = guns.player_position
	soldiers.scored = guns.scored
	soldiers.run_over = func(p: Vector3, margin: float, sideways: bool) -> Vector3:
		if _respawning > 0 or chinook != null:
			return Vector3.ZERO
		return btr.push_out(p, margin, sideways)
	add_child(soldiers)
	boats = Level3DBoats.new()
	boats.map = map
	boats.guns = guns
	boats.frame = _view_frame
	boats.ground = _ground_at
	boats.player_position = guns.player_position
	boats.scored = guns.scored
	add_child(boats)
	tanks = Level3DTanks.new()
	tanks.map = map
	tanks.guns = guns
	tanks.frame = _view_frame
	tanks.ground = _ground_at
	tanks.player_position = guns.player_position
	tanks.scored = guns.scored
	add_child(tanks)
	boss = Level3DBoss.new()
	boss.map = map
	boss.guns = guns
	boss.frame = _view_frame
	boss.ground = _ground_at
	boss.player_position = guns.player_position
	boss.scored = guns.scored
	add_child(boss)
	# What their wheels and tracks leave behind, and the player's.
	tracks = Level3DTracks.new()
	tracks.ground = _ground_at
	tracks.sources = [btr.wheel_tracks, tanks.track_contacts, boss.track_contacts]
	add_child(tracks)
	# The boss tanks are not in explosion_hit: nothing but the player's own
	# weapons hurts them (BossBlueTank.attack).
	guns.explosion_hit = func(box: Rect2, player: bool):
		soldiers.explosion_hit(box, player)
		boats.explosion_hit(box, player)
		tanks.explosion_hit(box, player)
	friends = Level3DFriends.new()
	friends.map = map
	friends.guns = guns
	friends.soldiers = soldiers
	friends.frame = _view_frame
	friends.ground = _ground_at
	friends.player_position = guns.player_position
	friends.scored = guns.scored
	add_child(friends)
	rescue = Level3DRescue.new()
	rescue.map = map
	rescue.friends = friends
	rescue.frame = _view_frame
	rescue.ground = _ground_at
	rescue.player_position = guns.player_position
	rescue.scored = guns.scored
	add_child(rescue)
	rescue.bind_lamps(level)
	soldiers.more_solids = friends.solid_boxes
	var centres := {}
	for building in destructibles:
		centres[building] = destructibles[building].footprint.get_center()
	friends.bind(centres)
	# A round stops at the first enemy on its way, gun, soldier, boat or tank;
	# a missile kills the soldiers it passes and stops at a gun, a boat or a
	# tank.
	gun.intercept = func(from: Vector3, to: Vector3):
		return _nearest([guns.intercept(from, to, PlayerBullet.MARGIN),
				soldiers.intercept(from, to, PlayerBullet.MARGIN),
				boats.intercept(from, to, PlayerBullet.MARGIN),
				tanks.intercept(from, to, PlayerBullet.MARGIN),
				boss.intercept(from, to, PlayerBullet.MARGIN)])
	gun.struck = func(found: Dictionary):
		if found.has("gun"):
			guns.bullet_attack(found.gun)
		elif found.has("boat"):
			boats.bullet_attack(found)
		elif found.has("tank"):
			tanks.bullet_attack(found)
		elif found.has("boss"):
			boss.bullet_attack(found)
		else:
			soldiers.bullet_attack(found)
	launcher.intercept = func(from: Vector3, to: Vector3):
		soldiers.sweep(from, to, PlayerMissile.MARGIN)
		return _nearest([guns.intercept(from, to, PlayerMissile.MARGIN, true),
				boats.intercept(from, to, PlayerMissile.MARGIN, true),
				tanks.intercept(from, to, PlayerMissile.MARGIN, true),
				boss.intercept(from, to, PlayerMissile.MARGIN, true)])
	launcher.struck = func(found: Dictionary):
		if found.has("boat"):
			boats.attack(found)
		elif found.has("tank"):
			tanks.attack(found)
		elif found.has("boss"):
			boss.attack(found)
		else:
			guns.attack(found.gun)
	launcher.traveled = guns.travel
	guns.travel_hit = _on_travel_hit
	_blast_scene = load(BLAST_PATH)
	var scene: PackedScene = load(Level3DGuns.GUN_PATH)
	if scene == null or _blast_scene == null:
		push_error("Cannot load the gun or the blast -- run export() in jackal_assets.blend and jackal_fx.blend")
		return
	for bunker_name in GUN_BUNKERS:
		var bunker := level.find_child(bunker_name, true, false) as Node3D
		if bunker == null:
			push_warning("No %s in %s; it gets no gun" % [bunker_name, LEVEL_PATH])
			continue
		var root := scene.instantiate() as Node3D
		root.name = "Gun_" + bunker_name
		add_child(root)
		root.global_transform = bunker.global_transform
		var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
		_sharpen_visibility(player.get_animation(DESTRUCTION_ANIMATION))
		_cast_both_sides_of_planes(root)
		var base_bodies := []
		for body in bunker.find_children("*", "StaticBody3D", true, false):
			base_bodies.append([body, body.collision_layer])
		# Switched with the ruin's bodies: on once the gun is gone.
		base_bodies.append([_add_bunker_ramp(bunker), RAMP_LAYER])
		guns.add(bunker_name, root, player, bunker_name != YELLOW_GUN_BUNKER, base_bodies)


# A bunker whose gun is gone is floor in the game -- its cells were empty all
# along; the gun's own boxes were what kept the jeep off -- so the BTR drives
# over it, and here it has to climb the concrete to do so, or it runs through
# it at sand level. What it climbs is not the concrete, whose edge is a step
# and whose wreck is jagged, but a frustum over it on RAMP_LAYER: its top the
# bunker's top plate at the height of the wreck's ring, its foot on the ground
# just far enough out that its slope passes over the slab's edge. Built in the
# bunker's own axes from its meshes, so it fits a bunker however it is turned.
const RAMP_TOP := 0.72      # over the wreck's ring, which stands to 0.69

func _add_bunker_ramp(bunker: Node3D) -> StaticBody3D:
	var into_bunker := bunker.global_transform.affine_inverse()
	var slab := AABB()
	var top := AABB()
	var first := true
	for node in bunker.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		var box: AABB = into_bunker * mesh_instance.global_transform * mesh_instance.get_aabb()
		slab = box if first else slab.merge(box)
		first = false
		if String(mesh_instance.name).begins_with("Bunker_Top"):
			top = box
	var foot := slab.position.y
	var centre := slab.get_center()
	var slab_half := Vector2(slab.size.x, slab.size.z) * 0.5
	var top_half := Vector2(top.size.x, top.size.z) * 0.5 if top.has_volume() else slab_half * 0.64
	# The slab's own height, without the plate, rivets and slit on it.
	var slab_height := top.position.y - foot if top.has_volume() else slab.size.y * 0.7
	var rise := RAMP_TOP
	# The run out past the slab's edge at which the slope is slab_height high
	# over that edge, on the slab's longer half.
	var inset := maxf(slab_half.x - top_half.x, slab_half.y - top_half.y)
	var run := slab_height * inset / maxf(rise - slab_height, 0.01) + 0.05
	var points := PackedVector3Array()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var c := corner as Vector2
		points.append(Vector3(centre.x + c.x * (slab_half.x + run), foot, centre.z + c.y * (slab_half.y + run)))
		points.append(Vector3(centre.x + c.x * top_half.x, foot + rise, centre.z + c.y * top_half.y))
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	var holder := CollisionShape3D.new()
	holder.shape = shape
	var body := StaticBody3D.new()
	body.name = "Ramp"
	body.collision_layer = 0
	body.collision_mask = 0
	body.add_child(holder)
	bunker.add_child(body)
	_kinds[body.get_rid()] = "ruin"
	return body


# Of the enemies' intercepts, the one a weapon meets first: {} for none.
static func _nearest(found: Array) -> Dictionary:
	var best := {}
	for f: Dictionary in found:
		if not f.is_empty() and (best.is_empty() or f.t < best.t):
			best = f
	return best


# FX_Blast from jackal_fx.blend, played once from its blast frame and gone.
func _spawn_blast(at: Vector3, size: float) -> void:
	var root := _blast_scene.instantiate() as Node3D
	add_child(root)
	root.global_position = at
	root.scale = Vector3.ONE * size
	var player := root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	_sharpen_visibility(player.get_animation(DESTRUCTION_ANIMATION))
	_light_flashes(root, player)
	player.play(DESTRUCTION_ANIMATION)
	player.seek(BLAST_START, true)
	get_tree().create_timer(DESTRUCTION_SETTLE).timeout.connect(root.queue_free)


# The top view's frame in x, z -- the game's screen, for what is on it.
func _view_frame() -> Rect2:
	var width := level_aabb.size.x / zoom
	var half_height := width * 9.0 / 32.0
	return Rect2(focus.x - width * 0.5, focus.y - half_height, width, half_height * 2.0)


# Player.attack: 32 px either side of the player.
func _attack_player(x: float, z: float) -> bool:
	if _respawning > 0 or _invincible > 0 or _immortal or chinook != null:
		return false
	var half := 32.0 * Level3DGuns.PX
	if absf(x - btr.position.x) > half or absf(z - btr.position.z) > half:
		return false
	_explode_btr("shot")
	return true


# Player.update's box for its mines: 32 px either side, 48 along x when facing
# east or west and 46 along y when facing north or south. The BTR's heading is
# not held to eight directions, so the nearest of them decides.
func _player_box() -> Rect2:
	var octant := wrapi(int(roundf(btr.heading / (PI / 4.0))), 0, 8)
	var half := Vector2(32.0, 32.0)
	if octant == 0 or octant == 4:
		half.x = 48.0
	elif octant == 2 or octant == 6:
		half.y = 46.0
	half *= Level3DGuns.PX
	return Rect2(Vector2(btr.position.x, btr.position.z) - half, half * 2.0)


# Player.explode: the blast, the BTR gone, and back after RESPAWN_DELAY where
# it went, invincible. No lives are counted; the preview has no continue.
func _explode_btr(by: String) -> void:
	_spawn_blast(btr.position + Vector3.UP * 0.6, 1.0)
	# Its own Explosion, which spares the guns and not the soldiers.
	guns.explode(btr.position, true)
	friends.player_died(btr.position)
	_shake(SHAKE_PIXELS)
	btr.stop()
	btr.visible = false
	_respawning = Player.RESPAWN_DELAY
	if guns.verbose:
		print("BTR destroyed (%s) at %.1f, %.1f" % [by, btr.position.x, btr.position.z])


func _make_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_score_label = Label.new()
	_score_label.position = Vector2(16, 12)
	_score_label.add_theme_font_size_override("font_size", 22)
	_score_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_score_label.add_theme_constant_override("outline_size", 6)
	layer.add_child(_score_label)
	_set_score(0)


func _set_score(score: int) -> void:
	_score = score
	_score_label.text = "SCORE %06d" % score
	if friends != null:
		_score_label.text += "   POW %d   %s" % [friends.pows, friends.weapon_name().to_upper()]
	if btr != null:
		_score_label.text += "   %s" % ("CLASSIC" if btr.classic else "FREE")


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


func _mesh_aabb(root: Node, leave_out: Array[String] = []) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if leave_out.any(func(prefix: String) -> bool: return mesh_instance.name.begins_with(prefix)):
			continue
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _update_camera() -> void:
	var width := level_aabb.size.x / zoom
	var half_width := width * 0.5
	var half_height := width * 9.0 / 32.0
	# Over the Chinook while it comes in: it is drawn at the original's scale
	# for its height, which takes it well above the usual 20 m.
	var height := TOP_CAMERA_HEIGHT
	if chinook != null:
		height = maxf(height, chinook.top() + 1.0)
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
		camera.position = Vector3(focus.x, height, focus.y)
		camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
		camera.near = 1.0
		camera.far = height + TOP_CAMERA_HEIGHT
		# Straight down, every ground point is at the same depth, so cascades
		# buy nothing and a single map over the whole depth is sharpest.
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		sun.directional_shadow_max_distance = height + TOP_CAMERA_HEIGHT
	_apply_shake(width)


# The tank bench's CameraShake.Blast: two sines per axis so it does not read as
# a pendulum, a (1 - t/T)^2 envelope, over in SHAKE_TIME. In screen pixels,
# converted through the frame's width, so zoom does not change it.
const SHAKE_PIXELS := 7.0
const SHAKE_TIME := 0.55
var _shake_left := 0.0
var _shake_pixels := 0.0


# A second blast inside the first restarts it, stronger, rather than adding.
func _shake(pixels: float) -> void:
	_shake_pixels = maxf(pixels, _shake_pixels if _shake_left > 0.0 else 0.0)
	_shake_left = SHAKE_TIME


func _apply_shake(width: float) -> void:
	if _shake_left <= 0.0:
		return
	var t := SHAKE_TIME - _shake_left
	var envelope := pow(_shake_left / SHAKE_TIME, 2.0)
	var metres := _shake_pixels * width / get_viewport().get_visible_rect().size.x * envelope
	var x := sin(t * TAU * 11.0) * 0.7 + sin(t * TAU * 17.0 + 1.3) * 0.3
	var y := sin(t * TAU * 13.0 + 0.6) * 0.7 + sin(t * TAU * 19.0 + 2.1) * 0.3
	camera.position += (camera.basis.x * x + camera.basis.y * y) * metres


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
	_ticks += 1
	# P is a press, as a right click is; a held span presses it once. Classic
	# reads it as held instead, below.
	if not btr.classic:
		for h in _held:
			if h[0] == KEY_P and maxi(h[1], 1) == _ticks:
				_rocket_wanted = ROCKET_WAIT
	if btr.classic:
		btr.key_up = _key(KEY_W)
		btr.key_down = _key(KEY_S)
		btr.key_left = _key(KEY_A)
		btr.key_right = _key(KEY_D)
		btr.throttle = 0.0
		btr.steer = 0.0
	else:
		btr.key_up = false
		btr.key_down = false
		btr.key_left = false
		btr.key_right = false
		btr.throttle = float(_key(KEY_W)) - float(_key(KEY_S))
		btr.steer = float(_key(KEY_A)) - float(_key(KEY_D))
	btr.turret_input = _axis(KEY_E, KEY_Q)
	if btr.turret_input != 0.0:
		mouse_aim = false
	# Classic without the mouse is the game's without it: the gun up the
	# screen whatever the jeep does, the grenade the way it drives or faces.
	var classic_aim := btr.classic and _forced_aim == null and not mouse_aim
	if _forced_aim != null:
		btr.aim_point = _forced_aim
	elif classic_aim:
		btr.aim_point = btr.position + _game_direction(270.0) * Level3DGun.RANGE
	else:
		btr.aim_point = _cursor_on_ground() if mouse_aim else null
	for building in destructibles:
		var entry: Dictionary = destructibles[building]
		if entry.player.is_playing():
			_sync_bodies(entry)
	# Player.update: while respawning the player does nothing at all; the tick
	# the count runs out it comes back, invincible, and carries on.
	var gone := false
	# The Chinook's run: Chinook sets GameMode.playing false, and the player
	# is not updated until it is over.
	if chinook != null:
		chinook.tick()
		gone = chinook != null
	elif _respawning > 0:
		_respawning -= 1
		if _respawning == 0:
			btr.visible = true
			_invincible = Player.INVINCIBLE_DELAY
			if guns.verbose:
				print("BTR back, invincible for %d ticks" % _invincible)
		else:
			gone = true
	if not gone:
		btr.step(delta)
	gun.trigger = not gone and (_hold_fire or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			or _key(KEY_L))
	gun.aim_point = btr.aim_point
	gun.step(delta)
	launcher.aim_point = btr.aim_point
	if classic_aim:
		launcher.aim_point = btr.position \
				+ _game_direction(btr.classic_fire_angle()) * Level3DLauncher.RANGE
	launcher.has_missiles = friends.has_missiles
	launcher.missile_power = friends.missile_power
	# Player.update's grenade: held, it goes the tick it can, and it has to be
	# let go of between two. A press while the last one is still in the air is
	# not lost if the button is still down when it is over.
	if btr.classic:
		if _key(KEY_P) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			if _fire_released and not gone and launcher.fire():
				_fire_released = false
		else:
			_fire_released = true
	# A click waits for the mount to come round and the rails to be loaded,
	# rather than being lost while they are not.
	if _rocket_wanted > 0.0:
		_rocket_wanted -= delta
		if not gone and launcher.fire():
			_rocket_wanted = 0.0
	launcher.step(delta)
	if not gone:
		if _invincible > 0:
			_invincible -= 1
		# Soldiers are run over and prisoners picked up whether or not the BTR is
		# invincible.
		soldiers.bump(_player_box())
		friends.bump(_player_box())
		if guns.bump(_player_box(), _invincible > 0):
			_explode_btr("ran into a gun")
		elif tanks.bump(_player_box(), _invincible > 0):
			_explode_btr("ran into a tank")
		elif boss.bump(_player_box(), _invincible > 0):
			_explode_btr("ran into a boss tank")
	guns.tick()
	soldiers.tick()
	boats.tick()
	tanks.tick()
	boss.tick()
	tracks.tick()
	friends.tick()
	rescue.tick()
	_set_score(_score)
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
	# The boss's pan and the arena after it: the frame's top where the boss
	# has it, as GameMode's boss_camera_pan and max_camera_y = 0 hold it.
	var boss_top := boss.camera_top() if boss != null else -1.0
	if boss_top >= 0.0:
		focus.y = Level3DMap.to_level(Vector2(0.0, boss_top)).y + level_aabb.size.x / zoom * 9.0 / 32.0
	rescue.enlarge = not tilted
	# The game flashes the jeep through four palettes a frame while it is
	# invincible; the BTR has one, so it blinks.
	if chinook != null:
		chinook.enlarge = not tilted
	elif _respawning == 0:
		_blink = _blink + 1 if _invincible > 0 else 0
		btr.visible = _blink % 4 < 2
	_shake_left = maxf(_shake_left - delta, 0.0)
	_update_camera()


# A key held on the keyboard or by --hold.
func _key(key: Key) -> bool:
	if Input.is_key_pressed(key):
		return true
	for h in _held:
		if h[0] == key and _ticks >= h[1] and _ticks < h[2]:
			return true
	return false


# A game angle -- 0 east, 90 down the screen -- as a level direction.
static func _game_direction(degrees: float) -> Vector3:
	var a := deg_to_rad(degrees)
	return Vector3(cos(a), 0.0, sin(a))


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
			KEY_T:
				gun.turbo = not gun.turbo
			KEY_P:
				if not btr.classic:
					_rocket_wanted = ROCKET_WAIT
			KEY_V:
				btr.classic = not btr.classic
				_set_score(_score)
			KEY_SPACE:
				if chinook != null:
					chinook.skip()
			KEY_R:
				btr.place(START, START_HEADING)
				following = true
				for building in destructibles:
					_set_destroyed(building, false)
				launcher.clear_craters()
				guns.reset()
				soldiers.reset()
				boats.reset()
				tanks.reset()
				boss.reset()
				tracks.reset()
				friends.reset()
				rescue.reset()
				map.reset()
				_respawning = 0
				_invincible = 0
				btr.visible = true
				_set_score(0)
				_start_intro()
			KEY_ESCAPE:
				btr.stop()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			# The left button is the gun's, read as held in _physics_process.
			MOUSE_BUTTON_RIGHT:
				if not btr.classic:
					_rocket_wanted = ROCKET_WAIT
			MOUSE_BUTTON_MIDDLE:
				var at = _cursor_on_ground()
				if at != null:
					btr.order(at, event.shift_pressed)
			MOUSE_BUTTON_WHEEL_UP:
				following = false
				focus.y -= 2.0 / zoom
			MOUSE_BUTTON_WHEEL_DOWN:
				following = false
				focus.y += 2.0 / zoom


# What the scene's collision says over the whole level, one pixel per
# OBSTACLE_STEP metres, north up: ground grey, water blue, forest green, walls
# red, trunks orange, off the level black. The BTR, its rounds and its rockets
# went by it once; they go by the game's grid now (level3d_btr.gd,
# level3d_gun.gd, level3d_rocket.gd), and this is what the ground's height and
# the look of a strike go by. Needs no window -- physics runs headless -- so it
# is the check for _add_collision:
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
	print("obstacle map %dx%d from %.2f, %.2f, %d trunks: %s" % [width, height,
			level_aabb.position.x, level_aabb.position.z, _trunks, counts])
	for building in destructibles:
		var centre: Vector3 = destructibles[building].centre
		print("  %s at %.1f, %.1f%s" % [building, centre.x, centre.z,
				" (destroyed)" if destructibles[building].destroyed else ""])
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
	guns.verbose = args.has("--shot")
	soldiers.verbose = guns.verbose
	boats.verbose = guns.verbose
	tanks.verbose = guns.verbose
	boss.verbose = guns.verbose
	friends.verbose = guns.verbose
	rescue.verbose = guns.verbose
	var intro := args.find("--intro")
	if intro >= 0:
		args.remove_at(intro)
	var immortal := args.find("--immortal")
	if immortal >= 0:
		_immortal = true
		args.remove_at(immortal)
	# Level3DSoldiers and Level3DBtr read these for themselves; they are not
	# waypoints.
	for own in ["--sprite-soldiers", "--btr"]:
		var at := args.find(own)
		if at >= 0:
			args.remove_at(at)
	var free := args.find("--free")
	if free >= 0:
		btr.classic = false
		args.remove_at(free)
		_set_score(_score)
	var hold := args.find("--hold")
	if hold >= 0:
		const KEYS := {"w": KEY_W, "a": KEY_A, "s": KEY_S, "d": KEY_D, "l": KEY_L, "p": KEY_P}
		for span in args[hold + 1].split(","):
			var at := span.split("@")
			var times := at[1].split("-")
			for c in at[0]:
				_held.append([KEYS[c], _ticks + roundi(float(times[0]) * 100.0),
						_ticks + roundi(float(times[1]) * 100.0)])
		args = args.slice(0, hold) + args.slice(hold + 2)
	var weapon := args.find("--weapon")
	if weapon >= 0:
		var level := int(args[weapon + 1])
		friends.has_missiles = level > 0
		friends.missile_power = clampi(level - 1, 0, 2)
		args = args.slice(0, weapon) + args.slice(weapon + 2)
		_set_score(_score)
	var aboard := args.find("--pows")
	if aboard >= 0:
		friends.pows = int(args[aboard + 1])
		friends.releaseable_pows = friends.pows
		args = args.slice(0, aboard) + args.slice(aboard + 2)
		_set_score(_score)
	var start_at := args.find("--at")
	if start_at >= 0:
		var xz := args[start_at + 1].split(",")
		btr.place(Vector3(float(xz[0]), 0.0, float(xz[1])), START_HEADING)
		args = args.slice(0, start_at) + args.slice(start_at + 2)
	var blow_up := args.find("--destroy")
	if blow_up >= 0:
		for building in args[blow_up + 1].split(","):
			_set_destroyed(building, true)
		args = args.slice(0, blow_up) + args.slice(blow_up + 2)
	var fire := args.find("--fire")
	if fire >= 0:
		var xz := args[fire + 1].split(",")
		_forced_aim = Vector3(float(xz[0]), 0.0, float(xz[1]))
		_hold_fire = true
		args = args.slice(0, fire) + args.slice(fire + 2)
	var rocket := args.find("--rocket")
	if rocket >= 0:
		var at := args[rocket + 1].split("@")
		var xz := at[0].split(",")
		_forced_aim = Vector3(float(xz[0]), 0.0, float(xz[1]))
		if at.size() > 1:
			get_tree().create_timer(float(at[1])).timeout.connect(func(): _rocket_wanted = INF)
		else:
			_rocket_wanted = INF
		args = args.slice(0, rocket) + args.slice(rocket + 2)
	if args.size() >= 2 and args[0] == "--obstacle-map":
		# Mapped once the ruins have settled, when anything was blown up.
		if blow_up >= 0:
			await get_tree().create_timer(DESTRUCTION_SETTLE).timeout
			await get_tree().physics_frame
			await get_tree().physics_frame
		_obstacle_map(args[1])
		get_tree().quit()
		return
	if args.size() < 2 or args[0] != "--shot":
		return
	if args.size() >= 3:
		following = false
		if args[2].contains(","):
			var xz := args[2].split(",")
			focus = Vector2(float(xz[0]), float(xz[1]))
		else:
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
			# A frame given as x,z stays put; one given along the stage follows.
			following = not args[2].contains(",")
		# So does one driven by --hold.
		if not _held.is_empty():
			following = not args[2].contains(",")
		await get_tree().create_timer(float(args[5])).timeout
	print("BTR at %.2f, %.2f heading %.1f, %s" % [btr.position.x, btr.position.z,
			rad_to_deg(btr.heading), "classic" if btr.classic else "free"])

	# Shadows and the first frame's pipeline compilation need a few frames.
	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(args[1])
	if error != OK:
		push_error("Cannot write %s (error %d)" % [args[1], error])
	get_tree().quit()
