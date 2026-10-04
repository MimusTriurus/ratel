# Not in the original. Picks between mouse aiming (the default) and the
# original's scheme, where the grenade follows the jeep and the machine gun
# only ever fires north. Modelled on DifficultyMode, and it writes through to
# user://buttons.cfg because the choice should outlive the session.
#
# "classic" rather than "keyboard": the keyboard drives the jeep either way,
# what changes is how the weapons are aimed.
#
# The third entry, turbo (ButtonMapping.turbo), is a switch rather than a
# choice: it toggles in place, as SoundMode's entries do, and the screen is
# left by picking one of the other two.
class_name ControlsMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_MENU := 1
const STATE_FADE_OUT := 2
const STATE_DONE := 3

const MOUSE := 0
const CLASSIC := 1
const TURBO := 2

var main: Main
var input: HumanInput
var state: int = STATE_FADE_IN
var menu: Menu
var chosen: bool
var selected_index: int


func init(p_main: Main) -> void:
	main = p_main
	input = p_main.input

	menu = Menu.new(448, 512, p_main,
		MOUSE if p_main.button_mapping.mouse_aim else CLASSIC,
		Menu.ICON_JEEP, self, ["mouse", "classic", _turbo_label()])

	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_MENU
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		main.button_mapping.mouse_aim = selected_index == MOUSE
		main.button_mapping.save()
		# Back to the title, as InputMode and DifficultyMode both do.
		main.request_mode(Modes.INTRO)


func selection_changed(_index: int) -> void:
	pass


func option_selected(p_index: int) -> void:
	if p_index == TURBO:
		main.button_mapping.turbo = not main.button_mapping.turbo
		main.button_mapping.save()
		main.play_sound(main.pickup_sound)
		menu.options[TURBO] = _turbo_label()
		# Menu takes one selection and stops listening; see SoundMode.
		menu.selection_made = false
		return
	chosen = true
	selected_index = p_index
	main.play_sound(main.explode_sound2)


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

	main.draw_text("controls", 384, 384, Main.FONT_GRAY)

	# A hint for whichever entry is highlighted right now. The glyphs are a
	# fixed 32 px wide, so these are just (1024 - 32 * length) / 2.
	if menu.selected_index == MOUSE:
		main.draw_text("aim mouse, lmb gun, rmb throw", 48, 736,
			Main.FONT_ORANGE_GRAY)
	elif menu.selected_index == TURBO:
		main.draw_text("hold gun for rapid fire", 144, 736,
			Main.FONT_ORANGE_GRAY)
	else:
		main.draw_text("gun fires north, wasd aims", 96, 736,
			Main.FONT_ORANGE_GRAY)

	menu.render()


func _turbo_label() -> String:
	return "turbo %s" % ("on" if main.button_mapping.turbo else "off")
