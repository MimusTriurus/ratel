# Port of jackal.HitElement.
class_name HitElement
extends GameElement

var hit_flag: bool

var hit_x1: float
var hit_y1: float
var hit_x2: float
var hit_y2: float

# Ring buffer of the last eight 128px cells visited, used to spot tanks that
# have got stuck driving in circles.
var trail := PackedInt32Array([0, -1, -2, -3, -4, -5, -6, -7])
var trail_index: int = 7


func init() -> void:
	enemy = true


static func overlap(ax1: float, ay1: float, ax2: float, ay2: float,
		bx1: float, by1: float, bx2: float, by2: float) -> bool:
	return ax1 <= bx2 and ax2 >= bx1 and ay1 <= by2 and ay2 >= by1


func hit_point(h: HitElement) -> bool:
	return hit_xy(h.x, h.y)


func hit_element(h: HitElement) -> bool:
	return overlap(
		h.x + h.hit_x1, h.y + h.hit_y1, h.x + h.hit_x2, h.y + h.hit_y2,
		x + hit_x1, y + hit_y1, x + hit_x2, y + hit_y2)


func hit_xy(px: float, py: float) -> bool:
	var lx := px - x
	var ly := py - y
	return ly >= hit_y1 and ly <= hit_y2 and lx >= hit_x1 and lx <= hit_x2


func hit_rect(x1: float, y1: float, x2: float, y2: float) -> bool:
	return overlap(x1, y1, x2, y2,
		x + hit_x1, y + hit_y1, x + hit_x2, y + hit_y2)


func is_hit() -> bool:
	return hit_flag


func set_hit(h: bool) -> void:
	hit_flag = h


func update_trail() -> void:
	var cell := ((int(y) >> 7) << 4) | (int(x) >> 7)
	if cell != trail[trail_index]:
		trail_index -= 1
		if trail_index < 0:
			trail_index = 7
		trail[trail_index] = cell


func trail_contains_loop() -> bool:
	var i0 := trail_index
	var i1 := (trail_index + 1) & 7
	var i2 := (trail_index + 2) & 7
	var i3 := (trail_index + 3) & 7

	if trail[i0] == trail[i2] and trail[i1] == trail[i3]:
		return true

	var i4 := (trail_index + 4) & 7
	var i5 := (trail_index + 5) & 7

	if trail[i0] == trail[i3] and trail[i1] == trail[i4] and trail[i2] == trail[i5]:
		return true

	var i6 := (trail_index + 6) & 7
	var i7 := (trail_index + 7) & 7

	if trail[i0] == trail[i4] and trail[i1] == trail[i5] \
			and trail[i2] == trail[i6] and trail[i3] == trail[i7]:
		return true

	return false


func check_bounds(max_y: float) -> void:
	if y + hit_y1 > max_y:
		do_remove()
