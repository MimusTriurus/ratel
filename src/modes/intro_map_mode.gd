# Port of jackal.IntroMapMode: the briefing map shown before the first stage.
class_name IntroMapMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_PAUSED := 1
const STATE_FADE_OUT := 2
const STATE_DONE := 3

const PAUSE_DELAY := 250

var main: Main
var delay: int = PAUSE_DELAY
var state: int = STATE_FADE_IN


func init(p_main: Main) -> void:
	main = p_main
	p_main.request_song(p_main.intro_song)
	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_PAUSED
	else:
		state = STATE_DONE
		main.start_player()
		main.request_mode(Modes.GAME)


func update() -> void:
	if state == STATE_PAUSED:
		delay -= 1
		if delay == 0:
			state = STATE_FADE_OUT
			main.start_fade(true, self)


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	if state == STATE_DONE:
		return

	main.map.draw(main, 124, 92)

	main.draw_text("This battle will", 416, 224, Main.FONT_GRAY)
	main.draw_text("make your blood", 416, 288, Main.FONT_GRAY)
	main.draw_text("boil.", 416, 352, Main.FONT_GRAY)
	main.draw_text("Good luck!", 480, 416, Main.FONT_GRAY)
