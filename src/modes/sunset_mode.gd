# Port of jackal.SunsetMode.
#
# The ending: the rescue helicopter flies out over a sunset (its silhouette
# fading into a lit sprite as it turns), then the credits type themselves out,
# and finally the player can press fire to start hard mode.
class_name SunsetMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_PAUSED_1 := 1
const STATE_HELICOPTER := 2
const STATE_PAUSED_2 := 3
const STATE_CREDITS := 4
const STATE_WAITING := 5
const STATE_ADVANCE_TO_HARD_MODE := 6
const STATE_HARD_MODE_FADE_OUT := 7
const STATE_HARD_MODE_WAITING := 8
const STATE_DONE := 9

const CENTER_X := Main.DISPLAY_WIDTH / 2.0
const CENTER_Y := Main.DISPLAY_HEIGHT / 2.0
const HELICOPTER_SCALE_0 := 0.2
const HELICOPTER_X0 := -215.0
const HELICOPTER_X1 := 215.0
const HELICOPTER_Y0 := -275.0
const HELICOPTER_Y1 := -315.0
const HELICOPTER_Z0 := -10.0
const HELICOPTER_Z1 := 0.0
const HELICOPTER_ANGLE0 := 0.0
const HELICOPTER_ANGLE1 := 8.75
const Z0 := (HELICOPTER_SCALE_0 * HELICOPTER_Z0) / (HELICOPTER_SCALE_0 - 1.0)

const PAUSE_TIME_1 := 1
const HELICOPTER_TIME := 18 * 91
const HELICOPTER_HARD_TIME := 1900
const FADE_TIME := 1.0 * 91
const SHADE_TIME := 12.0 * 91
const PAUSE_TIME_2 := 91
const TYPE_TIME := 11
const EOL_PAUSE_TIME := 64
const EOM_PAUSE_TIME := 2 * 91

const I_HELICOPTER := 1.0 / HELICOPTER_TIME
const I_FADE_TIME := 1.0 / FADE_TIME
const I_SHADE_TIME := 1.0 / SHADE_TIME

const SUN_HEIGHT := 92
const SUN_AMPLITUDE := 2.0
const SUN_WAVES := 3.0
const WAVES_HEIGHT := 32

static var SUN_OFFSETS: PackedFloat32Array = PackedFloat32Array()

const CREDITS: Array = [
	["programmed by",
	 "michael birken"],

	["inspired by",
	 "`jackal\" for the",
	 "nintendo",
	 "entertainment system and the",
	 "brilliant works of konami"],

	["based on graphics designed by",
	 "shimoide",
	 "satoh"],

	["adopted music by",
	 "sakamoto",
	 "fujio"],

	["based on characters created by",
	 "fujiwara",
	 "yoshimoto",
	 "maruo"],

	["based on code by",
	 "hori",
	 "yanagisawa"],

	["presented by",
	 "meatfighter.com"],

	["thanks for playing"],

	["final score: ",
	 "",
	 "  press start for",
	 "  hard mode..."],
]

var main: Main
var input: HumanInput
var credits: Array = []
var sun_offset: int
var sun_offset_counter: int
var rotor_angle: float
var helicopter_x: float = HELICOPTER_X0
var helicopter_y: float = HELICOPTER_Y0
var helicopter_z: float = HELICOPTER_Z0
var helicopter_angle: float = HELICOPTER_ANGLE0
var delay: int = PAUSE_TIME_1
var helicopter_delay: int
var state: int = STATE_FADE_IN
var credits_index: int
var line_index: int
var line_length: int


static func _static_init() -> void:
	SUN_OFFSETS.resize(SUN_HEIGHT)
	var percent := SUN_WAVES * 2 * PI / SUN_HEIGHT
	for i in SUN_HEIGHT:
		SUN_OFFSETS[i] = SUN_AMPLITUDE * sin(i * percent)


func init(p_main: Main) -> void:
	main = p_main
	input = p_main.input

	# The credits are copied so the score can be appended to the last page.
	credits = []
	for page in CREDITS:
		credits.append((page as Array).duplicate())
	credits[credits.size() - 1][0] += p_main.score_str

	p_main.start_fade(false, self)


func update() -> void:
	match state:
		STATE_PAUSED_1:
			delay -= 1
			if delay == 0:
				state = STATE_HELICOPTER
		STATE_HELICOPTER:
			_update_helicopter()
		STATE_PAUSED_2:
			delay -= 1
			if delay == 0:
				state = STATE_CREDITS
				delay = 1
		STATE_CREDITS:
			delay -= 1
			if delay == 0:
				_advance_credits()
		STATE_WAITING:
			if input.is_fire() or input.is_shoot() or input.is_enter():
				state = STATE_ADVANCE_TO_HARD_MODE
				main.advance_player_to_hard_mode()
				main.stop_song()
				main.start_fade(true, self)


func _update_helicopter() -> void:
	var t := helicopter_delay * I_HELICOPTER
	# The rotor gets louder as the helicopter comes towards the camera.
	if not main.is_sound_playing(main.helicopter_sound):
		var volume := t + 0.15
		main.play_sound(main.helicopter_sound, minf(volume, 1.0))
	helicopter_x = HELICOPTER_X0 + (HELICOPTER_X1 - HELICOPTER_X0) * t
	helicopter_y = HELICOPTER_Y0 + (HELICOPTER_Y1 - HELICOPTER_Y0) * t
	helicopter_z = HELICOPTER_Z0 + (HELICOPTER_Z1 - HELICOPTER_Z0) * t
	helicopter_angle = HELICOPTER_ANGLE0 \
		+ (HELICOPTER_ANGLE1 - HELICOPTER_ANGLE0) * t
	helicopter_delay += 1
	if main.hard_mode:
		if helicopter_delay == HELICOPTER_HARD_TIME:
			state = STATE_HARD_MODE_FADE_OUT
			main.stop_sound(main.helicopter_sound)
			main.request_song(main.ending_song)
			main.start_fade(true, self)
	elif helicopter_delay == HELICOPTER_TIME:
		state = STATE_PAUSED_2
		main.stop_sound(main.helicopter_sound)
		main.request_song(main.ending_song)
		rotor_angle = 0
		delay = PAUSE_TIME_2


func _advance_credits() -> void:
	var page: Array = credits[credits_index]
	if line_index == page.size():
		line_index = 0
		credits_index += 1
		delay = TYPE_TIME
	elif line_length == (page[line_index] as String).length():
		line_length = 0
		line_index += 1
		if line_index == page.size():
			if credits_index == credits.size() - 1:
				state = STATE_WAITING
				input.clear_key_pressed_record()
			else:
				delay = EOM_PAUSE_TIME
		else:
			delay = TYPE_TIME
	else:
		line_length += 1
		if line_length == (page[line_index] as String).length():
			delay = EOL_PAUSE_TIME
		else:
			delay = TYPE_TIME


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_PAUSED_1
	elif state == STATE_HARD_MODE_FADE_OUT:
		state = STATE_HARD_MODE_WAITING
		main.request_mode(Modes.HARD_ENDING)
	elif state == STATE_ADVANCE_TO_HARD_MODE:
		state = STATE_DONE
		main.request_mode(Modes.GAME)


# NOTE: the original passes its fade value into drawRotated's `scale`
# parameter, not its `alpha` one, so the rotor disc grows rather than fades in.
# That is reproduced here rather than "fixed".
func _draw_helicopter(alpha: float) -> void:
	var k := Z0 / (Z0 - helicopter_z)
	main.rotate_graphics(CENTER_X + helicopter_x * k, CENTER_Y + helicopter_y * k,
		helicopter_angle, k)
	main.scale_graphics(0, -40, 1, 0.2)
	for i in 4:
		main.draw_rotated_offset_scaled(main.rescue_helicopters[2], 0, 0, 0, -28,
			90 * i + rotor_angle, alpha)
	main.pop_graphics()
	main.draw_offset(main.rescue_helicopters[0], -38, -40, alpha)
	main.pop_graphics()


func _draw_helicopter_shaded(shade: float) -> void:
	var k := Z0 / (Z0 - helicopter_z)
	main.rotate_graphics(CENTER_X + helicopter_x * k, CENTER_Y + helicopter_y * k,
		helicopter_angle, k)
	main.scale_graphics(0, -40, 1, 0.2)
	for i in 4:
		main.draw_rotated_offset(main.rescue_helicopters[2], 0, 0, 0, -28,
			90 * i + rotor_angle)
	main.pop_graphics()
	main.draw_offset(main.rescue_helicopters[1], -38, -40)
	if shade > 0:
		main.draw_offset(main.rescue_helicopters[0], -38, -40, shade)
	main.pop_graphics()


func render() -> void:
	if state == STATE_HARD_MODE_WAITING:
		main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
			Color.BLACK, true)
		return

	if state < STATE_PAUSED_2:
		sun_offset_counter += 1
		if sun_offset_counter == 2:
			sun_offset_counter = 0
			sun_offset += 1
			if sun_offset == SUN_HEIGHT:
				sun_offset = 0

		rotor_angle -= 30
		if rotor_angle == -90:
			rotor_angle = 0

	main.sunset.draw(main, 0, 0)

	# The sun and the water are drawn one scanline at a time with a travelling
	# sine offset, which is what makes them shimmer.
	var j := sun_offset
	for i in SUN_HEIGHT:
		main.draw(main.suns[i], 428 + SUN_OFFSETS[j], 356 + i)
		j += 1
		if j == SUN_HEIGHT:
			j = 0

	j = sun_offset
	for i in WAVES_HEIGHT:
		main.draw(main.waves[i], 428 + SUN_OFFSETS[j], 448 + i)
		j += 1
		if j == SUN_HEIGHT:
			j = 0

	if state != STATE_PAUSED_1:
		if helicopter_delay < FADE_TIME:
			_draw_helicopter(helicopter_delay * I_FADE_TIME)
		elif helicopter_delay < SHADE_TIME + FADE_TIME:
			_draw_helicopter_shaded(1.0 - (helicopter_delay - FADE_TIME) * I_SHADE_TIME)
		else:
			_draw_helicopter_shaded(0)

	if state >= STATE_CREDITS:
		var lines: Array = credits[credits_index]
		var indent := false
		for i in line_index:
			main.draw_text(lines[i], 96 if indent else 32, 48 + (i << 6),
				Main.FONT_WHITE)
			indent = (lines[i] as String).length() != 0
		if line_index < lines.size():
			main.draw_text(lines[line_index], 96 if indent else 32,
				48 + (line_index << 6), Main.FONT_WHITE, line_length)
