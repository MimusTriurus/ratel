# Port of jackal.Airplane: strafes down (or up) the screen dropping bombs.
class_name Airplane
extends Enemy

const SPEED := 5.0
const BOMB_DELAY := 68
const APPEAR_DISTANCE := 192.0

var bomb_delay: int
var up: bool
var orientation_index: int


# Enters on a random side of the player, nudged inwards if that would put it
# off-screen.
func _init(_p_x: float, p_y: float) -> void:
	super()
	x = game_mode.player.x \
		+ (-APPEAR_DISTANCE if main.random.randi_range(0, 1) == 0 else APPEAR_DISTANCE)
	if x - 96 < game_mode.camera_x:
		x = game_mode.player.x + APPEAR_DISTANCE
	elif x + 96 > game_mode.camera_x + Main.SCREEN_WIDTH:
		x = game_mode.player.x - APPEAR_DISTANCE
	y = p_y


static func from_landing_port(left_landing_port: bool) -> Airplane:
	var a := Airplane.new(0, 0)
	a.x = Main.game_mode.player.x \
		+ (-APPEAR_DISTANCE if left_landing_port else APPEAR_DISTANCE)
	a.y = Main.game_mode.camera_y - 124
	return a


static func upward(p_x: float, p_y: float) -> Airplane:
	var a := Airplane.new(p_x, p_y)
	a.up = true
	a.orientation_index = 1
	return a


func init() -> void:
	super.init()

	layer = 7

	hit_x1 = -40
	hit_y1 = -40
	hit_x2 = 40
	hit_y2 = 40

	points = 1000


func do_remove() -> void:
	remove = true
	if play_sound_on_remove:
		main.play_hit_explode_sound()
	main.stop_sound(main.plane_sound)


func update() -> void:
	main.play_sound_if_not_playing(main.plane_sound)

	if up:
		y -= SPEED
		if y < game_mode.camera_y - 384:
			play_sound_on_remove = false
			do_remove()
	else:
		y += SPEED

	bomb_delay -= 1
	if bomb_delay < 0:
		bomb_delay = BOMB_DELAY
		Bomb.new(x, y, true)


func bump(_x1: float, _y1: float, _x2: float, _y2: float,
		_invincible: bool) -> bool:
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func render() -> void:
	main.draw(main.airplanes[orientation_index][1], x + 24, y + 24)
	main.draw(main.airplanes[orientation_index][0], x - 60, y - 62)
