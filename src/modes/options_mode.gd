# Port of jackal.OptionsMode.
class_name OptionsMode
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

	menu = Menu.new(448, 512, p_main, 0, Menu.ICON_TANK, self,
		["input", "controls", "difficulty", "done"])

	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_MENU
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		match selected_index:
			0:
				main.request_mode(Modes.INPUT)
			1:
				main.request_mode(Modes.CONTROLS)
			2:
				main.request_mode(Modes.DIFFICULTY)
			3:
				main.request_mode(Modes.INTRO)


func selection_changed(_index: int) -> void:
	pass


func option_selected(p_index: int) -> void:
	chosen = true
	selected_index = p_index
	main.play_sound(main.missile_sound)


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

	main.draw_text("options", 400, 384, Main.FONT_GRAY)
	menu.render()
