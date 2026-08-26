# Port of jackal.StatueMissile: flies out of the statue's mouth at 45 degrees,
# clipped to the mouth opening until it has cleared it.
class_name StatueMissile
extends Enemy

const EXPLODE_DELAY := 91
const SPEED := 3.5

var vx: float
var angle: float
var sprite: Spr
var statue_x: float
var statue_y: float
var right: bool
var clip_x: float
var explode_delay: int


func _init(p_statue_x: float, p_statue_y: float, p_right: bool) -> void:
	super()
	statue_x = p_statue_x
	statue_y = p_statue_y
	right = p_right

	x = p_statue_x + 48
	y = p_statue_y + 86

	if p_right:
		x -= 26
		vx = SPEED
		angle = 45
		sprite = main.statue_missiles[0]
		clip_x = p_statue_x + 74
	else:
		x += 26
		vx = -SPEED
		angle = 315
		sprite = main.statue_missiles[1]
		clip_x = p_statue_x - 22


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


func update() -> void:
	x += vx
	y += SPEED

	explode_delay += 1
	if explode_delay == EXPLODE_DELAY:
		play_sound_on_remove = false
		if not game_mode.is_outside_of_frame(x, y):
			main.play_explode_sound2()
		do_remove()
		var e := Explosion.new(x + (18 if right else -18), y + 18)
		e.set_tiny(true)


func render() -> void:
	var cleared := x > clip_x if right else x < clip_x
	if cleared:
		main.draw_rotated(sprite, x, y, angle)
		return
	if right:
		main.set_clip(statue_x + 46, statue_y, 52, 192)
	else:
		main.set_clip(statue_x - 30, statue_y, 80, 192)
	main.draw_rotated(sprite, x, y, angle)
	main.clear_clip()
