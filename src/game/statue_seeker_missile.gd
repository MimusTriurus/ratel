# Port of jackal.StatueSeekerMissile: the boss statue's homing missile.
class_name StatueSeekerMissile
extends Enemy

const ROTATION_SPEED := 0.9
const EXPLODE_DELAY := 8 * 91
const SPEED := 3.5
const TO_RADIANS := PI / 180.0
const EXPLODE_OFFSET := 18.0 / SPEED
const ENTRY_DELAY := 16

var vx: float
var vy: float
var angle: float = 90
var sprite: Spr
var statue_x: float
var statue_y: float
var clip_x: float
var explode_delay: int
var player: Player
var entry_delay: int = ENTRY_DELAY


func _init(p_statue_x: float, p_statue_y: float) -> void:
	super()
	statue_x = p_statue_x
	statue_y = p_statue_y

	player = game_mode.player

	x = p_statue_x + 48
	y = p_statue_y + 86
	vx = 0
	vy = SPEED

	sprite = main.statue_missiles[0]


func init() -> void:
	super.init()

	layer = 4

	bullet_hits = 1

	hit_x1 = -22
	hit_y1 = -22
	hit_x2 = 22
	hit_y2 = 22

	mine = true
	mine_x1 = -8
	mine_y1 = -8
	mine_x2 = 8
	mine_y2 = 8


func do_remove() -> void:
	remove = true
	if play_sound_on_remove:
		main.play_explode_sound2()


func attack(x1: float, y1: float, x2: float, y2: float,
		attack_source: int) -> bool:
	if attack_source < AttackSource.PLAYER_EXPLOSION and hit_rect(x1, y1, x2, y2):
		play_sound_on_remove = false
		do_remove()
		main.play_hit_explode_sound()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


func update() -> void:
	if entry_delay > 0:
		entry_delay -= 1
		y += SPEED
	else:
		var target_angle := rad_to_deg(atan2(player.y - y, player.x - x))
		var delta_angle := fmod(target_angle - angle + 180, 360.0)
		if delta_angle < 0:
			delta_angle += 180
		else:
			delta_angle -= 180
		if absf(delta_angle) < ROTATION_SPEED:
			angle = target_angle
		elif delta_angle < 0:
			angle -= ROTATION_SPEED
		else:
			angle += ROTATION_SPEED

		var ang := TO_RADIANS * angle
		vx = SPEED * cos(ang)
		vy = SPEED * sin(ang)
		x += vx
		y += vy

	explode_delay += 1
	if explode_delay == EXPLODE_DELAY:
		play_sound_on_remove = false
		if not game_mode.is_outside_of_frame(x, y):
			main.play_explode_sound2()
		do_remove()
		var e := Explosion.new(x + EXPLODE_OFFSET * vx, y + EXPLODE_OFFSET * vy)
		e.set_tiny(true)


func render() -> void:
	if entry_delay > 0:
		main.set_clip(statue_x + 24, statue_y + 100, 48, 96)
		main.draw_rotated(sprite, x, y, angle)
		main.clear_clip()
	else:
		main.draw_rotated(sprite, x, y, angle)
