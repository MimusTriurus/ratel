# Port of jackal.BossGarage.
#
# A garage door that rolls up, lets a tank drive out (drawn fading in behind
# the doorway) and closes again. It can only be destroyed while open.
class_name BossGarage
extends Enemy

const STATE_CLOSED := 0
const STATE_OPENING := 1
const STATE_CLOSING := 2
const STATE_OPEN := 3
const STATE_OPEN_2 := 4
const STATE_OPEN_3 := 5

const OPENING_SPEED := 2.0
const OPEN_3_PAUSE := 136

var boss_garage_manager = null
var light_index: int = 3
var state: int = STATE_CLOSED
var door_y: float
var is_brown_tank: bool
var vehicle: Array[Spr]
var vehicle_y: float
var brown_tank: BrownTank
var gray_tank: GrayTank
var delay: int
var group_index: int


func _init(p_x: float, p_y: float, p_manager) -> void:
	super()
	x = p_x
	y = p_y
	boss_garage_manager = p_manager

	group_index = game_mode.groups_map[int(p_y) >> 5][int(p_x) >> 5]


func init() -> void:
	super.init()

	layer = 0

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 120
	hit_y2 = 88

	explosion_x = 64
	explosion_y = 48


func update() -> void:
	match state:
		STATE_OPENING:
			door_y += OPENING_SPEED
			if door_y >= 96:
				# With the arena already full of tanks, just hold the door open.
				if boss_garage_manager.full():
					state = STATE_OPEN_3
					delay = OPEN_3_PAUSE
				else:
					state = STATE_OPEN
		STATE_OPEN:
			if is_brown_tank:
				vehicle_y += BrownTank.SPEED
				if vehicle_y > y + 72:
					brown_tank = BrownTank.from_garage_tracked(x + 64, vehicle_y,
						125, boss_garage_manager)
					state = STATE_OPEN_2
			else:
				vehicle_y += GrayTank.SPEED
				if vehicle_y > y + 80:
					gray_tank = GrayTank.from_garage_tracked(x + 64, vehicle_y,
						125, boss_garage_manager)
					state = STATE_OPEN_2
		STATE_OPEN_2:
			if is_brown_tank:
				if brown_tank.y > y + 138 or brown_tank.remove:
					brown_tank = null
					state = STATE_CLOSING
			else:
				if gray_tank.y > y + 148 or gray_tank.remove:
					gray_tank = null
					state = STATE_CLOSING
		STATE_CLOSING:
			door_y -= OPENING_SPEED
			if door_y <= 0:
				state = STATE_CLOSED
		STATE_OPEN_3:
			delay -= 1
			if delay == 0:
				state = STATE_CLOSING


func open() -> void:
	if state != STATE_CLOSED:
		return
	state = STATE_OPENING
	is_brown_tank = main.random.randi_range(0, 1) == 0
	if is_brown_tank:
		vehicle = main.brown_tanks
		vehicle_y = y - 8
	else:
		vehicle = main.gray_tanks
		vehicle_y = y - 24


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if state >= STATE_OPEN and attack_source == AttackSource.PLAYER_WEAPON \
			and hit_rect(x1, y1, x2, y2):
		do_remove()
		if state == STATE_OPEN:
			Explosion.new(x + 64, vehicle_y)
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		boss_garage_manager.garage_destroyed()
		game_mode.trigger_group(group_index)
		return true
	return false


func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	return hit_rect(x1, y1, x2, y2)


func render() -> void:
	if state == STATE_CLOSED:
		main.draw(main.garages[0], x, y)
		return

	light_index -= 1
	if light_index == 0:
		light_index = 3

	main.draw(main.garages[1], x, y)
	if state == STATE_OPEN:
		# The emerging tank fades in as it clears the doorway.
		main.set_clip(x - 1, y, 130, 256)
		var alpha: float = (vehicle_y - (y - 8)) * 0.0125 if is_brown_tank \
			else (vehicle_y - (y - 24)) * 0.0096154
		main.draw_vehicle(vehicle, x + 64, vehicle_y, 90, alpha)
		main.clear_clip()
	main.draw(main.garages[4], x, y)
	if light_index > 1:
		main.draw(main.garages[light_index], x + 46, y - 4)

	if state == STATE_OPENING or state == STATE_CLOSING:
		main.set_clip(x - 1, y, 130, 256)
		main.draw(main.garages[0], x, y - door_y)
		main.clear_clip()
