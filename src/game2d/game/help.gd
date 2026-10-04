# Port of jackal.Help. The "HELP" bubble over a POW building, which blinks four
# times and then releases a soldier.
class_name Help
extends GameElement

var left: bool
var visible: bool = false
var visible_count: int = 60
var blinks: int = 0


func _init(p_x: float, p_y: float, p_left: bool) -> void:
	super()
	x = p_x
	y = p_y
	left = p_left


func update() -> void:
	visible_count -= 1
	if visible_count != 0:
		return
	visible_count = 12
	visible = not visible
	if visible:
		return
	blinks += 1
	if blinks == 4:
		remove = true
		FriendlySoldier.new_walking(x + (-24 if left else 24), y + 28,
			FriendlySoldierType.HOUSE_LEFT_WALKING if left
				else FriendlySoldierType.HOUSE_RIGHT_WALKING,
			2 + main.random.randi_range(0, 2), false)


func render() -> void:
	if visible:
		main.draw(main.help, x - 48, y - 32)
