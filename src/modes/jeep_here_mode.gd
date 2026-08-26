# Port of jackal.JeepHereMode: the "here" cutscene between stages.
class_name JeepHereMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_SLIDE := 1
const STATE_HERE := 2
const STATE_FADE_OUT := 3
const STATE_DONE := 4

const COLOR_CYAN := Color8(0x00, 0x7C, 0x8D)

const SLIDE_TIME := 91
const HERE_DELAY := 3 * 91

const SLIDE_SPEED := (Main.DISPLAY_WIDTH - 224) / float(SLIDE_TIME)

var main: Main
var state: int = STATE_FADE_IN
var jeep_here_x: float = Main.DISPLAY_WIDTH
var delay: int = HERE_DELAY


func init(p_main: Main) -> void:
	main = p_main
	p_main.start_fade(false, self)
	p_main.request_song(p_main.cutscene_song)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_SLIDE
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		main.request_mode(Modes.MAP)


func update() -> void:
	match state:
		STATE_SLIDE:
			jeep_here_x -= SLIDE_SPEED
			if jeep_here_x <= 224:
				jeep_here_x = 224
				state = STATE_HERE
		STATE_HERE:
			delay -= 1
			if delay == 0:
				state = STATE_FADE_OUT
				main.start_fade(true, self)


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	if state == STATE_DONE:
		return

	main.draw_rect(Rect2(0, 288, Main.DISPLAY_WIDTH, 416), COLOR_CYAN, true)
	main.draw_rect(Rect2(0, 264, Main.DISPLAY_WIDTH, 16), Color.WHITE, true)
	main.draw_rect(Rect2(0, 712, Main.DISPLAY_WIDTH, 16), Color.WHITE, true)

	main.jeep_here.draw(main, jeep_here_x, 320)

	if state >= STATE_HERE:
		main.draw(main.heres[0], 160, 320)
		main.draw(main.heres[1], 287, 416)
