# Port of jackal.Chinook.
#
# The transport that flies the jeep in at the start of a continued stage. It
# swings in along a quarter-circle arc, unloads, then swings back out; height
# is faked with a scale factor and a separately scaled shadow.
class_name Chinook
extends GameElement

const STATE_FORWARDS := 0
const STATE_UNLOADING := 1
const STATE_AWAY := 2

const TO_DEGREES := 180.0 / PI
const IPI2 := 2.0 / PI

const FORWARD_TIME := 4 * 91
const DIAGONAL_TIME := 91.0

const DT := PI / 2.0
const AT := 2 * DT / float(FORWARD_TIME * FORWARD_TIME)
const VT0 := AT * FORWARD_TIME

const Z1 := 1.0
const SCALE_1 := 10.0
const Z0 := SCALE_1 * Z1 / (SCALE_1 - 1.0)

var angle: float
var rotor_angle: float = 90.0 + TO_DEGREES * DT
var z: float = 1.0
var state: int = STATE_FORWARDS
var vt: float = VT0
var t: float = DT
var diagonal_steps: int
var intro_player: IntroPlayer
var X: float
var Y: float


func init() -> void:
	layer = 7

	game_mode.playing = false

	# On a continue the cutscene is skipped: the jeep just appears.
	if main.continued:
		do_remove()
		_create_player()


func update() -> void:
	match state:
		STATE_FORWARDS:
			vt -= AT
			if vt >= 0:
				angle = 90.0 + TO_DEGREES * t
				z = (PI - t) * IPI2
				t += vt
				x = 1540.0 + 1024.0 * cos(t)
				y = 10780.0 + 1024.0 * sin(t)
			else:
				state = STATE_UNLOADING
				intro_player = IntroPlayer.new(x, y + 102, self)
			main.play_sound_if_not_playing(main.helicopter_sound, 0.5)
		STATE_UNLOADING:
			main.play_sound_if_not_playing(main.helicopter_sound, 0.5)
		STATE_AWAY:
			vt += AT
			angle = TO_DEGREES * t - 90.0
			z = -t * IPI2
			t -= vt
			x = X + 1024.0 * cos(t)
			y = Y + 1024.0 * sin(t)
			if angle < -128:
				do_remove()
				_create_player()
			else:
				main.play_sound_if_not_playing(main.helicopter_sound,
					0.5 + (angle + 90) / 76.0)


func _create_player() -> void:
	game_mode.player.x = IntroPlayer.FINAL_X
	game_mode.player.y = IntroPlayer.FINAL_Y
	game_mode.player.make_invincible()
	if intro_player != null:
		intro_player.do_remove()
	game_mode.playing = true


func unload_completed() -> void:
	state = STATE_AWAY
	X = x - 1024.0
	Y = y
	vt = 0
	t = 0


func render() -> void:
	rotor_angle -= 30
	if rotor_angle == -90:
		rotor_angle = 0

	var scale := Z0 / (Z0 - z)
	var shadow_scale := 3.25 / scale

	main.draw_rotated_scaled_xy(main.chinooks[3], x + 384 * z + 24, y + 256 * z + 16,
		-43.5, -22.5, angle, shadow_scale, shadow_scale)
	main.rotate_graphics(x, y, angle, scale)
	main.draw_offset(main.chinooks[0], -154, 0)
	main.draw_offset(main.chinooks[1], -154, -80)
	for i in 4:
		var ang := 90 * i + rotor_angle
		main.draw_rotated_offset(main.chinooks[2], -102, 0, 0, -38, ang)
		main.draw_rotated_offset(main.chinooks[2], 96, 0, 0, -38, 315 - ang)
	main.pop_graphics()
