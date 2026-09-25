# The BTR's machine gun on the 3D stage 1 preview: the trigger, where each
# round goes, and what it looks like when it gets there.
#
# Nothing here is part of the game. Jackal's gun is what it follows: a stream
# of rounds with a short reach that chips at buildings without taking them
# down -- that is the rocket's job, step 3 of docs/level3d-combat-plan.md. The
# bunkers' guns are the exception, as in the game: three rounds each
# (level3d_guns.gd), found along the round's flight through `intercept`.
#
# A round is decided the moment it is fired: at this scale a bullet's flight is
# a few frames at most, and nothing on the stage moves out of the way. It is
# aimed at the ground where the cursor is, along the turret's bearing rather
# than the cursor's -- the turret lags a fast mouse, and the stream is seen to
# swing round with it -- and no further than RANGE. What stops it is the
# game's to say, as it is for the BTR's driving: PlayerBullet moves VELOCITY a
# tick and is gone on the first tick it is over a tile is_missile_target
# answers for -- solid or shield -- on the map's collision grid
# (Level3DMap). The scene is asked only what is there to be seen: how high the
# round strikes, and whether it is a wall, a trunk, a building, the ground or
# the sea, for the impact. The round then flies there at a speed the eye can
# follow, and the impact is shown when it arrives.
#
# The round is PlayerBullet's sprite, yellow-bullet.png -- the one EnemyBullet
# draws yellow, as the game's player and gunners fire the same round -- turned
# to the camera at the game's size, as Level3DGuns draws the enemies'. It used
# to be a glowing streak, a tracer the game never had.
#
# From the tank bench (BlenderMCP/godot, docs/combat.md), the two things it
# settled for the cannon: recoil is an impulse into the body spring, not a
# curve over time, and it is signed along the gun, so a shot over the bow
# lifts the nose and a shot over the side does not. The camera does not shake:
# the bench leaves shake off for the cannon, and this gun fires nine times a
# second.
#
# Effects are low poly and opaque, like the stage: a puff grows and shrinks
# away instead of fading, which also keeps them out of Compatibility's
# transparent pass. They are cel-shaded as the models are, faceted and drawn
# round (level3d_fx.gd).
#
# With the BTR driving classic (level3d_btr.gd) the gun is PlayerBullet's and
# Player.update's trigger instead: a round the tick the trigger goes down, then
# one every GUN_ARMED_DELAY ticks while it is held -- tapping is faster than
# holding, as it is in the game -- each one flying 18 px a tick for 21 ticks,
# 378 px, whatever it was aimed at, with no spread, and no more than
# Player.MAX_BULLETS of them in flight. It is still decided when it is fired.
# With `turbo` (ButtonMapping.turbo, on by default) a held trigger fires every
# Player.TURBO_DELAY ticks instead of every GUN_ARMED_DELAY, as the game's.
class_name Level3DGun
extends Node3D

const FIRE_INTERVAL := 0.11
const SPREAD := deg_to_rad(2.0)
# Level metres. The frame is 24.6 m tall at zoom 1, so this is about half of it.
const RANGE := 12.0
const MIN_RANGE := 1.5
const RANGE_JITTER := 0.05
const ROUND_SPEED := 70.0
const ROUND_SPRITE := "yellow-bullet.png"
const FLASH_TIME := 0.05
const RECOIL_KICK := 0.12
# PlayerBullet, at the map's PX: it moves VELOCITY a tick and is gone on the
# tick its count passes TRAVEL_TIME, so it covers TRAVEL_TIME + 1 moves.
const CLASSIC_RANGE := (PlayerBullet.TRAVEL_TIME + 1) * PlayerBullet.VELOCITY * Level3DMap.PX
const CLASSIC_ROUND_SPEED := PlayerBullet.VELOCITY * 100.0 * Level3DMap.PX

# `ground.call(x, z)` as the BTR has it; `surface.call(x, z)` the same over
# everything that stands on the ground as well -- walls, trunks, buildings --
# with its kind: "water", "forest", "ground", "hard" (the bridge, the helipad,
# the hangars' pads, the gate's sill), "wall", "trunk" or "building".
var ground: Callable
var surface: Callable
var btr: Level3DBtr
var trigger := false
var turbo := true
var aim_point = null        # Vector3 or null
# `intercept.call(from, to)`: the first enemy on the round's flight before the
# grid stops it -- a bunker's gun, a soldier, a boat or a tank -- as {"t": 0-1
# along from -> to, ...}, or empty. `struck.call(found)` when the round gets
# there.
var intercept: Callable
var struck: Callable

var _cooldown := 0.0
# Player's gun_armed and shoot_released, for the classic trigger.
var _gun_armed := 0
var _shoot_released := true
# Rounds still flying, for Player.MAX_BULLETS.
var _in_flight := 0
var _rng := RandomNumberGenerator.new()
var _flash: MeshInstance3D
var _flash_left := 0.0
var _round_texture: AtlasTexture
var _puff_mesh: ArrayMesh
var _chip_mesh: ArrayMesh
var _materials := {}


func _ready() -> void:
	# Seeded, so a --shot of a burst is the same burst every time.
	_rng.seed = 1
	var sprite := SpriteBank.new(Main.SPRITES).get_sprite(ROUND_SPRITE)
	_round_texture = AtlasTexture.new()
	_round_texture.atlas = sprite.tex
	_round_texture.region = sprite.region

	var star := SphereMesh.new()
	star.radial_segments = 5
	star.rings = 2
	star.radius = 0.16
	star.height = 0.16
	star.material = _unshaded(Color(1.0, 0.75, 0.25))
	# On the bore itself, so it rides with the turret and the hull's pitch.
	_flash = MeshInstance3D.new()
	_flash.mesh = star
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	btr.muzzle_node().add_child(_flash)

	_puff_mesh = Level3DFx.ball(1, 0.12, 1)
	_chip_mesh = Level3DFx.ball(0, 0.25, 2)
	_materials = {
		"dust": _lit(Color(0.93, 0.76, 0.48)),
		# The sand's own orange, darker: what the round digs out.
		"clod": _lit(Color(0.82, 0.52, 0.2)),
		"leaves": _lit(Color(0.22, 0.45, 0.16)),
		"wood": _lit(Color(0.36, 0.24, 0.13)),
		"stone": _lit(Color(0.62, 0.62, 0.60)),
		"splash": _lit(Color(0.92, 0.97, 1.0)),
		"spark": _unshaded(Color(1.0, 0.9, 0.45)),
	}


func step(delta: float) -> void:
	if btr.classic:
		# Player.update, one tick of it.
		if _gun_armed > 0:
			_gun_armed -= 1
		if trigger:
			if (_shoot_released or _gun_armed == 0) and _in_flight < Player.MAX_BULLETS:
				_fire()
				_gun_armed = Player.TURBO_DELAY if turbo else Player.GUN_ARMED_DELAY
			_shoot_released = false
		else:
			_shoot_released = true
			_gun_armed = 0
		_cooldown = 0.0
	else:
		_cooldown -= delta
		if trigger:
			while _cooldown <= 0.0:
				_fire()
				_cooldown += FIRE_INTERVAL
		else:
			_cooldown = maxf(_cooldown, 0.0)
	_flash_left -= delta
	if _flash_left <= 0.0:
		_flash.visible = false


func _fire() -> void:
	var muzzle := btr.muzzle()
	var from := muzzle.origin
	var bearing := Vector3(muzzle.basis.x.x, 0.0, muzzle.basis.x.z).normalized()
	var direction := bearing
	var reach := CLASSIC_RANGE
	if not btr.classic:
		direction = bearing.rotated(Vector3.UP, _rng.randf_range(-SPREAD, SPREAD))
		reach = RANGE
		if aim_point != null:
			var to: Vector3 = aim_point - from
			reach = clampf(Vector2(to.x, to.z).length(), MIN_RANGE, RANGE)
		reach *= 1.0 + _rng.randf_range(-RANGE_JITTER, RANGE_JITTER)
	var landing := from + direction * reach
	var there: Dictionary = ground.call(landing.x, landing.z)
	landing.y = there.height
	var point := landing
	var normal := Vector3.UP
	var kind: String = there.kind if there.hit else "ground"
	var stop := _grid_stop(from, direction, reach)
	if stop >= 0.0:
		# Struck where the grid stops it, at the height it flew at or on top of
		# whatever is lower than that; head on.
		point = from + direction * stop
		var top: Dictionary = surface.call(point.x, point.z)
		if top.hit:
			point.y = minf(from.y, top.height)
		normal = -direction
		# A solid tile the scene has as bare ground is the grid's rock or
		# sandbag, drawn smaller than its tile.
		kind = top.kind if top.hit and not (top.kind in ["ground", ""]) else "wall"
	var line := point - from
	var found := {}
	if intercept.is_valid():
		found = intercept.call(from, point)
		if not found.is_empty():
			point = from.lerp(point, found.t)
			normal = -line.normalized()
			kind = "building"

	_round(from, point, kind, normal, line.normalized(), found)
	# A star at the bore, turned and sized afresh each round so a burst flickers.
	_flash.visible = true
	_flash.transform = Transform3D(Basis(Vector3.RIGHT, _rng.randf() * TAU)
			.scaled(Vector3(1.6, 1.0, 1.0) * _rng.randf_range(0.8, 1.2)), Vector3(0.12, 0.0, 0.0))
	_flash_left = FLASH_TIME
	btr.recoil(direction, RECOIL_KICK)


# PlayerBullet.update's is_missile_target, a tick's move at a time along the
# round's flight: how far it gets before a solid or shield tile stops it, or
# -1 if it flies its whole reach.
func _grid_stop(from: Vector3, direction: Vector3, reach: float) -> float:
	var step := PlayerBullet.VELOCITY * Level3DMap.PX
	var ticks := ceili(reach / step - 1e-6)
	for k in range(1, ticks + 1):
		var d := minf(k * step, reach)
		var p := Level3DMap.to_map(Vector2(from.x + direction.x * d, from.z + direction.z * d))
		if btr.map.is_missile_target(p.x, p.y):
			return d
	return -1.0


func _round(from: Vector3, to: Vector3, kind: String, normal: Vector3, travel: Vector3,
		found: Dictionary) -> void:
	# Drawn as Level3DGuns.enemy_bullet draws the enemies' rounds.
	var node := Sprite3D.new()
	node.texture = _round_texture
	node.pixel_size = Level3DMap.PX
	node.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	node.shaded = false
	node.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	node.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Over everything: Level3DGuns.ROUND_PRIORITY.
	node.no_depth_test = true
	node.render_priority = Level3DGuns.ROUND_PRIORITY
	get_parent().add_child(node)
	node.global_position = from
	_in_flight += 1
	var time := from.distance_to(to) / (CLASSIC_ROUND_SPEED if btr.classic else ROUND_SPEED)
	var tween := node.create_tween()
	tween.tween_property(node, "global_position", to, time)
	tween.tween_callback(func():
		node.queue_free()
		_in_flight -= 1
		_impact(to, kind, normal, travel)
		if not found.is_empty():
			struck.call(found))


# What a round leaves where it lands, by what it landed on.
func _impact(at: Vector3, kind: String, normal: Vector3, travel: Vector3) -> void:
	match kind:
		"water":
			_puffs(at, "splash", 3, 0.22, 0.35)
		"forest":
			_puffs(at, "leaves", 2, 0.18, 0.30)
		"trunk":
			_chips(at, normal, travel, "wood", 4)
		"wall", "building":
			_chips(at, normal, travel, "spark", 4)
			_chips(at, normal, travel, "stone", 3)
			_puffs(at, "stone", 1, 0.15, 0.25)
		"hard":
			# Concrete underfoot: what a wall throws, no sand.
			_chips(at, normal, travel, "spark", 3)
			_chips(at, normal, travel, "stone", 3)
			_puffs(at, "stone", 1, 0.12, 0.22)
		_:
			_dust(at, travel)


# A round in the sand, which is not smoke and does not rise: clods kicked up
# and back towards the gun, a cloud that swells low over the hole and settles
# back into it, and grains flung out and falling.
func _dust(at: Vector3, travel: Vector3) -> void:
	var back := Vector3(-travel.x, 0.0, -travel.z).normalized()
	var gravity := Vector3.DOWN * 9.8
	# Out to the sides as much as up: seen from above, sand thrown straight up
	# only sits on the cloud.
	for i in 5:
		var clod := _instance(_puff_mesh, "clod")
		var angle := _rng.randf_range(-PI, PI) * 0.8
		var side_way := back.rotated(Vector3.UP, angle)
		var out := (Vector3.UP * _rng.randf_range(0.7, 1.1) + side_way).normalized()
		var velocity := out * _rng.randf_range(1.8, 2.6)
		var size := _rng.randf_range(0.016, 0.026)
		var life := _rng.randf_range(0.28, 0.36)
		var fly := func(t: float):
			var v := velocity + gravity * t
			var p := at + velocity * t + gravity * 0.5 * t * t
			var shrink := clampf(2.0 - 2.0 * t / life, 0.0, 1.0)
			# Long along the way it flies, a streak of sand.
			var along := v.normalized()
			var side := along.cross(Vector3.UP if absf(along.y) < 0.99 else Vector3.RIGHT).normalized()
			clod.global_transform = Transform3D(
					Basis(side, along, side.cross(along)).scaled(Vector3(1.0, 1.7, 1.0) * size * shrink), p)
		_start(clod, fly, life)
	# A cluster, not a ball: each puff from a little way off the hole, going
	# its own way.
	for i in 4:
		var puff := _instance(_puff_mesh, "dust")
		var way := back.rotated(Vector3.UP, TAU * (i + _rng.randf_range(-0.3, 0.3)) / 4.0)
		var start := way * _rng.randf_range(0.03, 0.07)
		var drift := start + back * 0.06 + way * _rng.randf_range(0.08, 0.14)
		var peak := _rng.randf_range(0.08, 0.13)
		var life := _rng.randf_range(0.45, 0.6)
		var spin := _rng.randf() * TAU
		var swell := func(t: float):
			var k := t / life
			# Swells in the first eighth, then shrinks away; sits on the
			# ground as it goes, so that it settles as it shrinks.
			var size := peak * (1.0 - pow(1.0 - minf(k * 8.0, 1.0), 3.0)) * (1.0 - pow(maxf(k - 0.125, 0.0) / 0.875, 2.0))
			var p := at + start.lerp(drift, 1.0 - pow(1.0 - k, 2.0))
			p.y = at.y + size * 0.5
			puff.global_transform = Transform3D(Basis(Vector3.UP, spin).scaled(Vector3(1.0, 0.75, 1.0) * maxf(size, 0.001)), p)
		_start(puff, swell, life)
	for i in 4:
		var grain := _instance(_chip_mesh, "clod")
		var out := (Vector3.UP * _rng.randf_range(0.6, 1.2) + back * 0.3
				+ Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1))).normalized()
		var velocity := out * _rng.randf_range(1.5, 2.8)
		grain.scale = Vector3.ONE * _rng.randf_range(0.01, 0.016)
		var life := _rng.randf_range(0.25, 0.35)
		var fall := func(t: float):
			var p := at + velocity * t + gravity * 0.5 * t * t
			p.y = maxf(p.y, at.y + 0.01)
			grain.global_position = p
		_start(grain, fall, life)


# Runs `move` over `life` seconds, then frees the node -- and once now: a
# tween's first step is the next frame, and until then the node would be drawn
# as it was made, a ball a metre across at the middle of the map, once a round.
func _start(node: Node3D, move: Callable, life: float) -> void:
	move.call(0.0)
	var tween := node.create_tween()
	tween.tween_method(move, 0.0, life, life)
	tween.tween_callback(node.queue_free)


# A few low-poly balls that swell and shrink away, rising a little.
func _puffs(at: Vector3, material: String, count: int, size: float, life: float) -> void:
	for i in count:
		var puff := _instance(_puff_mesh, material)
		var offset := Vector3(_rng.randf_range(-1, 1), 0.0, _rng.randf_range(-1, 1)) * size
		puff.global_position = at + offset
		puff.scale = Vector3.ONE * size * 0.3
		var peak := size * _rng.randf_range(0.8, 1.3)
		var tween := puff.create_tween()
		tween.set_parallel()
		tween.tween_property(puff, "scale", Vector3.ONE * peak, life * 0.3).set_ease(Tween.EASE_OUT)
		tween.tween_property(puff, "global_position", puff.global_position + Vector3.UP * size * 1.5, life)
		tween.tween_property(puff, "scale", Vector3.ONE * 0.001, life * 0.7).set_delay(life * 0.3) \
				.set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(puff.queue_free)


# Bits thrown back off a hard surface: out along the normal, back towards the
# gun, and falling.
func _chips(at: Vector3, normal: Vector3, travel: Vector3, material: String, count: int) -> void:
	var bounce := (travel - 2.0 * travel.dot(normal) * normal).normalized()
	for i in count:
		var chip := _instance(_chip_mesh, material)
		# Half a unit box's 0.03 to 0.06: the chip is a ball of radius 1.
		var size := _rng.randf_range(0.015, 0.03)
		chip.scale = Vector3.ONE * size
		chip.global_position = at + normal * 0.03
		var out := (bounce + normal + Vector3(_rng.randf_range(-0.6, 0.6), _rng.randf_range(0.2, 0.9),
				_rng.randf_range(-0.6, 0.6))).normalized()
		var life := _rng.randf_range(0.18, 0.3)
		var velocity := out * _rng.randf_range(2.0, 4.0)
		var tween := chip.create_tween()
		tween.tween_method(func(t: float):
			chip.global_position = at + velocity * t + Vector3.DOWN * 4.9 * t * t, 0.0, life, life)
		tween.tween_callback(chip.queue_free)


# The material goes on before the node enters the tree, where the preview's
# _toon gives it its two-tone light.
func _instance(mesh: Mesh, material: String) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = _materials[material]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(node)
	return node


static func _unshaded(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	return material


static func _lit(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 1.0
	# What is lit is drawn round, as the models are; what glows is not.
	return Level3DFx.contour(material)
