# Port of jackal.ContinueMode.
class_name ContinueMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_MENU := 1
const STATE_FADE_OUT := 2
const STATE_DONE := 3

var main: Main
var input: HumanInput
var state: int = STATE_FADE_IN
var menu: Menu
var chosen: bool
var selected_index: int


func init(p_main: Main) -> void:
	main = p_main
	input = p_main.input

	p_main.stop_all_sound()
	p_main.request_song(p_main.continue_song)

	menu = Menu.new(480, 512, p_main, 0, Menu.ICON_GRENADE, self,
		["yes", "no"])

	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_MENU
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		if selected_index == 0:
			main.continue_player()
			main.request_mode(Modes.GAME)
		else:
			main.request_mode(Modes.INTRO)


func selection_changed(_index: int) -> void:
	pass


func option_selected(p_index: int) -> void:
	chosen = true
	selected_index = p_index
	main.stop_song()


func update() -> void:
	menu.update()

	if state == STATE_MENU and chosen:
		state = STATE_FADE_OUT
		main.start_fade(true, self)


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	if state == STATE_DONE:
		return

	main.draw_text("continue", 384, 384, Main.FONT_GRAY)
	menu.render()
