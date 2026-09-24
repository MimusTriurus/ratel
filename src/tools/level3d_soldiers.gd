# The enemy soldiers on the 3D stage 1 preview: jackal.EnemySoldier and
# jackal.DeadEnemySoldier, on jackal_trooper.glb or jackal_soldier.glb (MODELS).
#
# Nothing here is part of the game, and all of it is the game's: the soldiers
# are stage-0.json's SOLDIER_WALKER and SOLDIER_STATIONARY triggers on normal,
# spawned as GameMode._process_triggers spawns them, and they walk, aim, fire
# and die by EnemySoldier's code on the game's own map -- its collision grid
# and its flow field, through Level3DMap, in map pixels and ticks. The level is
# only where they are drawn, which it can be because it lies on the map to a
# tile (Level3DMap). Their rounds are EnemyBullets and the explosions that kill
# them are Explosions, both Level3DGuns'.
#
# What the game does, and so this:
#   * A walker seeks: it walks towards the player along the flow field for
#     one to five legs of one to four seconds each, veering by up to 22.5
#     degrees, turning off at a right angle when the way is barred and away
#     when it comes within 128 px of the player. Then, if the player is more
#     than 96 px off, it aims: 114 ticks, the last 23 blinking, and one round
#     (total_shots on stage 1); then it seeks again.
#   * A stationary soldier only aims, for 114 ticks and up to 182 more, and
#     never moves.
#   * One of anything kills a soldier: a round, a grenade or missile passing
#     through (it does not stop them -- EnemySoldier.attack returns false), any
#     explosion including the player's own, or being run over, which does not
#     hurt the player. He falls, lies for 182 ticks and fades over 91; the
#     corpse is 100 points.
#
# He is drawn as the trooper of the soldier model sheet (jackal_trooper.glb,
# jackal_soldier_lowpoly.blend) unless the preview is given --sprite-soldiers,
# which brings back the figure made from the game's sprite (jackal_soldier.glb,
# jackal_units.blend). The same flag does the prisoners (level3d_friends.gd).
# Both are the same soldier to everything above: MODELS
# says what differs -- the trooper is a 1.8 m man shrunk to the sprite
# figure's metre, blinks his khaki, and walks by the ground he covers.
#
# Where this departs from the game, and why:
#   * The hit and mine boxes are the game's 32 x 60 px, but centred on him
#     rather than hung 54 px above his feet: that offset is the sprite standing
#     up the screen, and here he stands up out of it.
#   * He fires from where he stands, at the player, not from 30 px up the
#     screen at a point 30 px down it -- the same sprite offset twice.
#   * He faces the way he walks or aims, not the nearest of four.
class_name Level3DSoldiers
extends Node3D

const SOLDIER_PATH := "res://resources/3d/jackal_soldier.glb"
const TROOPER_PATH := "res://resources/3d/jackal_trooper.glb"
const PX := Level3DMap.PX

# What the two figures need said about them:
#   scale        to the sprite figure's metre -- what keeps him in proportion
#                with the BTR and the bunkers (jackal_units.blend)
#   round_height where his rifle is when he fires, metres, scaled
#   brown, dark  the materials his blink recolours, as the yellow sheet does
#                the sprite's brown and black
#   stride       metres a Walk cycle covers, unscaled, for a walk driven by the
#                ground covered; 0 steps it by the game's leg frames, which is
#                right for the sprite figure's two-frame walk and slides the
#                trooper's feet (his cycle is 0.8 m, the game's 26 ticks 13 px)
#   loop_pad     seconds the looping clips are short of their repeat: the
#                trooper's are exported up to the frame before the first again
const MODELS := {
	"trooper": {"path": TROOPER_PATH, "scale": 0.55, "round_height": 0.72,
			"brown": "T_Uniform", "dark": "T_UniformDark", "stride": 0.8, "loop_pad": 1.0 / 24.0},
	"sprite": {"path": SOLDIER_PATH, "scale": 1.0, "round_height": 0.55,
			"brown": "J_SoldierBrown", "dark": "J_SoldierDark", "stride": 0.0, "loop_pad": 0.0},
}

# EnemySoldier.init()'s boxes, pixels from his position. Solid is the game's,
# for walking round each other; hit and mine are the same size, centred.
const SOLID := Rect2(-16, -54, 32, 60)
const HIT := Rect2(-16, -30, 32, 60)
const POINTS := 100
# SOLDIER_*: 2 x 3 tiles, the soldier at (32, 74) px into it. A trigger fires
# when its bottom row is one above the frame's top row: his position 22 px
# above the top edge.
const TRIGGER_OFFSET := Vector2(32, 74)
# GameMode.REMOVE_BOUND and CAMERA_BOUND, in pixels: an enemy whose solid box is
# this far below the furthest the frame has been is gone.
const REMOVE_BOUND := 1536.0 + (1152 - 960)
const CAMERA_BOUND := 1152.0
# The yellow sheet he blinks: enemy-soldier-yellow.png's colours for the
# brown and the black of enemy-soldier-brown.png.
const BLINK_BROWN := Color8(188, 190, 0)
const BLINK_DARK := Color8(108, 7, 0)
# The Walk clip is a whole leg cycle; the game's is LEG_FRAMES ticks.
const WALK := "Walk"
const AIM := "Aim"
const SHOOT := "Shoot"
const DEATH := "Death"
# DeadEnemySoldier: lies, then fades; here it sinks this far into the sand.
const SINK := 0.3

const STATE_SEEKING := 0
const STATE_AIMING := 1

var map: Level3DMap
var guns: Level3DGuns
# `frame.call()`: the frame the player sees, Rect2 in level x, z.
var frame: Callable
# `ground.call(x, z)`: {"height": ...} as the preview's.
var ground: Callable
# `player_position.call()`: the player's level x, z.
var player_position: Callable
var scored: Callable
# `more_solids.call()`: other solid boxes to walk round, map px -- the
# prisoners' (level3d_friends.gd).
var more_solids: Callable
var verbose := false

# MODELS' entry for the figure he is drawn as.
var model: Dictionary
var soldiers: Array[Soldier] = []
var _corpses: Array[Soldier] = []
var _scene: PackedScene
var _rng := RandomNumberGenerator.new()
var _trigger_y := -1
var _furthest_top := INF


class Soldier:
	var type: int
	var x: float            # map pixels
	var y: float
	var state := STATE_SEEKING
	var target_vx := 0.0
	var target_vy := 0.0
	var direction_x := 0.0
	var direction_y := 1.0
	var walking := 0
	var aiming := 0
	var leg_frames := 0
	# Walk cycles covered, for a model that walks by its stride.
	var stride_phase := 0.0
	var walk_steps := 0
	var blink := 0
	var shots := 0
	var total_shots := 1
	var in_swamp := false
	var moved := false
	# DeadEnemySoldier
	var dead := false
	var fading := false
	var delay := 0
	var root: Node3D
	var player: AnimationPlayer
	var fade: Level3DCrossfade
	# Where the Walk is, 0..1, set by the tick and sought by the frame.
	var walk_phase := 0.0
	var brown: StandardMaterial3D
	var dark: StandardMaterial3D
	var brown_colour: Color
	var dark_colour: Color


func _ready() -> void:
	_rng.seed = 3
	model = MODELS["sprite" if OS.get_cmdline_user_args().has("--sprite-soldiers") else "trooper"]
	_scene = load(model.path)
	if _scene == null:
		push_error("Cannot load %s -- run export() in its .blend" % model.path)
		return
	# The clips are the scene's, shared by every soldier: padded once, here.
	if model.loop_pad > 0.0:
		var probe := _scene.instantiate()
		var clips := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
		for clip in [WALK, AIM]:
			clips.get_animation(clip).length += model.loop_pad
		probe.free()
	reset()


# No soldiers, and the triggers from the bottom of the map again.
func reset() -> void:
	for s in soldiers + _corpses:
		s.root.queue_free()
	soldiers.clear()
	_corpses.clear()
	_trigger_y = map.stage.map_height
	_furthest_top = INF


# ----------------------------------------------------------------------------
# The tick

func tick() -> void:
	var view: Rect2 = frame.call()
	var top := Level3DMap.to_map(view.position).y
	_process_triggers(top)
	_furthest_top = minf(_furthest_top, top)
	var player := Level3DMap.to_map(player_position.call())
	for i in range(soldiers.size() - 1, -1, -1):
		var s := soldiers[i]
		_update(s, player)
		# Enemy.check_bounds
		if s.y + SOLID.position.y > _furthest_top + CAMERA_BOUND + REMOVE_BOUND:
			s.root.queue_free()
			soldiers.remove_at(i)
	for i in range(_corpses.size() - 1, -1, -1):
		if _update_corpse(_corpses[i]):
			_corpses.remove_at(i)


# GameMode._process_triggers, for the soldiers' triggers only (the guns are
# Level3DGuns'): every row from the last one fired up to the one above the
# frame's top row.
func _process_triggers(top: float) -> void:
	var row := (int(top) >> 5) - 1
	if row < 0:
		return
	var triggers: Array = map.stage.trigger_map[0]
	while _trigger_y > row:
		_trigger_y -= 1
		var list: Array = triggers[_trigger_y]
		for i in range(list.size() - 1, -1, -1):
			var t: Array = list[i]
			match t[0]:
				Triggers.SOLDIER_WALKER:
					_spawn(t[1] + TRIGGER_OFFSET.x, t[2] + TRIGGER_OFFSET.y, EnemySoldierType.WALKER)
				Triggers.SOLDIER_STATIONARY:
					_spawn(t[1] + TRIGGER_OFFSET.x, t[2] + TRIGGER_OFFSET.y, EnemySoldierType.STATIONARY)


func _spawn(x: float, y: float, type: int) -> void:
	var s := Soldier.new()
	s.x = x
	s.y = y
	s.type = type
	# EnemySoldier._init on stage 1: one round before he moves on.
	s.total_shots = 1
	s.root = _scene.instantiate() as Node3D
	s.root.scale = Vector3.ONE * model.scale
	add_child(s.root)
	s.player = s.root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in [WALK, AIM]:
		s.player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	# Advanced by hand in _process, so that the fade can go on top of it.
	s.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_own_materials(s)
	soldiers.append(s)
	var player := Level3DMap.to_map(player_position.call())
	match type:
		EnemySoldierType.WALKER:
			_start_seeking(s, player)
		EnemySoldierType.STATIONARY:
			_start_aiming(s, player)
	_place(s)
	s.fade = Level3DCrossfade.new(s.root, s.player.assigned_animation)
	if verbose:
		print("soldier %s appears at %.0f, %.0f" % ["walker" if type == EnemySoldierType.WALKER else "stationary", x, y])


# Each soldier blinks on his own, so each has his own brown and black.
func _own_materials(s: Soldier) -> void:
	for mesh_instance in s.root.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh_instance as MeshInstance3D
		for surface in mi.mesh.get_surface_count():
			var material := mi.mesh.surface_get_material(surface) as StandardMaterial3D
			if material == null:
				continue
			if material.resource_name == model.brown:
				s.brown = material.duplicate()
				mi.set_surface_override_material(surface, s.brown)
			elif material.resource_name == model.dark:
				s.dark = material.duplicate()
				mi.set_surface_override_material(surface, s.dark)
	s.brown_colour = s.brown.albedo_color
	s.dark_colour = s.dark.albedo_color


# EnemySoldier.update.
func _update(s: Soldier, player: Vector2) -> void:
	s.in_swamp = map.is_swamp(s.x, s.y)
	s.moved = false
	if s.type == EnemySoldierType.WALKER:
		match s.state:
			STATE_SEEKING:
				_seek(s, player)
			STATE_AIMING:
				_aim(s, player)
	else:
		_aim(s, player)
	_place(s)


func _walk_speed(s: Soldier) -> float:
	return 0.5 * EnemySoldier.WALK_SPEED if s.in_swamp else EnemySoldier.WALK_SPEED


func _target_player(s: Soldier, player: Vector2) -> void:
	var d := map.suggest_direction(s.x, s.y, player.x, player.y, _rng)
	s.direction_x = d.x
	s.direction_y = d.y
	s.target_vx = _walk_speed(s) * d.x
	s.target_vy = _walk_speed(s) * d.y
	s.walking = _rng.randi_range(0, EnemySoldier.MAX_WALK_TIME - EnemySoldier.MIN_WALK_TIME - 1) \
		+ EnemySoldier.MIN_WALK_TIME


func _avoid_getting_too_close_to_player(s: Soldier, player: Vector2) -> void:
	var dx := player.x - s.x
	var dy := player.y - s.y
	var r2 := dx * dx + dy * dy
	if r2 < 16384 and dx * s.direction_x + dy * s.direction_y > 0:
		var v := (Vector2(-dx, -dy) / sqrt(r2)).rotated(_rng.randf() * 0.3927 - 0.1963)
		s.direction_x = v.x
		s.direction_y = v.y
		s.target_vx = _walk_speed(s) * v.x
		s.target_vy = _walk_speed(s) * v.y
		s.walking = _rng.randi_range(0, EnemySoldier.MAX_WALK_TIME - EnemySoldier.MIN_WALK_TIME - 1) \
			+ EnemySoldier.MIN_WALK_TIME


func _walk_at_right_angle_to_barrier(s: Soldier) -> void:
	var d := Level3DMap.suggest_direction_bounce(s.direction_x, s.direction_y, _rng)
	s.direction_x = d.x
	s.direction_y = d.y
	s.target_vx = _walk_speed(s) * d.x
	s.target_vy = _walk_speed(s) * d.y


func _aim(s: Soldier, player: Vector2) -> void:
	s.direction_x = player.x - s.x
	s.direction_y = player.y - s.y
	# Too close to shoot: a walker breaks off, anyone else just waits.
	if s.aiming > EnemySoldier.AIM_BLINKING:
		var r2 := s.direction_x * s.direction_x + s.direction_y * s.direction_y
		if r2 <= 9216:
			if s.type == EnemySoldierType.WALKER:
				_start_seeking(s, player)
			return
	s.aiming -= 1
	if s.aiming <= 0:
		_shoot(s)
		s.shots += 1
		if s.shots == s.total_shots:
			s.shots = 0
			if s.type == EnemySoldierType.WALKER:
				_start_seeking(s, player)
			else:
				_start_aiming(s, player)
		else:
			s.aiming = EnemySoldier.AIM_RESHOOT


func _shoot(s: Soldier) -> void:
	var d := Vector2(s.direction_x, s.direction_y).normalized()
	guns.enemy_bullet(Level3DMap.to_level(Vector2(s.x, s.y)), d * EnemyBullet.SPEED,
			EnemySoldier.BULLET_TRAVEL_TIME, model.round_height)
	s.player.play(SHOOT)
	s.player.queue(AIM)


func _start_aiming(s: Soldier, player: Vector2) -> void:
	s.state = STATE_AIMING
	s.aiming = EnemySoldier.AIM_FRAMES
	if s.type != EnemySoldierType.WALKER:
		s.aiming += _rng.randi_range(0, EnemySoldier.EXTRA_AIMING_TIME - 1)
	# Straight after a round the kick plays out first; Aim is queued behind it.
	if s.player.current_animation != SHOOT:
		s.player.play(AIM)
	_aim(s, player)


func _start_seeking(s: Soldier, player: Vector2) -> void:
	s.state = STATE_SEEKING
	s.walk_steps = 1 + _rng.randi_range(0, EnemySoldier.MAX_WALK_STEPS - 1)
	s.player.play(WALK)
	_target_player(s, player)


func _seek(s: Soldier, player: Vector2) -> void:
	s.walking -= 1
	if s.walking <= 0:
		s.walk_steps -= 1
		if s.walk_steps <= 0:
			var dx := player.x - s.x
			var dy := player.y - s.y
			if dx * dx + dy * dy > 9216:
				_start_aiming(s, player)
				return
			_target_player(s, player)
		else:
			_target_player(s, player)

	_avoid_getting_too_close_to_player(s, player)

	var next_x := s.x + s.target_vx
	var next_y := s.y + s.target_vy
	var walkable := map.is_driveable_box(next_x - 16, next_y - 6, next_x + 16, next_y + 6)
	if walkable:
		# Avoid bumping into other enemies, but never get stuck inside one.
		var now := Rect2(Vector2(s.x, s.y) + SOLID.position, SOLID.size)
		var then := Rect2(Vector2(next_x, next_y) + SOLID.position, SOLID.size)
		for box in _solids(s):
			if box.intersects(then) and not box.intersects(now):
				walkable = false
				break
	if walkable:
		if model.stride > 0.0:
			s.stride_phase += Vector2(next_x - s.x, next_y - s.y).length() * PX / (model.stride * model.scale)
		s.x = next_x
		s.y = next_y
		s.moved = true
		if s.leg_frames == 0:
			s.leg_frames = EnemySoldier.LEG_FRAMES - 1
		s.leg_frames -= 1
	else:
		_walk_at_right_angle_to_barrier(s)


# The other enemies' solid boxes, in map pixels: the guns' and the soldiers'.
func _solids(me: Soldier) -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for box in guns.solid_boxes():
		var a := Level3DMap.to_map(box.position)
		boxes.append(Rect2(a, box.size / PX))
	for other in soldiers:
		if other != me:
			boxes.append(Rect2(Vector2(other.x, other.y) + SOLID.position, SOLID.size))
	if more_solids.is_valid():
		boxes.append_array(more_solids.call())
	return boxes


# The soldiers' own solid boxes, map px, for the prisoners to walk round.
func solid_boxes() -> Array[Rect2]:
	var boxes: Array[Rect2] = []
	for s in soldiers:
		boxes.append(Rect2(Vector2(s.x, s.y) + SOLID.position, SOLID.size))
	return boxes


# Where he stands and which way he faces, the leg frame he is on, and the
# blink: EnemySoldier.render, in so far as it is not the tick's.
func _place(s: Soldier) -> void:
	var at := Level3DMap.to_level(Vector2(s.x, s.y))
	var height: float = ground.call(at.x, at.y).height
	s.root.position = Vector3(at.x, height, at.y)
	if s.direction_x != 0.0 or s.direction_y != 0.0:
		s.root.rotation.y = atan2(s.direction_x, s.direction_y)
	if s.state == STATE_SEEKING and s.type == EnemySoldierType.WALKER:
		# The walk advances only on a step taken, as the leg frames do -- or,
		# for a model with a stride, by the ground the step covered.
		s.walk_phase = float(EnemySoldier.LEG_FRAMES - 1 - s.leg_frames) / EnemySoldier.LEG_FRAMES
		if model.stride > 0.0:
			s.walk_phase = fposmod(s.stride_phase, 1.0)


# Per rendered frame, as EnemySoldier.render counts it.
func _process(delta: float) -> void:
	for s in soldiers:
		s.blink -= 1
		if s.blink < 0:
			s.blink = 4
		var blinking := s.blink < 2 and s.state == STATE_AIMING and s.aiming <= EnemySoldier.AIM_BLINKING
		s.brown.albedo_color = BLINK_BROWN if blinking else s.brown_colour
		s.dark.albedo_color = BLINK_DARK if blinking else s.dark_colour
	for s in soldiers + _corpses:
		_pose(s, delta)


# The frame's pose: the clip, faded into from whatever was on screen when it
# changed -- walk to aim, aim to walk, the kick back to aim, anything to the
# fall (Level3DCrossfade). The Walk is sought where the tick left it, the rest
# played on.
func _pose(s: Soldier, delta: float) -> void:
	s.fade.before()
	if s.player.assigned_animation == WALK:
		s.player.seek(s.walk_phase * s.player.get_animation(WALK).length, true)
	else:
		s.player.advance(delta)
	s.fade.after(s.player.assigned_animation, delta)


# ----------------------------------------------------------------------------
# Dying

# EnemySoldier.do_remove + DeadEnemySoldier.
func _kill(i: int, by: String) -> void:
	var s := soldiers[i]
	soldiers.remove_at(i)
	s.dead = true
	s.delay = DeadEnemySoldier.PRE_FADE_DELAY
	s.brown.albedo_color = s.brown_colour
	s.dark.albedo_color = s.dark_colour
	s.player.play(DEATH)
	_corpses.append(s)
	scored.call(POINTS)
	if verbose:
		print("soldier killed (%s) at %.0f, %.0f, tick %d" % [by, s.x, s.y, Engine.get_physics_frames()])


# DeadEnemySoldier.update: true when it is gone.
func _update_corpse(s: Soldier) -> bool:
	s.delay -= 1
	if s.fading:
		# render() draws it at delay / FADE_DELAY: whole until the last 91.
		var left := clampf(float(s.delay) / DeadEnemySoldier.FADE_DELAY, 0.0, 1.0)
		var at := Level3DMap.to_level(Vector2(s.x, s.y))
		s.root.position.y = ground.call(at.x, at.y).height - SINK * (1.0 - left)
	if s.delay != 0:
		return false
	if s.fading:
		s.root.queue_free()
		return true
	s.fading = true
	s.delay = DeadEnemySoldier.PRE_FADE_DELAY
	return false


func _hit_box(s: Soldier, margin: float) -> Rect2:
	var box := Rect2(Vector2(s.x, s.y) + HIT.position, HIT.size).grow(margin)
	return Rect2(Level3DMap.to_level(box.position), box.size * PX)


# The first soldier a round's flight from `from` to `to` meets, its box grown
# by the round's `margin` px: {"t", "soldier"} or empty. EnemySoldier's
# bullet_attack takes the round.
func intercept(from: Vector3, to: Vector3, margin: float) -> Dictionary:
	var best := {}
	for s in soldiers:
		var t := Level3DGuns._segment_enters(Vector2(from.x, from.z), Vector2(to.x, to.z), _hit_box(s, margin))
		if t >= 0.0 and (best.is_empty() or t < best.t):
			best = {"t": t, "soldier": s}
	return best


func bullet_attack(found: Dictionary) -> void:
	var i := soldiers.find(found.soldier)
	if i >= 0:
		_kill(i, "machine gun")


# A grenade's or missile's flight from `from` to `to`: every soldier it passes
# dies and it flies on (EnemySoldier.attack returns false). Only on screen, as
# the grenade looks.
func sweep(from: Vector3, to: Vector3, margin: float) -> void:
	var view: Rect2 = frame.call()
	for i in range(soldiers.size() - 1, -1, -1):
		var box := _hit_box(soldiers[i], margin)
		if view.intersects(box) and Level3DGuns._segment_enters(Vector2(from.x, from.z), Vector2(to.x, to.z), box) >= 0.0:
			_kill(i, "rocket")


# An Explosion's box this tick (Level3DGuns): any soldier in it dies.
func explosion_hit(box: Rect2, player: bool) -> void:
	for i in range(soldiers.size() - 1, -1, -1):
		if box.intersects(_hit_box(soldiers[i], 0.0)):
			_kill(i, "the player's explosion" if player else "explosion")


# EnemySoldier.bump: the player ran him over. He dies; the player does not.
func bump(player_box: Rect2) -> void:
	for i in range(soldiers.size() - 1, -1, -1):
		if player_box.intersects(_hit_box(soldiers[i], 0.0)):
			_kill(i, "run over")
