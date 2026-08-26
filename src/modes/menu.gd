# Port of jackal.Menu.
#
# The selection icon does not snap between entries: it accelerates for half the
# distance and decelerates for the other half over SELECT_TIME ticks.
class_name Menu
extends RefCounted

const ICON_JEEP := 0
const ICON_GRENADE := 1
const ICON_MISSILE := 2
const ICON_EXPLOSION := 3
const ICON_TANK := 4

const SELECT_STATE_STATIONARY := 0
const SELECT_STATE_ACCELERATING := 1
const SELECT_STATE_DECELERATING := 2

const SELECT_TIME := 8
const I_SELECT_TIME2 := 1.0 / float(SELECT_TIME * SELECT_TIME)

var main: Main
var options: Array
var input: HumanInput
var x: float
var y: float
var icon_y: float
var selected_index: int
var menu_listener = null
var icon: int
var button_released: bool
var select_state: int = SELECT_STATE_STATIONARY
var icon_vy: float
var icon_mid_y: float
var icon_a: float
var target_y: float
var selection_made: bool
var input_enabled: bool = true
var konami_code_test: bool


func _init(p_x: float, p_y: float, p_main: Main, p_selected_index: int,
		p_icon: int, p_menu_listener, p_options: Array) -> void:
	x = p_x
	y = p_y
	main = p_main
	selected_index = p_selected_index
	icon = p_icon
	menu_listener = p_menu_listener
	options = p_options

	input = p_main.input
	icon_y = 16 + (selected_index << 6)

	input.clear_key_pressed_record()


func enable_konami_code_test() -> void:
	konami_code_test = true


func set_input_enabled(p_input_enabled: bool) -> void:
	input_enabled = p_input_enabled


func _move_icon() -> void:
	if menu_listener != null:
		menu_listener.selection_changed(selected_index)
	select_state = SELECT_STATE_ACCELERATING
	target_y = 16 + (selected_index << 6)
	icon_mid_y = 0.5 * (icon_y + target_y)
	icon_vy = 0
	icon_a = 2 * (target_y - icon_y) * I_SELECT_TIME2


func update() -> void:
	if konami_code_test:
		main.konami_code.update()
		# While the code is being entered, swallow the inputs so that the
		# gun/grenade steps do not also pick a menu entry.
		if main.konami_code.getting_close() \
				or (main.konami_code.enabled and not main.konami_code.key_released):
			return

	if not (input.is_down() or input.is_up() or input.is_shoot() or input.is_fire()):
		button_released = true

	if button_released:
		if input.is_down():
			button_released = false
			if input_enabled and not selection_made \
					and selected_index != options.size() - 1:
				selected_index += 1
				_move_icon()
		elif input.is_up():
			button_released = false
			if input_enabled and not selection_made and selected_index != 0:
				selected_index -= 1
				_move_icon()
		elif input.is_fire() or input.is_shoot():
			button_released = false
			if not selection_made and input_enabled:
				selection_made = true
				if menu_listener != null:
					menu_listener.option_selected(selected_index)

	if not selection_made and input.is_enter() and input_enabled:
		selection_made = true
		if menu_listener != null:
			menu_listener.option_selected(selected_index)

	match select_state:
		SELECT_STATE_ACCELERATING:
			icon_vy += icon_a
			icon_y += icon_vy
			if icon_a > 0:
				if icon_y >= icon_mid_y:
					select_state = SELECT_STATE_DECELERATING
			else:
				if icon_y <= icon_mid_y:
					select_state = SELECT_STATE_DECELERATING
		SELECT_STATE_DECELERATING:
			icon_vy -= icon_a
			icon_y += icon_vy
			if icon_a > 0:
				if icon_y >= target_y or icon_vy <= 0:
					select_state = SELECT_STATE_STATIONARY
					icon_y = target_y
			else:
				if icon_y <= target_y or icon_vy >= 0:
					select_state = SELECT_STATE_STATIONARY
					icon_y = target_y


func render() -> void:
	main.translate_graphics(x, y)
	for i in range(options.size() - 1, -1, -1):
		main.draw_text(options[i], 0, i << 6, Main.FONT_GRAY)

	match icon:
		ICON_JEEP:
			main.draw_rotated(main.players[0][0], -72, icon_y, 0)
		ICON_GRENADE:
			main.draw_rotated(main.grenade, -64, icon_y, 0)
		ICON_MISSILE:
			main.draw_rotated(main.player_missile, -64, icon_y, 0)
		ICON_EXPLOSION:
			main.draw_rotated(main.explosions[0], -64, icon_y, 0)
		ICON_TANK:
			main.draw_rotated(main.boss_blue_tanks[0][0], -72, icon_y, 0)
	main.pop_graphics()
