# Port of jackal.TileDebris.
#
# One map tile flung into the air when a structure collapses. The tile is
# swapped in the live map at the moment it starts moving, and the delay is
# proportional to its distance from the player, so the collapse ripples
# outwards from where the player is standing.
class_name TileDebris
extends GameElement

const GRAVITY := 0.2
const SCALER := 0.015

var sprite: Spr
var X: int
var Y: int
var tile: int
var type: int
var delay: int
var moving: bool
var vx: float
var vy: float
var scale: float = 1.0


func _init(p_x: int, p_y: int, p_tile: int, p_type: int) -> void:
	super()
	X = p_x
	Y = p_y
	x = (p_x << 5) + 16
	y = (p_y << 5) + 16
	tile = p_tile
	type = p_type
	# Off the image backdrop when the stage has one, off the tile sheet when it
	# does not; background_sprite answers either way.
	sprite = game_mode.background_sprite(p_x, p_y)
	delay = int(game_mode.player.x - x) >> 3
	if delay < 0:
		delay = -delay
	delay += 1


func init() -> void:
	layer = 7


func update() -> void:
	if moving:
		vy += GRAVITY
		x += vx
		y += vy
		scale -= SCALER
		if scale <= 0:
			scale = 0
			do_remove()
		return

	delay -= 1
	if delay == 0:
		moving = true
		game_mode.tile_map[Y][X] = tile
		game_mode.types_map[Y][X] = type
		game_mode.mark_patched(X, Y)
		vx = 1 + main.random.randf() * 5
		if game_mode.player.x > x:
			vx = -vx
		vy = -2 - main.random.randf() * 5


func render() -> void:
	if moving:
		main.draw_centered_scaled(sprite, x, y, scale)
