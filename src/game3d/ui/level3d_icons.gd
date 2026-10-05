# The HUD's icons (Level3DHud), rendered from the preview's own models rather
# than cut from the game's sprite sheets: the vehicle the preview drives for
# the lives and the stage's prisoner (Level3DFriends.chosen), waving, for the
# prisoners aboard. The weapon had one too, its round, until the HUD stopped showing it.
#
# Each model is put in a SubViewport of its own, with a world of its own so
# that none of the level is in it, and seen in three quarters, all from the
# same side, by an orthographic camera framed on it. The light is the
# preview's -- the sun's strength and SHADE, handed in, and the two-tone light
# (_toon), whose hook runs on anything in the tree -- but from over the
# camera's shoulder: the sun is set for the stage seen from straight above.
#
# Pixelated: rendered small, with no antialiasing, and drawn up by a whole
# factor with the canvas' nearest filter (Level3DHud.ICON_PIXEL), as the font
# is. At that size the engine's contour, a few pixels of a 1080 frame, comes
# to nothing,
# so the line is drawn on the image instead: every clear pixel next to one of
# the model's is black, one pixel round the silhouette, and the model's edge
# is made hard, all or nothing, as a sprite's is.
#
# Rendered once each, and again when the HUD's size changes (render_all).
class_name Level3DIcons
extends Node

const POW_POSE_AT := 0.35             # seconds into his wave: the arm up
const POW_FACING := PI / 2.0          # +Z, his front, onto +X
# Three quarters: from above the vehicle's front and a side, as a model sheet
# draws it. The vehicle faces +X (heading 0) and is turned by HEADING, which
# puts its nose some 55 degrees round from the camera -- less and the side is
# lost, more and it is a side view.
const ELEVATION := deg_to_rad(38.0)
const AZIMUTH := deg_to_rad(-50.0)    # of the camera, round +Y from +Z
const HEADING := deg_to_rad(165.0)
const PAD := 1                        # pixels round the model, for the line
const PROBE := 256                    # the loose frame's size, to measure on
const ALPHA_CUT := 0.5

var sun_energy := 1.0
var shade := 0.3


# Every icon at `height` pixels (the widest may be up to `max_aspect` times
# that across), for `vehicle` -- Level3DBtr.VEHICLES' entry: {"lives": Texture,
# "pow": Texture}, and "lives_2" too, the vehicle
# turned by Level3DBtr.tint's `hues` (min, max, shift), when they are given:
# the second player's. Takes a few frames.
func render_all(vehicle: Dictionary, height: int, hues := Vector3.ZERO) -> Dictionary:
	var scene: PackedScene = load(vehicle.path)
	var prefix: String = vehicle.prefix
	var fits: Array[String] = []
	for fit in Level3DLauncher.FITS:
		fits.append(prefix + String(fit.base).trim_prefix("BTR_"))
	var spare: Array[String] = []
	for name in vehicle.get("spare_fits", []):
		spare.append(prefix + name)
	# Nor the shop's upgrades (Level3DBtr.UPGRADE_PARTS).
	for name in Level3DBtr.UPGRADE_PARTS.values():
		spare.append(prefix + name)

	# The vehicle bare: none of its mounts, which change with the weapon.
	var body := _turned(scene.instantiate(), vehicle.facing)
	for name in fits + spare:
		var node := body.find_child(name, true, false)
		if node != null:
			node.visible = false
	var icons := {"lives": await render(body, height, 1.6)}
	if hues != Vector3.ZERO:
		var tinted := _turned(scene.instantiate(), vehicle.facing)
		for name in fits + spare:
			var node := tinted.find_child(name, true, false)
			if node != null:
				node.visible = false
		Level3DBtr.tint_model(tinted, hues.x, hues.y, hues.z)
		icons["lives_2"] = await render(tinted, height, 1.6)

	var pow: Dictionary = Level3DFriends.chosen()
	var pose: String = pow.wave
	var pow_scene: PackedScene = load(pow.path)
	# Turned as the vehicle is, to face the way its nose does: the figure
	# faces +Z, as the jeep's model does before VEHICLES' facing turns it.
	var pow_model: Node3D = pow_scene.instantiate()
	Level3DFriends.dress(pow_model, pow)
	var pow_turned := _turned(pow_model, POW_FACING)
	icons["pow"] = await render(pow_turned, height, 1.0, func():
		var player := pow_model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if player != null and player.has_animation(pose):
			player.play(pose)
			player.seek(POW_POSE_AT, true)
			player.pause())
	# And in the second player's colours, for the mission's summary, which
	# colours each prisoner by who brought him (Level3DSummary).
	if hues != Vector3.ZERO:
		var pow_2: Node3D = pow_scene.instantiate()
		Level3DFriends.dress(pow_2, pow)
		Level3DBtr.tint_model(pow_2, hues.x, hues.y, hues.z)
		icons["pow_2"] = await render(_turned(pow_2, POW_FACING), height, 1.0, func():
			var player := pow_2.find_child("AnimationPlayer", true, false) as AnimationPlayer
			if player != null and player.has_animation(pose):
				player.play(pose)
				player.seek(POW_POSE_AT, true)
				player.pause())
	return icons


# The model under a pivot that turns it to face +X, then HEADING on.
static func _turned(model: Node3D, facing: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.add_child(model)
	model.transform = Transform3D(Basis(Vector3.UP, facing), Vector3.ZERO)
	pivot.rotation.y = HEADING
	return pivot


# One model at `height` pixels, no wider than `max_aspect` times that; posed
# by `pose` once it is in the tree. The model is freed with its viewport.
func render(model: Node3D, height: int, max_aspect: float, pose := Callable()) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.size = Vector2i(height, height)
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = shade
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	var world := WorldEnvironment.new()
	world.environment = env
	viewport.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.light_energy = sun_energy
	viewport.add_child(sun)
	viewport.add_child(model)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	viewport.add_child(camera)
	if pose.is_valid():
		pose.call()
	# A frame for the skeletons to take their pose and the hooks to run.
	await get_tree().process_frame

	# The camera's axes, and the light from over its left shoulder: the
	# preview's sun is set for the stage seen from straight above, and from
	# this side it lit the models from behind, nearly black.
	var back := Vector3(sin(AZIMUTH) * cos(ELEVATION), sin(ELEVATION), cos(AZIMUTH) * cos(ELEVATION))
	var look := Basis.looking_at(-back, Vector3.UP)
	var toward := (back - look.x * 0.7 + look.y * 0.5).normalized()
	sun.basis = Basis.looking_at(-toward, Vector3.UP if absf(toward.y) < 0.99 else Vector3.FORWARD)
	# A loose frame first, on the boxes of what is shown -- turned to three
	# quarters, a box's empty corners make it far bigger than the model.
	var low := Vector3.INF
	var high := -Vector3.INF
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if not mesh_instance.is_visible_in_tree():
			continue
		var box := mesh_instance.global_transform * mesh_instance.get_aabb()
		for i in 8:
			var p := look.inverse() * box.get_endpoint(i)
			low = low.min(p)
			high = high.max(p)
	if low == Vector3.INF:
		viewport.queue_free()
		return null
	var extent := high - low
	var centre := look * ((low + high) * 0.5)
	camera.near = 0.05
	camera.far = extent.z + 20.0
	var loose := maxf(extent.x, extent.y) * 1.1
	viewport.size = Vector2i(PROBE, PROBE)
	camera.size = loose
	camera.global_transform = Transform3D(look, centre + back * (extent.z + 10.0))
	var probe := await _draw(viewport)
	# Then the model's own outline, measured on that, in the camera's plane.
	var used := probe.get_used_rect()
	if used.size == Vector2i.ZERO:
		viewport.queue_free()
		return null
	var per_pixel := loose / PROBE
	var half := PROBE * 0.5
	var left := (used.position.x - half) * per_pixel
	var right := (used.end.x - half) * per_pixel
	var up := (half - used.position.y) * per_pixel
	var down := (half - used.end.y) * per_pixel
	var model_w := right - left
	var model_h := up - down
	centre += look.x * (left + right) * 0.5 + look.y * (up + down) * 0.5
	# At `height`, or lower where it is too wide for max_aspect.
	var inner_h := height - PAD * 2
	var world_h := maxf(model_h, model_w / max_aspect)
	var inner_w := maxi(int(ceil(inner_h * model_w / world_h)), 1)
	viewport.size = Vector2i(inner_w + PAD * 2, height)
	camera.size = world_h * height / inner_h
	camera.global_transform = Transform3D(look, centre + back * (extent.z + 10.0))
	var image := await _draw(viewport)
	viewport.queue_free()
	image.convert(Image.FORMAT_RGBA8)
	_outline(image)
	return ImageTexture.create_from_image(image)


# One frame of the viewport, read back.
func _draw(viewport: SubViewport) -> Image:
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()


# Hard edges and a line: alpha all or nothing, and every clear pixel with a
# solid one beside it, of the four, black.
static func _outline(image: Image) -> void:
	var w := image.get_width()
	var h := image.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			var c := image.get_pixel(x, y)
			var on := c.a >= ALPHA_CUT
			solid[y * w + x] = 1 if on else 0
			if on:
				c.a = 1.0
				image.set_pixel(x, y, c)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if solid[y * w + x] == 1:
				continue
			if (x > 0 and solid[y * w + x - 1] == 1) or (x < w - 1 and solid[y * w + x + 1] == 1) \
					or (y > 0 and solid[(y - 1) * w + x] == 1) or (y < h - 1 and solid[(y + 1) * w + x] == 1):
				image.set_pixel(x, y, Color.BLACK)
