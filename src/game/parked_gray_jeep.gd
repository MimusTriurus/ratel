# Port of jackal.ParkedGrayJeep.
class_name ParkedGrayJeep
extends Enemy


func _init(p_x: float, p_y: float) -> void:
	super()
	x = p_x
	y = p_y


func init() -> void:
	super.init()

	layer = 3

	bullet_hits = 3

	hit_x1 = -40
	hit_y1 = -40
	hit_x2 = 40
	hit_y2 = 40

	mine = true
	mine_x1 = -28
	mine_y1 = -28
	mine_x2 = 28
	mine_y2 = 28

	solid = true
	solid_x1 = -48
	solid_y1 = -48
	solid_x2 = 48
	solid_y2 = 48

	points = 50


func update() -> void:
	pass


func render() -> void:
	main.draw_centered(main.parked_gray_jeep, x, y)
