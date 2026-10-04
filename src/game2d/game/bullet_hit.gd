# Port of jackal.BulletHit.
class_name BulletHit
extends GameElement

const TIME_TO_LIVE := 10

var time_to_live: int = TIME_TO_LIVE


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 1


func update() -> void:
	time_to_live -= 1
	if time_to_live <= 0:
		remove = true


func render() -> void:
	main.draw_centered(main.bullet_hit, x, y)
