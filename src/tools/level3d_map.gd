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
# and the level is only where it is drawn.
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


func _init() -> void:
	MapIO.load_stage(STAGE, stage, MapIO.load_trigger_sizes())
	FlowField.load_into(STAGE, stage)


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
