# Port of jackal.Train: one car of the armoured train. Cars run up a fixed
# track, crush anything on the rails and disappear into the tunnel.
class_name Train
extends Enemy

const SPEED := 3.5
const SHOOT_DELAY := 3 * 91
const BULLET_SPEED := 1.5
const BULLET_TRAVEL_TIME := 4 * 91

var mines: Array[Enemy]
var player: Player
var car_index: int
var shoot_delay: int
var shoot_x: float
var shoot_y: float


func _init(p_x: float, p_y: float, locomotive: bool) -> void:
	super()
	x = p_x
	y = p_y
	car_index = 0 if locomotive else 1
	shoot_x = 28 if locomotive else 24
	shoot_y = 64
	shoot_delay = main.random.randi_range(0, SHOOT_DELAY - 1)


func init() -> void:
	super.init()

	mines = game_mode.mines
	player = game_mode.player

	layer = 3

	bullet_hits = 4

	hit_x1 = 8
	hit_y1 = 8
	hit_x2 = 48 if car_index == 0 else 40
	hit_y2 = 120

	mine = true
	mine_x1 = 8
	mine_y1 = 8
	mine_x2 = 48 if car_index == 0 else 40
	mine_y2 = 120

	solid = true
	solid_x1 = 0
	solid_y1 = 0
	solid_x2 = 56 if car_index == 0 else 48
	solid_y2 = 128

	points = 1500 if car_index == 0 else 1200

	explosion_x = 28 if car_index == 0 else 24
	explosion_y = 64


func check_bounds(_max_y: float) -> void:
	pass


func flatten() -> void:
	pass


func update() -> void:
	y -= SPEED
	if y < 3104:
		play_sound_on_remove = false
		do_remove()
		return

	if y > 3296:
		shoot_delay -= 1
		if shoot_delay <= 0:
			shoot_delay = SHOOT_DELAY
			EnemyBullet.new(x + shoot_x, y + shoot_y,
				BULLET_SPEED if player.x > x else -BULLET_SPEED, 0,
				BULLET_TRAVEL_TIME, EnemyBullet.SPRITE_YELLOW)

	for i in range(mines.size() - 1, -1, -1):
		var m: Enemy = mines[i]
		if m != self and m.is_mine_rect(x + mine_x1, y + mine_y1,
				x + mine_x2, y + mine_y2):
			m.flatten()


func render() -> void:
	# Once a car reaches the tunnel mouth it is clipped and the tunnel is
	# redrawn on top of it.
	if y <= 3296:
		main.set_clip(384, 3248, 64, 192)
		main.draw(main.trains[car_index], x, y)
		main.draw(main.trains[2], 384, 3232)
		main.clear_clip()
	else:
		main.draw(main.trains[car_index], x, y)
