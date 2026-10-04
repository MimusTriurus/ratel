# Port of jackal.Enemy.
class_name Enemy
extends HitElement

var solid: bool   # other enemies will avoid bumping into this one
var mine: bool    # player will explode if it hits this enemy

var solid_x1: float
var solid_y1: float
var solid_x2: float
var solid_y2: float

var mine_x1: float
var mine_y1: float
var mine_x2: float
var mine_y2: float

var bullet_hits: int
var points: int

var explosion_x: float
var explosion_y: float

var play_sound_on_remove: bool = true


func is_solid_xy(px: float, py: float) -> bool:
	var lx := px - x
	var ly := py - y
	return ly >= solid_y1 and ly <= solid_y2 and lx >= solid_x1 and lx <= solid_x2


func is_solid_rect(x1: float, y1: float, x2: float, y2: float) -> bool:
	return overlap(x1, y1, x2, y2,
		x + solid_x1, y + solid_y1, x + solid_x2, y + solid_y2)


func is_mine_xy(px: float, py: float) -> bool:
	var lx := px - x
	var ly := py - y
	return ly >= mine_y1 and ly <= mine_y2 and lx >= mine_x1 and lx <= mine_x2


func is_mine_rect(x1: float, y1: float, x2: float, y2: float) -> bool:
	return overlap(x1, y1, x2, y2,
		x + mine_x1, y + mine_y1, x + mine_x2, y + mine_y2)


func flatten() -> void:
	explode()


func explode() -> void:
	if not remove:
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)


# Returns true if the player bumped into the enemy.
func bump(x1: float, y1: float, x2: float, y2: float, invincible: bool) -> bool:
	if invincible:
		return false
	if is_mine_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


func do_remove() -> void:
	remove = true
	if play_sound_on_remove:
		main.play_hit_explode_sound()


# Returns true if the attack was successful.
func attack(x1: float, y1: float, x2: float, y2: float, attack_source: int) -> bool:
	if attack_source < AttackSource.PLAYER_EXPLOSION and hit_rect(x1, y1, x2, y2):
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
		return true
	return false


# Returns true if the player bullet was absorbed by the enemy.
func bullet_attack(x1: float, y1: float, x2: float, y2: float) -> bool:
	if not hit_rect(x1, y1, x2, y2):
		return false
	bullet_hits -= 1
	if bullet_hits <= 0:
		do_remove()
		Explosion.new(x + explosion_x, y + explosion_y)
		main.add_points(points)
	else:
		main.play_sound_always(main.bullet_hit_sound)
	return true


func check_bounds(max_y: float) -> void:
	if solid:
		if y + solid_y1 > max_y:
			play_sound_on_remove = false
			do_remove()
	else:
		if y + hit_y1 > max_y:
			play_sound_on_remove = false
			do_remove()
