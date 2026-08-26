# Port of jackal.PlayerBullet.
class_name PlayerBullet
extends GameElement

const DISTANCE := 360.0
const TRAVEL_TIME := 20
const VELOCITY := DISTANCE / TRAVEL_TIME
const MARGIN := 16.0

var t: int
var enemies: Array[Enemy]


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y
	enemies = game_mode.enemies


func init() -> void:
	layer = 4
	main.play_sound_always(main.machine_gun_sound)


func update() -> void:
	y -= VELOCITY

	var did_hit := false
	var x1 := x - MARGIN
	var y1 := y - MARGIN
	var x2 := x + MARGIN
	var y2 := y + MARGIN
	for i in range(enemies.size() - 1, -1, -1):
		var e: Enemy = enemies[i]
		if not e.remove and e.bullet_attack(x1, y1, x2, y2):
			did_hit = true
			break

	t += 1
	if did_hit or t > TRAVEL_TIME or game_mode.is_missile_target(x, y):
		remove = true
		BulletHit.new(x, y)


func render() -> void:
	main.draw_centered(main.yellow_bullet, x, y)
