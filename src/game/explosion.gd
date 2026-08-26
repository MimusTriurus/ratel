# Port of jackal.Explosion.
class_name Explosion
extends GameElement

const GROW_RATE := 1.03

var size: float = 32
var sprite_index: int
var scale: float
var grenade_explosion: bool
var damages_enemies: bool = true
var enemies: Array[Enemy]
var type: int
var tiny: bool
var delay: int
var alpha: float = 1.0
var enemy_x: float
var enemy_y: float
var tracked_enemy: Enemy


func _init(p_x: float, p_y: float, player_explosion: bool = false) -> void:
	super()
	x = p_x
	y = p_y
	type = AttackSource.PLAYER_EXPLOSION if player_explosion else AttackSource.EXPLOSION
	enemies = game_mode.enemies


# A delayed explosion that follows an enemy until it goes off.
static func attached(p_x: float, p_y: float, p_tiny: bool, p_delay: int,
		p_alpha: float, p_enemy: Enemy) -> Explosion:
	var e := Explosion.delayed(p_x, p_y, p_tiny, p_delay, p_alpha)
	e.tracked_enemy = p_enemy
	e.enemy_x = p_enemy.x
	e.enemy_y = p_enemy.y
	return e


static func delayed(p_x: float, p_y: float, p_tiny: bool, p_delay: int,
		p_alpha: float) -> Explosion:
	var e := Explosion.new(p_x, p_y)
	e.set_tiny(p_tiny)
	e.set_delayed(p_delay)
	e.set_alpha(p_alpha)
	return e


func set_alpha(p_alpha: float) -> void:
	alpha = p_alpha


func set_tiny(p_tiny: bool) -> void:
	tiny = p_tiny
	if tiny:
		set_damages_enemies(false)


func set_delayed(p_delay: int) -> void:
	delay = p_delay


func set_damages_enemies(p_damages_enemies: bool) -> void:
	damages_enemies = p_damages_enemies


func set_grenade_explosion(p_grenade_explosion: bool) -> void:
	grenade_explosion = p_grenade_explosion


func init() -> void:
	layer = 5


func update() -> void:
	if delay > 0:
		delay -= 1
		if delay == 0:
			if tracked_enemy != null:
				x += tracked_enemy.x - enemy_x
				y += tracked_enemy.y - enemy_y
		else:
			return

	size *= GROW_RATE

	if size >= 80:
		sprite_index = 2
		scale = size / 128.0
	elif size >= 56:
		sprite_index = 1
		scale = size / 56.0
	else:
		sprite_index = 0
		scale = size / 32.0

	var margin := size * 0.35
	var x1 := x - margin
	var y1 := y - margin
	var x2 := x + margin
	var y2 := y + margin
	if damages_enemies and not game_mode.is_outside_of_frame_rect(x1, y1, x2, y2):
		for i in range(enemies.size() - 1, -1, -1):
			var e: Enemy = enemies[i]
			if not e.remove:
				e.attack(x1, y1, x2, y2, type)

	if (tiny and size > 68) or size > 128:
		remove = true
		if grenade_explosion:
			game_mode.player.set_weapon_armed(true)


func render() -> void:
	main.draw_scaled(main.explosions[sprite_index], x, y, scale, alpha)
