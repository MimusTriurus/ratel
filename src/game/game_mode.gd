# Port of jackal.GameMode.
class_name GameMode
extends RefCounted

const CAMERA_MARGIN_NORTH := 384.0
const CAMERA_MARGIN_SOUTH := 192.0
const CAMERA_MARGIN_SIDES := 256.0
const CAMERA_BOUND := 224.0
const REMOVE_BOUND := 1536.0
const BOSS_PAN_CAMERA_SPEED := 4.0
const ENDING_PAN_CAMERA_SPEED := 2.0
const CONVEYOR_SPEED := Player.SPEED / 3.0
const STAGE_COMPLETED_DELAY := 228

const TYPE_SOLID := 0
const TYPE_EMPTY := 1
const TYPE_SHIELD := 2
const TYPE_WATER := 3
const TYPE_SWAMP := 4
const TYPE_CONVEYOR := 5

const DIR_UP := 0
const DIR_DOWN := 1
const DIR_LEFT := 2
const DIR_RIGHT := 3
const DIR_UP_LEFT := 4
const DIR_UP_RIGHT := 5
const DIR_DOWN_LEFT := 6
const DIR_DOWN_RIGHT := 7

const DIRECTION_RADIANS: Array[float] = [
	3.0 * PI / 2.0,
	PI / 2.0,
	PI,
	0.0,
	5.0 * PI / 4.0,
	7.0 * PI / 4.0,
	3.0 * PI / 4.0,
	PI / 4.0,
]

const DIRECTION_DEGREES: Array[int] = [270, 90, 180, 0, 225, 315, 135, 45]

const WATER_ALPHAS_PERIOD := 136
static var WATER_ALPHAS: PackedFloat32Array = PackedFloat32Array()

var main: Main
var input: HumanInput

var stage: Stage

var tile_map: Array = []          # mutable during gameplay
var types_map: Array = []         # mutable during gameplay
var trigged_groups: PackedByteArray = PackedByteArray()

var tiles: Array[Spr] = []
var groups: Array = []
var trigger_map: Array = []
var groups_map: Array = []
var map_width: int
var map_height: int
var directions: PackedInt64Array = PackedInt64Array()
var directions_width: int
var directions_height: int
var water_alpha_index: int
var conveyor_offset: float
var conveyor_last_index: int
var conveyor_delta: float

var player: Player
var camera_x: float
var camera_y: float
var max_camera_x: float
var max_camera_y: float
var paused: bool
var trigger_y: int
var boss_camera_pan: bool
var ending_camera_pan: bool
var playing: bool = true
var camera_pan_listener = null

var stage_index: int

var stage_completed: bool
var stage_completed_delay: int = STAGE_COMPLETED_DELAY

var elements: Array = []          # 8 layers of Array[GameElement]

var enemies: Array[Enemy] = []
var solids: Array[Enemy] = []
var mines: Array[Enemy] = []


static func _static_init() -> void:
	WATER_ALPHAS.resize(WATER_ALPHAS_PERIOD)
	for i in WATER_ALPHAS_PERIOD:
		WATER_ALPHAS[i] = 0.5 + 0.5 * sin(2.0 * PI * i / float(WATER_ALPHAS_PERIOD))


func init(p_main: Main) -> void:
	main = p_main
	input = p_main.input

	p_main.friendly_soldiers_picked_up = 0
	FriendlySoldier.reset_count()

	elements = []
	for i in 8:
		var layer: Array[GameElement] = []
		elements.append(layer)

	trigger_y = map_height
	max_camera_x = float((map_width - 32) * 32)
	max_camera_y = float((map_height - 31) * 32)
	camera_x = 0.0
	camera_y = max_camera_y

	player = Player.new()
	player.y = camera_y + 2 * Main.DISPLAY_HEIGHT


func set_stage(p_stage_index: int, p_stage: Stage, hard: bool) -> void:
	stage_index = p_stage_index
	stage = p_stage

	tiles = p_stage.tiles
	groups = p_stage.groups
	trigger_map = p_stage.trigger_map[1 if hard else 0]
	groups_map = p_stage.groups_map
	map_width = p_stage.map_width
	map_height = p_stage.map_height
	directions = p_stage.directions
	directions_width = p_stage.directions_width
	directions_height = p_stage.directions_height

	# The pristine maps are shared between plays; gameplay mutates copies.
	tile_map = []
	for row in p_stage.tile_map:
		tile_map.append((row as PackedInt32Array).duplicate())

	types_map = []
	for row in p_stage.types_map:
		types_map.append((row as PackedInt32Array).duplicate())

	trigged_groups = PackedByteArray()
	trigged_groups.resize(groups.size())


func start_boss_camera_pan(listener) -> void:
	boss_camera_pan = true
	camera_pan_listener = listener


func start_ending_camera_pan(listener) -> void:
	playing = false
	ending_camera_pan = true
	camera_pan_listener = listener


func rotate(v: PackedFloat32Array, angle: float) -> void:
	var c := cos(angle)
	var s := sin(angle)
	var vx := v[0]
	var vy := v[1]
	v[0] = vx * c - vy * s
	v[1] = vx * s + vy * c


func trigger_group(group_index: int) -> void:
	if trigged_groups[group_index] != 0:
		return
	trigged_groups[group_index] = 1
	var group: Array = groups[group_index]
	for i in range(group.size() - 1, -1, -1):
		var g: Array = group[i]
		tile_map[g[1]][g[0]] = g[2]
		types_map[g[1]][g[0]] = g[3]


# Rotates 90+ degrees; used after a collision.
func suggest_direction_bounce(vx: float, vy: float) -> PackedFloat32Array:
	var clockwise := true

	if vy >= 0:
		if vx >= 0:
			if vy > vx:
				clockwise = false
		else:
			if -vx > vy:
				clockwise = false
	else:
		if vx >= 0:
			if vx > -vy:
				clockwise = false
		else:
			if vx >= vy:
				clockwise = false

	var angle := 1.571 + 0.4 * main.random.randf()
	var v := main.unit_vector
	v[0] = vx
	v[1] = vy
	rotate(v, angle if clockwise else -angle)
	return v


func straight_direction(x1: float, y1: float, x2: float, y2: float) -> PackedFloat32Array:
	var angle := rad_to_deg(atan2(y2 - y1, x2 - x1))
	if angle < 0:
		angle += 360
	var ang := 45 * int(round(angle / 45.0))
	var v := main.create_unit_vector(ang)
	v[2] = ang
	return v


# Looks the next step up in the stage's precomputed flow field. Returns
# [dx, dy, angle]; falls back to a straight line outside the field.
func suggest_direction(x1: float, y1: float, x2: float, y2: float,
		add_randomness: bool) -> PackedFloat32Array:
	var d := _lookup_direction(x1, y1, x2, y2)
	if d < 0:
		return straight_direction(x1, y1, x2, y2)

	var v: PackedFloat32Array
	if add_randomness:
		var angle: float = DIRECTION_RADIANS[d] + (main.random.randf() - 0.5) * 0.7854
		v = main.create_unit_vector2(angle)
		v[2] = angle
	else:
		var angle: int = DIRECTION_DEGREES[d]
		v = main.create_unit_vector(angle)
		v[2] = angle
	return v


# As above, but turns at most 45 degrees per step away from current_angle.
func suggest_direction_turning(x1: float, y1: float, x2: float, y2: float,
		current_angle: int, add_randomness: bool) -> PackedFloat32Array:
	var d := _lookup_direction(x1, y1, x2, y2)
	if d < 0:
		return straight_direction(x1, y1, x2, y2)

	var v: PackedFloat32Array
	if add_randomness:
		var angle: float = DIRECTION_RADIANS[d] + (main.random.randf() - 0.5) * 0.7854
		v = main.create_unit_vector2(angle)
		v[2] = angle
	else:
		var target_angle: int = DIRECTION_DEGREES[d]
		var delta_angle := (target_angle - current_angle + 180) % 360
		if delta_angle < 0:
			delta_angle += 180
		else:
			delta_angle -= 180
		if delta_angle != 0:
			if delta_angle < 0:
				current_angle -= 45
			else:
				current_angle += 45
			if current_angle < 0:
				current_angle += 360
			elif current_angle >= 360:
				current_angle -= 360
		v = main.create_unit_vector(current_angle)
		v[2] = current_angle
	return v


# Returns a direction 0..7, or -1 when the query falls outside the field.
func _lookup_direction(x1: float, y1: float, x2: float, y2: float) -> int:
	var X1 := int(x1) >> 7
	var Y1 := int(y1) >> 7
	var X2 := int(x2) >> 7
	var Y2 := int(y2) >> 7

	if X1 < 0 or Y1 < 0 or X1 >= directions_width or Y1 >= directions_height \
			or X2 < 0 or Y2 < 0 or X2 >= directions_width or Y2 >= directions_height:
		return -1

	var i := (((Y1 << 4) + X1) << 4) * directions_height + ((Y2 << 4) + X2)
	var index := i / 21
	var shift := 3 * (i % 21)

	if index < 0 or index >= directions.size():
		return -1

	return int((directions[index] >> shift) & 7)


func _camera_track_player() -> void:
	if player.x - camera_x < CAMERA_MARGIN_SIDES:
		camera_x = player.x - CAMERA_MARGIN_SIDES
		if camera_x < 0:
			camera_x = 0
	elif camera_x - player.x < CAMERA_MARGIN_SIDES - Main.DISPLAY_WIDTH:
		camera_x = player.x + CAMERA_MARGIN_SIDES - Main.DISPLAY_WIDTH
		if camera_x > max_camera_x:
			camera_x = max_camera_x

	if player.y - camera_y < CAMERA_MARGIN_NORTH:
		camera_y = player.y - CAMERA_MARGIN_NORTH
		if camera_y < 0:
			camera_y = 0
	elif camera_y - player.y < CAMERA_MARGIN_SOUTH - Main.DISPLAY_HEIGHT:
		camera_y = player.y + CAMERA_MARGIN_SOUTH - Main.DISPLAY_HEIGHT
		if camera_y > max_camera_y:
			camera_y = max_camera_y

	# The camera never scrolls back down: max_camera_y only ever shrinks.
	var max_y := camera_y + CAMERA_BOUND
	if max_y < max_camera_y:
		max_camera_y = max_y


func _process_triggers() -> void:
	var row := (int(camera_y) >> 5) - 1
	if row < 0:
		return
	while trigger_y > row:
		trigger_y -= 1
		var triggers: Array = trigger_map[trigger_y]
		for i in range(triggers.size() - 1, -1, -1):
			var t: Array = triggers[i]
			process_trigger(t[0], t[1], t[2])


func process_trigger(index: int, x: int, y: int) -> void:
	match index:
		Triggers.GRAY_GUN:
			RotatingGun.make_gray(x + 64, y + 64, true)
		Triggers.SOLDIER_WALKER:
			EnemySoldier.new(x + 32, y + 74, EnemySoldierType.WALKER)
		Triggers.SOLDIER_STATIONARY:
			EnemySoldier.new(x + 32, y + 74, EnemySoldierType.STATIONARY)
		Triggers.GREEN_BOAT:
			GreenBoat.new(x + 72, y + 56)
		Triggers.BROWN_TANK:
			BrownTank.new(x + 32, y + 48)
		Triggers.FRIENDLY_HELICOPTER_LANDING:
			FriendlyHelicopter.new(camera_x + Main.DISPLAY_WIDTH / 2.0,
				camera_y + Main.DISPLAY_HEIGHT + 128, true, false)
		Triggers.YELLOW_GUN:
			RotatingGun.make_gray(x + 64, y + 64, false)
		Triggers.STAR_BROWN:
			InvisibleStar.new(x + 32, y + 32, Star.TYPE_BROWN)
		Triggers.GRAY_TANK:
			GrayTank.new(x + 64, y + 64)
		Triggers.STAR_FLASHING:
			InvisibleStar.new(x + 32, y + 32, Star.TYPE_FLASHING)
		Triggers.AIRPLANE:
			Airplane.new(x + 60, y + 62)
		Triggers.GRAY_JEEP:
			GrayJeep.new(x + 32, y + 46)
		Triggers.PARKED_GRAY_JEEP:
			ParkedGrayJeep.new(x + 32, y + 46)
		Triggers.GRAY_BOAT:
			GrayBoat.new(x, y)
		Triggers.APPEARING_SOLDIER:
			AppearingSoldier.new(x + 32, y + 74)
		Triggers.APPEARING_BROWN_TANK:
			AppearingBrownTank.new(x + 8, y + 12)
		Triggers.SUBMARINE:
			Submarine.new(x + 32, y + 128)
		Triggers.TROOPS_TRUCK:
			TroopsTruck.new(x, y + 8)
		Triggers.FLOOR_GUN:
			FloorGun.new(x, y + 28, false)
		Triggers.SWAMP_MISSILE_LAUNCHER:
			SwampMissileLauncher.new(x, y)
		Triggers.ROCK:
			Rock.new(x + 32, y + 32)
		Triggers.CANNON_TRUCK_RIGHT:
			CannonTruck.new(x + 16, y, true)
		Triggers.MINE:
			Mine.new(x + 16, y)
		Triggers.CLIFF_MISSILE_LAUNCHER:
			CliffMissileLauncher.new(x + 16, y + 20)
		Triggers.TRAIN:
			TrainManager.new(x + 4, y)
		Triggers.CANNON_TRUCK_LEFT:
			CannonTruck.new(x + 16, y, false)
		Triggers.HOUSE_LEFT:
			House.new(x, y, true)
		Triggers.HOUSE_RIGHT:
			House.new(x, y, false)
		Triggers.HUT:
			Hut.new(x, y, false, false)
		Triggers.SHACK:
			Hut.new(x, y, true, false)
		Triggers.GATE:
			Gate.new(x, y)
		Triggers.TANK_SHACK:
			Hut.new(x, y, true, true)
		Triggers.CLIFF_GUN:
			CliffGun.new(x, y)
		Triggers.FIRE_TANK:
			FireTank.new(x + 64, y + 64)
		Triggers.SOLDIER_FIRE:
			EnemySoldier.new(x + 32, y + 74, EnemySoldierType.FIRE)
		Triggers.PARKED_BROWN_TANK:
			ParkedBrownTank.new(x + 32, y + 40)
		Triggers.PLAYER:
			_create_player(x + 48, y + 48)
			main.start_fade(false, null)
			match main.stage_index:
				3:
					main.request_song(main.stage_song0)
				1, 4:
					main.request_song(main.stage_song1)
				2, 5:
					main.request_song(main.stage_song2)
		Triggers.GREEN_GUN:
			RotatingGun.make_typed(x + 48, y + 44, RotatingGun.TYPE_GREEN)
		Triggers.APPEARING_PLANE:
			AppearingPlane.new(x + 60, y + 62)
		Triggers.ENEMY_HELICOPTER:
			EnemyHelicopter.new(true)
		Triggers.FLOOR_GUN_PLAIN:
			FloorGun.new(x, y + 28, true)
		Triggers.BROWN_GUN:
			RotatingGun.make_typed(x + 48, y + 44, RotatingGun.TYPE_BROWN)
		Triggers.APPEARING_ENEMY_HELICOPTER:
			AppearingEnemyHelicopter.new(y)
		Triggers.APPEARING_GRAY_JEEP:
			AppearingGrayJeep.new(x + 32, y + 46)
		Triggers.FLOOR_MISSILE_LAUNCHER:
			FloorMissileLauncher.new(x + 16, y + 8)
		Triggers.STATUE_NONE:
			Statue.new(x, y, Statue.TYPE_NONE)
		Triggers.STATUE_LEFT:
			Statue.new(x, y, Statue.TYPE_LEFT)
		Triggers.STATUE_RIGHT:
			Statue.new(x, y, Statue.TYPE_RIGHT)
		Triggers.COLUMN:
			Column.new(x, y)
		Triggers.LANDING_PORT_LEFT:
			LandingPort.new(x, y, LandingPort.TYPE_LEFT)
		Triggers.LANDING_PORT_RIGHT:
			LandingPort.new(x, y, LandingPort.TYPE_RIGHT)
		Triggers.LANDING_PORT_CIRCLE:
			LandingPort.new(x, y, LandingPort.TYPE_CIRCLE)
		Triggers.BOSS_BLUE_TANKS:
			BossBlueTanksManager.new()
			main.request_song(main.boss_song)
		Triggers.BOSS_STATUES:
			BossStatuesManager.new()
			main.request_song(main.boss_song)
		Triggers.LASER:
			LasersManager.new(x, y)
		Triggers.BOSS_SHIP:
			BossShipManager.new()
			main.request_song(main.boss_song)
		Triggers.BOSS_HELICOPTER:
			BossHelicopterManager.new()
			main.request_song(main.boss_song)
		Triggers.STAR_GREEN:
			InvisibleStar.new(x + 32, y + 32, Star.SPRITE_GREEN)
		Triggers.BOSS_GARAGE:
			BossGarageManager.new()
			main.request_song(main.boss_song)
		Triggers.BOSS_HEADQUARTERS:
			BossHeadquartersManager.new()
			main.request_song(main.boss_song)
		Triggers.CHINOOK:
			Chinook.new()
			if main.continued:
				main.request_song(main.stage_song0)
			main.start_fade(false, null)


func _create_player(x: float, y: float) -> void:
	camera_x = x - CAMERA_MARGIN_NORTH - 48
	if camera_x < 0:
		camera_x = 0
	player.x = x
	player.y = y
	player.make_invincible()


func is_missile_target(x: float, y: float) -> bool:
	var t := get_tile_type(x, y)
	return t == TYPE_SOLID or t == TYPE_SHIELD


func is_driveable_box(x1: float, y1: float, x2: float, y2: float) -> bool:
	return is_driveable(x1, y1) and is_driveable(x2, y2) \
		and is_driveable(x1, y2) and is_driveable(x2, y1)


func is_solid_tile(x: int, y: int) -> bool:
	return types_map[y][x] == TYPE_SOLID


func is_driveable(x: float, y: float) -> bool:
	var t := get_tile_type(x, y)
	return t == TYPE_EMPTY or t == TYPE_SWAMP or t == TYPE_CONVEYOR


func is_driveable_land(x: float, y: float) -> bool:
	var t := get_tile_type(x, y)
	return t == TYPE_EMPTY or t == TYPE_CONVEYOR


func is_solid(x: float, y: float) -> bool:
	return get_tile_type(x, y) == TYPE_SOLID


func is_empty(x: float, y: float) -> bool:
	return get_tile_type(x, y) == TYPE_EMPTY


func is_shield(x: float, y: float) -> bool:
	return get_tile_type(x, y) == TYPE_SHIELD


func is_water(x: float, y: float) -> bool:
	return get_tile_type(x, y) == TYPE_WATER


func is_swamp(x: float, y: float) -> bool:
	return get_tile_type(x, y) == TYPE_SWAMP


func is_conveyor(x: float, y: float) -> bool:
	return get_tile_type(x, y) == TYPE_CONVEYOR


func is_outside_of_frame(x: float, y: float) -> bool:
	return y > camera_y + Main.DISPLAY_HEIGHT or x < camera_x or y < camera_y \
		or x > camera_x + Main.DISPLAY_WIDTH


func is_outside_of_frame_rect(x1: float, y1: float, x2: float, y2: float) -> bool:
	return y1 > camera_y + Main.DISPLAY_HEIGHT or x2 < camera_x or y2 < camera_y \
		or x1 > camera_x + Main.DISPLAY_WIDTH


func distance_outside_of_frame(x: float, y: float) -> float:
	if y < camera_y:
		return camera_y - y
	if y > camera_y + Main.DISPLAY_HEIGHT:
		return y - (camera_y + Main.DISPLAY_HEIGHT)
	if x < camera_x:
		return camera_x - x
	if x > camera_x + Main.DISPLAY_WIDTH:
		return x - (camera_x + Main.DISPLAY_WIDTH)
	return 0.0


func audio_volume(x: float, y: float) -> float:
	var d := distance_outside_of_frame(x, y)
	if d == 0:
		return 1.0
	if d >= 256:
		return 0.0
	return 1.0 - d / 256.0


func destroy_all_except(except_enemy: Enemy) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e: Enemy = enemies[i]
		if e != except_enemy:
			e.explode()
	_flag_enemy_bullets(false)


func destroy_all() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		enemies[i].explode()
	_flag_enemy_bullets(true)


func destroy_all_within_frame() -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var e: Enemy = enemies[i]
		if not is_outside_of_frame_rect(e.x + e.hit_x1, e.y + e.hit_y1,
				e.x + e.hit_x2, e.y + e.hit_y2):
			e.explode()
	_flag_enemy_bullets(false)


# destroyAll() routes through remove() (which plays a sound); the other two
# variants set the flag directly. That difference is preserved.
func _flag_enemy_bullets(call_remove: bool) -> void:
	for i in range(7, -1, -1):
		var list: Array = elements[i]
		for j in range(list.size() - 1, -1, -1):
			var element: GameElement = list[j]
			if element.enemy_bullet:
				if call_remove:
					element.do_remove()
				else:
					element.remove = true


func get_tile_type(x: float, y: float) -> int:
	var X := int(x) >> 5
	var Y := int(y) >> 5
	if X < 0:
		X = 0
	elif X >= map_width:
		X = map_width - 1
	if Y < 0:
		Y = 0
	elif Y >= map_height:
		Y = map_height - 1
	return types_map[Y][X]


func add(element: GameElement) -> void:
	if element.enemy:
		var e: Enemy = element
		elements[e.layer].append(e)
		enemies.append(e)
		if e.solid:
			solids.append(e)
		if e.mine:
			mines.append(e)
	else:
		elements[element.layer].append(element)


func mark_stage_completed() -> void:
	stage_completed = true
	main.stop_song()


func fade_completed() -> void:
	if stage_index == 5:
		main.request_mode(Modes.SUNSET)
	else:
		CutsceneSequence.request_cutscene()


func update() -> void:
	if paused:
		if input.is_pause():
			paused = false
			main.set_music_on(true)
		return
	elif input.is_pause() and not stage_completed and playing and main.is_song_playing():
		paused = true
		main.play_sound(main.pause_sound)
		main.set_music_on(false)

	water_alpha_index += 1
	if water_alpha_index == WATER_ALPHAS_PERIOD:
		water_alpha_index = 0

	if stage_index == 5:
		conveyor_offset += CONVEYOR_SPEED
		if conveyor_offset >= 16:
			conveyor_offset -= 16
		var conveyor_index := int(conveyor_offset)
		conveyor_delta = conveyor_index - conveyor_last_index
		if conveyor_delta < 0:
			conveyor_delta += 16
		tiles[0] = main.conveyors[conveyor_index]
		conveyor_last_index = conveyor_index

	if boss_camera_pan and camera_y != 0:
		camera_y -= BOSS_PAN_CAMERA_SPEED
		if camera_y <= 0:
			camera_y = 0
			max_camera_y = 0
			boss_camera_pan = false
			camera_pan_listener.pan_complete()
		else:
			return

	if ending_camera_pan:
		if camera_x > 512:
			camera_x -= ENDING_PAN_CAMERA_SPEED
			if camera_x <= 512:
				camera_x = 512
				ending_camera_pan = false
				camera_pan_listener.pan_complete()
			else:
				return
		else:
			camera_x += ENDING_PAN_CAMERA_SPEED
			if camera_x >= 512:
				camera_x = 512
				ending_camera_pan = false
				camera_pan_listener.pan_complete()
			else:
				return

	_process_triggers()

	var max_bound_y := max_camera_y + REMOVE_BOUND

	for i in range(7, -1, -1):
		var list: Array = elements[i]
		for j in range(list.size() - 1, -1, -1):
			var element: GameElement = list[j]
			if not element.remove:
				element.check_bounds(max_bound_y)
			if not element.remove:
				element.update()
				if element.change_layer_to >= 0:
					if element.layer != element.change_layer_to:
						element.layer = element.change_layer_to
						list.remove_at(j)
						elements[element.layer].append(element)
					element.change_layer_to = -1
			if element.remove:
				list.remove_at(j)
				if element.enemy:
					var e: Enemy = element
					enemies.erase(e)
					if e.solid:
						solids.erase(e)
					if e.mine:
						mines.erase(e)

	if playing:
		player.update()
		_camera_track_player()

	if stage_completed:
		stage_completed_delay -= 1
		if stage_completed_delay == 0:
			main.start_fade(true, self)


func _draw_background() -> void:
	var x_offset := fmod(camera_x, 32.0)
	var y_offset := fmod(camera_y, 32.0)
	var x_tile := int(camera_x / 32.0)
	var y_tile := int(camera_y / 32.0)
	var x_start := 31 if 32 + x_tile == map_width else 32

	if stage_index > 0:
		if stage_index == 2:
			# Stage 2 cross-fades two water tile sets underneath the terrain.
			# Only tiles 0..3 carry the animated alpha, as in the original.
			for i in 4:
				tiles[i].alpha = WATER_ALPHAS[water_alpha_index]
			for y in range(30, -1, -1):
				var Y := float(y << 5) - y_offset
				var row: PackedInt32Array = tile_map[y + y_tile]
				for x in range(x_start, -1, -1):
					var tile := row[x + x_tile]
					var X := float(x << 5) - x_offset
					if tile < 32:
						var water := (((y + y_tile) & 1) << 1) + ((x + x_tile) & 1)
						main.draw(tiles[water + 4], X, Y)
						main.draw(tiles[water], X, Y)
					if tile < 225:
						main.draw(tiles[tile], X, Y)
		else:
			for y in range(30, -1, -1):
				var Y := float(y << 5) - y_offset
				var row: PackedInt32Array = tile_map[y + y_tile]
				for x in range(x_start, -1, -1):
					var tile := row[x + x_tile]
					if tile < 225:
						main.draw(tiles[tile], float(x << 5) - x_offset, Y)

		# Tiles from sheet 6 sit on top of everything else in the background.
		for y in range(30, -1, -1):
			var Y := float(y << 5) - y_offset
			var row: PackedInt32Array = tile_map[y + y_tile]
			for x in range(x_start, -1, -1):
				var tile := row[x + x_tile]
				if tile >= 225:
					main.draw(tiles[tile], float(x << 5) - x_offset, Y)
	else:
		for y in range(30, -1, -1):
			var Y := float(y << 5) - y_offset
			var row: PackedInt32Array = tile_map[y + y_tile]
			for x in range(x_start, -1, -1):
				main.draw(tiles[row[x + x_tile]], float(x << 5) - x_offset, Y)


func _draw_sprites() -> void:
	main.translate_graphics(-camera_x, -camera_y)

	for i in 4:
		var list: Array = elements[i]
		for j in range(list.size() - 1, -1, -1):
			var element: GameElement = list[j]
			if not element.remove:
				element.render()

	player.render()

	for i in range(4, 8):
		var list: Array = elements[i]
		for j in range(list.size() - 1, -1, -1):
			var element: GameElement = list[j]
			if not element.remove:
				element.render()

	main.pop_graphics()


func _draw_score() -> void:
	main.draw_text("1P", 64, 804, Main.FONT_WHITE)
	main.draw_text(main.score_str, 160, 804, Main.FONT_WHITE)
	main.draw_text("P", 176, 868, Main.FONT_WHITE)
	main.draw_text(main.extra_lives_str, 216, 868, Main.FONT_WHITE)


func render() -> void:
	_draw_background()
	_draw_sprites()
	if playing:
		_draw_score()
