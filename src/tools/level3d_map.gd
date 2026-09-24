# The game's own map of stage 1 laid over the 3D preview: stage-0.json's
# collision grid, dirs-0.dat's flow field and the triggers, in the game's
# pixels, and the transform between those pixels and level metres.
#
# Nothing here is part of the game. The level was modelled from screenshots,
# not from the map, but it lines up with it: the fifteen bunkers and nine
# buildings (huts, houses, gate, landing port) sit where their triggers put
# them to 11 cm rms, 47 cm at worst, on one scale for both axes --
#
#     level x = PX * map x + ORIGIN.x      level z = PX * map y + ORIGIN.y
#
# with PX 1.465 cm, 68.25 map pixels to the metre, which makes the map's 2048 px
# the level's 30 m of land from x = -15. And the grid agrees with the ground:
# 99.5% of the tiles the game lets a soldier walk on are ground in the level
# (the rest forest edge, walls and trunks), and its forest is the level's. So what walks here walks by the game's
# rules on the game's grid -- GameMode.is_driveable, suggest_direction --
# and the level is only where it is drawn. The grid is the game's as it plays,
# not only as it is stored: the POW buildings' footprints are solid until
# they are blown open, and then their destruction groups rewrite them.
#
# PX is also the scale every game distance is converted by, so that a round's
# reach and a gun's spacing agree. The BTR was sized otherwise, to the jeep
# (level3d_btr.gd), because the level's buildings are drawn larger than the
# game's.
class_name Level3DMap
extends RefCounted

const STAGE := 0
const PX := 0.014651
const ORIGIN := Vector2(-15.0121, -135.0312)

var stage := Stage.new()
# The POW buildings of the stage, as Hut and House find them: {"type" (the
# Triggers constant), "x", "y" (map px, the trigger's corner), "group" (the
# destruction group they rewrite)}.
var buildings: Array = []
# The gate's destruction group, as Gate finds it, or -1.
var gate_group := -1
var _pristine: Array = []
var _triggered := {}


func _init() -> void:
	MapIO.load_stage(STAGE, stage, MapIO.load_trigger_sizes())
	FlowField.load_into(STAGE, stage)
	for row in stage.types_map:
		_pristine.append((row as PackedInt32Array).duplicate())
	for row in stage.trigger_map[0]:
		for t in row:
			match t[0]:
				Triggers.GATE:
					gate_group = stage.groups_map[t[2] >> 5][(t[1] >> 5) + 1]
				Triggers.HUT:
					buildings.append({"type": t[0], "x": t[1], "y": t[2],
							"group": stage.groups_map[(t[2] >> 5) + 1][(t[1] >> 5) + 1]})
				Triggers.HOUSE_LEFT, Triggers.HOUSE_RIGHT:
					var left: bool = t[0] == Triggers.HOUSE_LEFT
					buildings.append({"type": t[0], "x": t[1], "y": t[2],
							"group": stage.groups_map[(t[2] >> 5) + 2][(t[1] >> 5) + (0 if left else 5)]})
	reset()


# The map as the stage starts it. Hut and House make their footprints solid
# when they are spawned -- 6 x 5 tiles and 6 x 6 -- and here that is done for
# all of them at once; before its trigger fires the ground under a hut is
# water, which stops the same walkers and fewer rounds.
func reset() -> void:
	for y in stage.types_map.size():
		stage.types_map[y] = (_pristine[y] as PackedInt32Array).duplicate()
	_triggered.clear()
	for b in buildings:
		var X: int = b.x >> 5
		var Y: int = b.y >> 5
		for i in (5 if b.type == Triggers.HUT else 6):
			for j in 6:
				stage.types_map[Y + i][X + j] = MapIO.TYPE_SOLID


# GameMode.trigger_group: the building is down, and its cells become what the
# group says -- the ruin's ground, walkable again.
func trigger_group(index: int) -> void:
	if _triggered.has(index):
		return
	_triggered[index] = true
	for g in stage.groups[index]:
		stage.types_map[g[1]][g[0]] = g[3]


static func to_level(p: Vector2) -> Vector2:
	return ORIGIN + p * PX


static func to_map(v: Vector2) -> Vector2:
	return (v - ORIGIN) / PX


# GameMode.get_tile_type.
func tile_type(x: float, y: float) -> int:
	var tx := clampi(int(x) >> 5, 0, stage.map_width - 1)
	var ty := clampi(int(y) >> 5, 0, stage.map_height - 1)
	return stage.types_map[ty][tx]


func is_driveable(x: float, y: float) -> bool:
	return FlowField.DRIVABLE.has(tile_type(x, y))


func is_driveable_box(x1: float, y1: float, x2: float, y2: float) -> bool:
	return is_driveable(x1, y1) and is_driveable(x2, y2) \
		and is_driveable(x1, y2) and is_driveable(x2, y1)


# GameMode.is_driveable_land: what a tank's sensor will drive on -- not swamp.
func is_driveable_land(x: float, y: float) -> bool:
	var t := tile_type(x, y)
	return t == MapIO.TYPE_EMPTY or t == MapIO.TYPE_CONVEYOR


func is_solid(x: float, y: float) -> bool:
	return tile_type(x, y) == MapIO.TYPE_SOLID


func is_swamp(x: float, y: float) -> bool:
	return tile_type(x, y) == MapIO.TYPE_SWAMP


# GameMode._lookup_direction: the flow field's step from x1, y1 towards x2, y2.
func lookup_direction(x1: float, y1: float, x2: float, y2: float) -> int:
	var w := stage.directions_width
	var h := stage.directions_height
	var X1 := int(x1) >> 7
	var Y1 := int(y1) >> 7
	var X2 := int(x2) >> 7
	var Y2 := int(y2) >> 7
	if X1 < 0 or Y1 < 0 or X1 >= w or Y1 >= h or X2 < 0 or Y2 < 0 or X2 >= w or Y2 >= h:
		return -1
	var i := (((Y1 << 4) + X1) << 4) * h + ((Y2 << 4) + X2)
	var index := i / 21
	if index < 0 or index >= stage.directions.size():
		return -1
	return int((stage.directions[index] >> (3 * (i % 21))) & 7)


# GameMode.suggest_direction with add_randomness, the soldier's call: a unit
# vector in map axes.
func suggest_direction(x1: float, y1: float, x2: float, y2: float, rng: RandomNumberGenerator) -> Vector2:
	var d := lookup_direction(x1, y1, x2, y2)
	if d < 0:
		return straight_direction(x1, y1, x2, y2)
	var angle: float = GameMode.DIRECTION_RADIANS[d] + (rng.randf() - 0.5) * 0.7854
	return Vector2(cos(angle), sin(angle))


# GameMode.suggest_direction without randomness, the tank's call: the flow
# field's step as Main.create_unit_vector has it, and its angle in degrees, in
# a Vector3 (x, y, angle).
func suggest_direction_exact(x1: float, y1: float, x2: float, y2: float) -> Vector3:
	var d := lookup_direction(x1, y1, x2, y2)
	var angle: int
	if d < 0:
		var a := rad_to_deg(atan2(y2 - y1, x2 - x1))
		if a < 0:
			a += 360
		angle = 45 * int(round(a / 45.0)) % 360
	else:
		angle = GameMode.DIRECTION_DEGREES[d]
	var v := unit_vector(angle)
	return Vector3(v.x, v.y, angle)


# GameMode.suggest_direction_turning without randomness, the boss tank's call:
# not the flow field's step itself but a turn of 45 degrees from `current`
# towards it, so that a run never turns it further than that. Off the field
# it is GameMode.straight_direction, whose angle can come out as 360.
func suggest_direction_turning(x1: float, y1: float, x2: float, y2: float, current: int) -> Vector3:
	var d := lookup_direction(x1, y1, x2, y2)
	if d < 0:
		var a := rad_to_deg(atan2(y2 - y1, x2 - x1))
		if a < 0:
			a += 360
		var ang := 45 * int(round(a / 45.0))
		var s := unit_vector(ang)
		return Vector3(s.x, s.y, ang)
	var target: int = GameMode.DIRECTION_DEGREES[d]
	var delta := (target - current + 180) % 360
	if delta < 0:
		delta += 180
	else:
		delta -= 180
	if delta != 0:
		current += -45 if delta < 0 else 45
		if current < 0:
			current += 360
		elif current >= 360:
			current -= 360
	var v := unit_vector(current)
	return Vector3(v.x, v.y, current)


# Main.create_unit_vector, the exact table for multiples of 45 degrees.
static func unit_vector(angle: int) -> Vector2:
	var s := Main.ISQRT2
	match posmod(angle, 360):
		0: return Vector2(1, 0)
		45: return Vector2(s, s)
		90: return Vector2(0, 1)
		135: return Vector2(-s, s)
		180: return Vector2(-1, 0)
		225: return Vector2(-s, -s)
		270: return Vector2(0, -1)
		_: return Vector2(s, -s)


# GameMode.straight_direction: towards the target, to the nearest 45 degrees.
static func straight_direction(x1: float, y1: float, x2: float, y2: float) -> Vector2:
	var angle := rad_to_deg(atan2(y2 - y1, x2 - x1))
	if angle < 0:
		angle += 360
	var a := deg_to_rad(45 * int(round(angle / 45.0)))
	return Vector2(cos(a), sin(a))


# GameMode.suggest_direction_bounce: off a barrier at a right angle or a
# little more, turning the way that keeps going forward.
static func suggest_direction_bounce(vx: float, vy: float, rng: RandomNumberGenerator) -> Vector2:
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
	var angle := 1.571 + 0.4 * rng.randf()
	return Vector2(vx, vy).rotated(angle if clockwise else -angle)
