# Port of jackal.TroopsTruck: waits for the player, drives across, then unloads
# soldiers one at a time.
class_name TroopsTruck
extends Enemy

const STATE_PAUSED := 0
const STATE_MOVING := 1
const STATE_RELEASING_TROOPS := 2

const SPEED := 1.25
const TRAVEL_TIME := 291
const PLAYER_DISTANCE := 256.0
const TROOPS := 12
const TROOPS_DELAY := 2 * 91

var state: int = STATE_PAUSED
var player: Player
var traveling: int = TRAVEL_TIME
var troops: int = TROOPS
var troops_delay: int


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	player = game_mode.player

	layer = 4

	bullet_hits = 4

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 120
	hit_y2 = 76

	mine = true
	mine_x1 = 8
	mine_y1 = 8
	mine_x2 = 120
	mine_y2 = 76

	solid = true
	solid_x1 = 0
	solid_y1 = 0
	solid_x2 = 128
	solid_y2 = 84

	points = 1000

	explosion_x = 64
	explosion_y = 42


func update() -> void:
	match state:
		STATE_PAUSED:
			if player.y - y <= PLAYER_DISTANCE:
				state = STATE_MOVING
		STATE_MOVING:
			x += SPEED
			traveling -= 1
			if traveling == 0:
				state = STATE_RELEASING_TROOPS
		STATE_RELEASING_TROOPS:
			troops_delay -= 1
			if troops_delay < 0:
				troops_delay = TROOPS_DELAY
				if troops > 0:
					troops -= 1
					EnemySoldier.new(x + 16, y + 66, EnemySoldierType.TROOPS_TRUCK)


func render() -> void:
	main.draw(main.troops_truck, x, y)
