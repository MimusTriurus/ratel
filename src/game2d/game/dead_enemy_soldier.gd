# Port of jackal.DeadEnemySoldier: the corpse, which lingers then fades.
class_name DeadEnemySoldier
extends GameElement

const PRE_FADE_DELAY := 91 * 2
const FADE_DELAY := 91

var fading: bool = false
var delay: int = PRE_FADE_DELAY


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	layer = 1
	main.add_points(100)


func update() -> void:
	delay -= 1
	if delay != 0:
		return
	if fading:
		do_remove()
	else:
		fading = true
		delay = PRE_FADE_DELAY


func render() -> void:
	if fading:
		main.draw(main.dead_enemy_soldier, x - 20, y - 54, delay / float(FADE_DELAY))
	else:
		main.draw(main.dead_enemy_soldier, x - 20, y - 54)
