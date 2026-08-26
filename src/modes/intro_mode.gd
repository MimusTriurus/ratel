# Port of jackal.IntroMode.
#
# The attract loop: title screen with the start/options menu, then the story
# text scrolling in from the right, then the two pairs of officers walking on
# and having their names typed out. Any input jumps back to the title.
class_name IntroMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_EXPLOSION := 1
const STATE_START_GAME := 2
const STATE_OPTIONS := 3
const STATE_TITLE := 4
const STATE_STORY_SCROLL := 5
const STATE_STORY := 6
const STATE_SOLDIERS_ENTER := 7
const STATE_TYPING := 8
const STATE_NAMES_PAUSE := 9
const STATE_FADE_OUT := 10
const STATE_DONE := 11

const STORY: Array[String] = [
	"Your brothers-in-arms are",
	"hostages behind enemy",
	"lines, and you're their",
	"only hope for freedom.",
	"But the firepower you'll",
	"face to rescue them is",
	"awesome.",
	"Rescue the POW's in the",
	"buildings.",
	"You'll need a pocket full",
	"of miracles, and the",
	"ferocity of a wild jackal.",
]

const NAMES: Array = [
	["Colonel", "Decker", "Lieut.", "Bob"],
	["Sgt.", "Quint", "Corporal", "Grey"],
]

const NAME_XYS: Array[Vector2] = [
	Vector2(528, 128),
	Vector2(624, 192),
	Vector2(240, 640),
	Vector2(304, 736),
]

const UPPER_SOLDIER_Y := 96.0
const LOWER_SOLDIER_Y := 576.0

const UPPER_SOLDIER_X0 := 1024.0
const UPPER_SOLDIER_X1 := 112.0
const LOWER_SOLDIER_X0 := -288.0
const LOWER_SOLDIER_X1 := 624.0

const TITLE_DELAY := 600
const SCROLL_DELAY := 500
const STORY_DELAY := 500
const ENTER_DELAY := 40
const EON_DELAY := 45
const TYPE_DELAY := 10
const NAMES_DELAY := 100
const EXPLOSION_DELAY := 100

const I_SCROLL_DELAY := 1.0 / SCROLL_DELAY
const I_ENTER_DELAY := 1.0 / ENTER_DELAY

var main: Main
var input: HumanInput
var state: int = STATE_FADE_IN
var delay: int = TITLE_DELAY
var scroll_offset_x: float
var upper_soldier_x: float
var lower_soldier_x: float
var names_index: int
var name_length: int
var soldier_set: int
var menu: Menu
var selection_made: bool
var selected_index: int


func init(p_main: Main) -> void:
	main = p_main
	input = p_main.input

	p_main.start_fade(false, self)

	menu = Menu.new(416, 608, p_main, 0, Menu.ICON_JEEP, self,
		["start", "options"])
	menu.enable_konami_code_test()


func _start_title() -> void:
	state = STATE_TITLE
	delay = TITLE_DELAY
	scroll_offset_x = 0
	main.stop_song()
	menu.set_input_enabled(true)


func _update_title_screen() -> void:
	menu.update()

	delay -= 1
	if delay == 0:
		main.stop_song()
		main.request_song(main.title_song)
		state = STATE_STORY_SCROLL
		delay = SCROLL_DELAY
		scroll_offset_x = 0
		menu.set_input_enabled(false)


func _update_story_scroll() -> void:
	scroll_offset_x = Main.DISPLAY_WIDTH * (delay * I_SCROLL_DELAY - 1.0)

	delay -= 1
	if delay == 0:
		state = STATE_STORY
		scroll_offset_x = -Main.DISPLAY_WIDTH
		delay = STORY_DELAY


func _start_soldiers_enter(set_index: int) -> void:
	soldier_set = set_index
	state = STATE_SOLDIERS_ENTER
	delay = ENTER_DELAY
	upper_soldier_x = UPPER_SOLDIER_X0
	lower_soldier_x = LOWER_SOLDIER_X0
	names_index = 0
	name_length = 0


func _update_story() -> void:
	delay -= 1
	if delay == 0:
		_start_soldiers_enter(0)


func _update_soldiers_enter() -> void:
	var t := 1.0 - delay * I_ENTER_DELAY
	upper_soldier_x = UPPER_SOLDIER_X0 + (UPPER_SOLDIER_X1 - UPPER_SOLDIER_X0) * t
	lower_soldier_x = LOWER_SOLDIER_X0 + (LOWER_SOLDIER_X1 - LOWER_SOLDIER_X0) * t

	delay -= 1
	if delay == 0:
		main.play_sound_always(main.intro_ching_sound)
		state = STATE_TYPING
		upper_soldier_x = UPPER_SOLDIER_X1
		lower_soldier_x = LOWER_SOLDIER_X1
		delay = EON_DELAY


func _update_typing() -> void:
	delay -= 1
	if delay != 0:
		return

	var names: Array = NAMES[soldier_set]
	if names_index == names.size():
		state = STATE_NAMES_PAUSE
		delay = NAMES_DELAY
	elif name_length == (names[names_index] as String).length():
		name_length = 0
		names_index += 1
		delay = TYPE_DELAY
	else:
		main.play_sound_always(main.intro_type_sound)
		name_length += 1
		# A longer beat after the surname of each officer.
		if name_length == (names[names_index] as String).length() and names_index == 1:
			delay = EON_DELAY
		else:
			delay = TYPE_DELAY


func _update_names_pause() -> void:
	delay -= 1
	if delay != 0:
		return
	if soldier_set == 0:
		_start_soldiers_enter(1)
	elif main.is_song_playing():
		delay = 1
	else:
		state = STATE_FADE_OUT
		main.start_fade(true, self)


func fade_completed() -> void:
	match state:
		STATE_FADE_IN:
			_start_title()
		STATE_FADE_OUT:
			state = STATE_FADE_IN
			main.start_fade(false, self)
		STATE_START_GAME:
			state = STATE_DONE
			main.request_mode(Modes.INTRO_MAP)
		STATE_OPTIONS:
			state = STATE_DONE
			main.request_mode(Modes.OPTIONS)


func selection_changed(_index: int) -> void:
	if state == STATE_TITLE:
		delay = TITLE_DELAY


func option_selected(p_index: int) -> void:
	selection_made = true
	selected_index = p_index
	if state == STATE_TITLE:
		delay = TITLE_DELAY


func _is_key_pressed() -> bool:
	return input.is_enter() or input.is_up() or input.is_down() \
		or input.is_right() or input.is_left() or input.is_shoot() \
		or input.is_fire()


func update() -> void:
	match state:
		STATE_FADE_IN, STATE_TITLE:
			_update_title_screen()
		STATE_STORY_SCROLL:
			_update_story_scroll()
		STATE_STORY:
			_update_story()
		STATE_SOLDIERS_ENTER:
			_update_soldiers_enter()
		STATE_TYPING:
			_update_typing()
		STATE_NAMES_PAUSE:
			_update_names_pause()
		STATE_EXPLOSION:
			delay -= 1
			if delay == 0:
				state = STATE_START_GAME
				main.start_fade(true, self)

	if state >= STATE_STORY_SCROLL and state < STATE_FADE_OUT and _is_key_pressed():
		menu.button_released = false
		_start_title()

	if state == STATE_TITLE and selection_made:
		if selected_index == 0:
			state = STATE_EXPLOSION
			delay = EXPLOSION_DELAY
			main.play_sound(main.explode_sound)
		elif selected_index == 1:
			state = STATE_OPTIONS
			main.start_fade(true, self)
			main.play_sound(main.explode_sound3)


func _clear() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)


func _render_title_and_story() -> void:
	_clear()

	var scrolling := state == STATE_STORY_SCROLL or state == STATE_STORY
	if scrolling:
		main.translate_graphics(scroll_offset_x, 0)

	if state <= STATE_TITLE or state == STATE_STORY_SCROLL:
		main.title.draw(main, 128, 192)
		menu.render()

	if scrolling:
		for i in STORY.size():
			main.draw_text(STORY[i], Main.DISPLAY_WIDTH + 96, (i << 6) + 96,
				Main.FONT_GRAY)
		main.pop_graphics()


func _render_soldiers() -> void:
	_clear()

	var offset := soldier_set << 1
	main.soldiers[offset + 0].draw(main, upper_soldier_x, UPPER_SOLDIER_Y)
	main.soldiers[offset + 1].draw(main, lower_soldier_x, LOWER_SOLDIER_Y)


func _render_typing() -> void:
	_clear()

	var offset := soldier_set << 1
	main.soldiers[offset + 0].draw(main, UPPER_SOLDIER_X1, UPPER_SOLDIER_Y)
	main.soldiers[offset + 1].draw(main, LOWER_SOLDIER_X1, LOWER_SOLDIER_Y)

	var names: Array = NAMES[soldier_set]
	for i in names_index:
		main.draw_text(names[i], NAME_XYS[i].x, NAME_XYS[i].y, Main.FONT_GRAY)
	if names_index != names.size():
		main.draw_text(names[names_index], NAME_XYS[names_index].x,
			NAME_XYS[names_index].y, Main.FONT_GRAY, name_length)


func render() -> void:
	match state:
		STATE_FADE_IN, STATE_EXPLOSION, STATE_START_GAME, STATE_OPTIONS, \
		STATE_TITLE, STATE_STORY_SCROLL, STATE_STORY:
			_render_title_and_story()
		STATE_SOLDIERS_ENTER:
			_render_soldiers()
		STATE_TYPING, STATE_NAMES_PAUSE, STATE_FADE_OUT:
			_render_typing()
		STATE_DONE:
			_clear()
