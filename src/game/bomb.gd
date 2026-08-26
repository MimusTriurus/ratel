# Port of jackal.Bomb.
#
# Thrown at where the player is now (plus a little error); like the grenade it
# flies straight and fakes its height with scale. It only becomes lethal in the
# last two ticks before it lands.
class_name Bomb
extends Enemy

const CLOSE_MARGIN := 128.0
const DISTANCE := 160.0
const MIN_SCALE := 32.0 / 44.0
const TRAVEL_TIME := 114
const HALF_TIME := TRAVEL_TIME / 2
const GRAVITY := -2.0 * (1.0 - MIN_SCALE) / float(HALF_TIME * HALF_TIME)
const HALF_GRAVITY2 := (MIN_SCALE - 1.0) / float(TRAVEL_TIME * TRAVEL_TIME)
const VELOCITY := DISTANCE / TRAVEL_TIME
const HALF_GRAVITY := GRAVITY / 2.0
const V0 := -GRAVITY * HALF_TIME
const ANGULAR_VELOCITY := 5.0
const ERROR := 64.0

var vx: float
var vy: float
var scale: float
var angle: float
var t: int
var airplane: bool


func _init(p_x: float, p_y: float, p_airplane: bool, p_vx: float = 0.0,
		p_vy: float = 0.0) -> void:
	super()
	x = p_x
	y = p_y
	airplane = p_airplane

	vx = (game_mode.player.x + main.random.randf() * ERROR - ERROR) - p_x
	vy = (game_mode.player.y + main.random.randf() * ERROR - ERROR) - p_y
	var imag := (VELOCITY if p_airplane else 0.75 * VELOCITY) \
		/ sqrt(vx * vx + vy * vy)
	vx *= imag
	vy *= imag

	# A bomb dropped by a moving jeep inherits part of its velocity.
	vx += p_vx
	vy += p_vy

	angle = main.random.randi_range(0, 3) * 90

	if p_airplane or _is_close_to_frame():
		main.play_sound(main.throw_sound)


func _is_close_to_frame() -> bool:
	var X := x - game_mode.camera_x
	var Y := y - game_mode.camera_y
	return X >= -CLOSE_MARGIN and X <= Main.DISPLAY_WIDTH + CLOSE_MARGIN \
		and Y >= -CLOSE_MARGIN and Y <= Main.DISPLAY_HEIGHT + CLOSE_MARGIN


func init() -> void:
	super.init()

	layer = 5

	hit_x1 = -19
	hit_y1 = -19
	hit_x2 = 19
	hit_y2 = 19

	mine = true
	mine_x1 = -19
	mine_y1 = -19
	mine_x2 = 19
	mine_y2 = 19


func do_remove() -> void:
	remove = true
	if not game_mode.is_outside_of_frame(x, y) and play_sound_on_remove:
		main.play_explode_sound2()


func update() -> void:
	x += vx
	y += vy
	if airplane:
		scale = 1.0 + HALF_GRAVITY2 * t * t
	else:
		scale = MIN_SCALE + t * (V0 + HALF_GRAVITY * t)
	angle += ANGULAR_VELOCITY

	t += 1
	if t > TRAVEL_TIME:
		do_remove()
		var e := Explosion.new(x, y)
		e.set_damages_enemies(false)


func attack(_x1: float, _y1: float, _x2: float, _y2: float,
		_attack_source: int) -> bool:
	return false


func bullet_attack(_x1: float, _y1: float, _x2: float, _y2: float) -> bool:
	return false


func bump(x1: float, y1: float, x2: float, y2: float, invincible: bool) -> bool:
	if t < TRAVEL_TIME - 2 or invincible:
		return false
	if is_mine_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x, y)
		main.add_points(points)
		return true
	return false


func render() -> void:
	main.draw_angle_scale(main.bomb, x, y, angle, scale)
