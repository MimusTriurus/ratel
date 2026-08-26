# Port of jackal.SwampMissile: rises out of its launcher, then homes on the
# player at a limited turn rate until it times out.
class_name SwampMissile
extends Enemy

const ROTATION_SPEED := 0.9
const EXPLODE_DELAY := 8 * 91
const SPEED := 4.0
const TO_RADIANS := PI / 180.0
const EXPLODE_OFFSET := 21.0 / SPEED
const ENTRY_DELAY := 45
const REMOVE_MARGIN := 336.0

var vx: float
var vy: float
var angle: float = 270
var launcher_x: float
var launcher_y: float
var clip_x: float
var explode_delay: int
var player: Player
var entry_delay: int = ENTRY_DELAY


func _init(p_launcher_x: float, p_launcher_y: float) -> void:
	super()
	launcher_x = p_launcher_x
	launcher_y = p_launcher_y

	player = game_mode.player

	x = p_launcher_x
	y = p_launcher_y + 32
	vx = 0
	vy = -SPEED


func init() -> void:
	super.init()

	layer = 4

	bullet_hits = 1

	hit_x1 = -26
	hit_y1 = -26
	hit_x2 = 26
	hit_y2 = 26

	mine = true
	mine_x1 = -8
	mine_y1 = -8
	mine_x2 = 8
	mine_y2 = 8


func update() -> void:
	if entry_delay > 0:
		entry_delay -= 1
		y -= SPEED
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

	if y < game_mode.camera_y - REMOVE_MARGIN \
			or y > game_mode.camera_y + Main.DISPLAY_HEIGHT + REMOVE_MARGIN \
			or x < game_mode.camera_x - REMOVE_MARGIN \
			or x > game_mode.camera_x + Main.DISPLAY_WIDTH + REMOVE_MARGIN:
		play_sound_on_remove = false
		do_remove()
		return

	explode_delay += 1
	if explode_delay == EXPLODE_DELAY:
		do_remove()
		var e := Explosion.new(x + EXPLODE_OFFSET * vx, y + EXPLODE_OFFSET * vy)
		e.set_tiny(true)


func render() -> void:
	# While emerging, only the part above the launcher mouth is visible.
	if entry_delay > 0:
		main.set_clip(launcher_x - 20, launcher_y - 256, 40, 256)
		main.draw_rotated(main.swamp_missiles[0], x, y, angle)
		main.clear_clip()
	else:
		main.draw_rotated(main.swamp_missiles[0], x, y, angle)
