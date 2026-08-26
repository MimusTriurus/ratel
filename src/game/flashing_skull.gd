# Port of jackal.FlashingSkull: the skull painted on the final map flashes,
# fades to its burnt version, and then hands over to MissionAccomplished.
class_name FlashingSkull
extends GameElement

const STATE_FLASHING := 0
const STATE_FADING := 1
const STATE_PAUSED := 2
const STATE_DONE := 3

const FLASH_TIME := 5
const FLASHING_TIME := FLASH_TIME * 32
const FADE_TIME := 91

const INV_FADE_TIME := 1.0 / float(FADE_TIME)

# (x, y, tile index) of every tile making up the skull.
const TILES: Array[Vector3i] = [
	Vector3i(800, 704, 302), Vector3i(832, 704, 303), Vector3i(864, 704, 303),
	Vector3i(896, 704, 304), Vector3i(928, 704, 303), Vector3i(960, 704, 303),
	Vector3i(992, 704, 303), Vector3i(1024, 704, 303), Vector3i(1056, 704, 303),
	Vector3i(1088, 704, 303), Vector3i(1120, 704, 305), Vector3i(1152, 704, 303),
	Vector3i(1184, 704, 303), Vector3i(1216, 704, 306),
	Vector3i(832, 736, 302), Vector3i(864, 736, 303), Vector3i(896, 736, 304),
	Vector3i(928, 736, 307), Vector3i(960, 736, 308), Vector3i(992, 736, 309),
	Vector3i(1024, 736, 310), Vector3i(1056, 736, 308), Vector3i(1088, 736, 311),
	Vector3i(1120, 736, 305), Vector3i(1152, 736, 303), Vector3i(1184, 736, 306),
	Vector3i(864, 768, 302), Vector3i(896, 768, 304), Vector3i(928, 768, 303),
	Vector3i(960, 768, 307), Vector3i(992, 768, 312), Vector3i(1024, 768, 313),
	Vector3i(1056, 768, 311), Vector3i(1088, 768, 303), Vector3i(1120, 768, 305),
	Vector3i(1152, 768, 306),
	Vector3i(896, 800, 314), Vector3i(928, 800, 303), Vector3i(960, 800, 303),
	Vector3i(992, 800, 307), Vector3i(1024, 800, 311), Vector3i(1056, 800, 303),
	Vector3i(1088, 800, 303), Vector3i(1120, 800, 315),
	Vector3i(928, 832, 302), Vector3i(960, 832, 303), Vector3i(992, 832, 303),
	Vector3i(1024, 832, 303), Vector3i(1056, 832, 303), Vector3i(1088, 832, 306),
	Vector3i(960, 864, 302), Vector3i(992, 864, 303), Vector3i(1024, 864, 303),
	Vector3i(1056, 864, 306),
	Vector3i(992, 896, 302), Vector3i(1024, 896, 306),
]

var state: int = STATE_FLASHING
var delay: int = FLASHING_TIME
var flash_delay: int = 1
var visible: bool
var alpha: float


func init() -> void:
	layer = 0


func update() -> void:
	match state:
		STATE_FLASHING:
			delay -= 1
			if delay == 0:
				state = STATE_FADING
				delay = FADE_TIME
		STATE_FADING:
			alpha = 1.0 - INV_FADE_TIME * delay
			delay -= 1
			if delay == 0:
				state = STATE_PAUSED
		STATE_PAUSED:
			if not main.is_song_playing():
				state = STATE_DONE
				MissionAccomplished.new()


func render() -> void:
	match state:
		STATE_FLASHING:
			flash_delay -= 1
			if flash_delay == 0:
				visible = not visible
				flash_delay = FLASH_TIME
			if visible:
				for i in range(TILES.size() - 1, -1, -1):
					var t: Vector3i = TILES[i]
					main.draw(game_mode.tiles[t.z], t.x, t.y)
		STATE_FADING:
			for i in range(TILES.size() - 1, -1, -1):
				var t: Vector3i = TILES[i]
				main.draw(game_mode.tiles[t.z + 14], t.x, t.y, alpha)
		_:
			for i in range(TILES.size() - 1, -1, -1):
				var t: Vector3i = TILES[i]
				main.draw(game_mode.tiles[t.z + 14], t.x, t.y)
