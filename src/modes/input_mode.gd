# Port of jackal.InputMode: the control-remapping screen. Each prompt is
# answered by pressing the key or pad button to bind, and a binding already in
# use is simply ignored. Pressing a pad button binds grenade and gun and skips
# the four direction prompts.
#
# Beyond the original, which had no way out of this screen: Escape cancels and
# restores the mapping as it was on entry, instead of being bound as a control.
# The binding each prompt is about to replace is shown too, so it is clear what
# is being changed. Without these it is easy to walk in, try to back out with
# Escape, and leave with the jeep bound to nonsense.
#
# Nor did the original have a second player: InputMode.new(1) remaps the
# second's mapping (Modes.INPUT_2). A key the other player has bound is
# ignored, as one already in use by this player always was, and the side a
# key was pressed on is kept for the weapons -- the second player's defaults
# are the right Alt and Ctrl, which only HumanInput.key_event tells apart.
class_name InputMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_READING := 1
const STATE_READ_FADE := 2
const STATE_FADE_OUT := 3
const STATE_DONE := 4

const FADE_TIME := 11
const I_FADE_TIME := 1.0 / FADE_TIME

const NAMES: Array[String] = [
	"throw grenade",
	"fire machine gun",
	"up",
	"down",
	"left",
	"right",
]

static var NAME_XS: PackedFloat32Array = PackedFloat32Array()

var main: Main
var player_index: int
var button_mapping: ButtonMapping
# The other player's mapping, whose keys cannot be bound here.
var other_mapping: ButtonMapping
var state: int = STATE_FADE_IN
var name_index: int
var delay: int
var controller_pressed: bool
var cancelled: bool
# The mapping as it was on entry, restored if the remap is cancelled.
var entry_mapping: ButtonMapping


static func _static_init() -> void:
	NAME_XS.resize(NAMES.size())
	for i in NAMES.size():
		NAME_XS[i] = (Main.DISPLAY_WIDTH - (NAMES[i].length() << 5)) / 2.0


func _init(p_player_index: int = 0) -> void:
	player_index = p_player_index


func init(p_main: Main) -> void:
	main = p_main
	button_mapping = p_main.button_mapping_2 if player_index == 1 else p_main.button_mapping
	other_mapping = p_main.button_mapping if player_index == 1 else p_main.button_mapping_2
	entry_mapping = button_mapping.duplicate_mapping()
	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_READING
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		if cancelled:
			# Nothing was written to disk, so restoring the live mapping is all
			# it takes. Back to Options, where this screen was entered from.
			button_mapping.copy_from(entry_mapping)
			main.request_mode(Modes.OPTIONS)
		else:
			button_mapping.save()
			main.request_mode(Modes.INTRO)


# Fed from Main._input.
func input_event(event: InputEvent) -> void:
	if state != STATE_READING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_cancel()
			return
		if other_mapping.claims_at(event.keycode, event.location):
			return
		_key_pressed(event.keycode, event.location)
	elif event is InputEventJoypadButton and event.pressed:
		_button_pressed(event.device, event.button_index)


func _button_pressed(device: int, button_index: int) -> void:
	controller_pressed = true
	button_mapping.controller = true
	button_mapping.controller_index = device

	match name_index:
		0:
			button_mapping.controller_grenade = button_index
			# Never leave both actions on the same button.
			if button_mapping.controller_grenade == button_mapping.controller_gun:
				button_mapping.controller_gun = \
					1 if button_mapping.controller_grenade == 0 else 0
			_advance()
		1:
			if button_mapping.controller_grenade != button_index:
				button_mapping.controller_gun = button_index
				_advance()


func _key_pressed(keycode: int, location: KeyLocation) -> void:
	var bm := button_mapping
	match name_index:
		0:
			bm.key_grenade = keycode
			bm.key_grenade_location = location
			_advance()
		1:
			if bm.key_grenade != keycode:
				bm.gun_key_mapped = true
				bm.key_gun = keycode
				bm.key_gun_location = location
				_advance()
		2:
			if bm.key_grenade != keycode and bm.key_gun != keycode:
				bm.key_up = keycode
				_advance()
		3:
			if bm.key_grenade != keycode and bm.key_gun != keycode \
					and bm.key_up != keycode:
				bm.key_down = keycode
				_advance()
		4:
			if bm.key_grenade != keycode and bm.key_gun != keycode \
					and bm.key_up != keycode and bm.key_down != keycode:
				bm.key_left = keycode
				_advance()
		5:
			if bm.key_grenade != keycode and bm.key_gun != keycode \
					and bm.key_up != keycode and bm.key_down != keycode \
					and bm.key_left != keycode:
				bm.key_right = keycode
				_advance()


func _cancel() -> void:
	cancelled = true
	state = STATE_FADE_OUT
	main.play_sound_always(main.bullet_hit_sound)
	main.start_fade(true, self)


# What the current prompt is about to replace. The gun falls back to the
# original's Z/Y/W/K set until it is mapped, and Z is the one shown.
func _current_binding() -> String:
	var bm := button_mapping
	var code: Key = bm.key_grenade
	var location := bm.key_grenade_location
	match name_index:
		1:
			code = bm.key_gun
			location = bm.key_gun_location
		2, 3, 4, 5:
			code = [bm.key_up, bm.key_down, bm.key_left, bm.key_right][name_index - 2]
			location = KEY_LOCATION_UNSPECIFIED
	var side := ""
	match location:
		KEY_LOCATION_LEFT: side = "left "
		KEY_LOCATION_RIGHT: side = "right "
	return side + OS.get_keycode_string(code)


static func _centered_x(text: String) -> float:
	return (Main.DISPLAY_WIDTH - (text.length() << 5)) / 2.0


func _advance() -> void:
	main.play_sound_always(main.bullet_hit_sound)
	state = STATE_READ_FADE
	delay = FADE_TIME


func update() -> void:
	if state != STATE_READ_FADE:
		return
	delay -= 1
	if delay == 0:
		name_index += 1
		if name_index == NAMES.size() or (controller_pressed and name_index == 2):
			state = STATE_FADE_OUT
			main.start_fade(true, self)
		else:
			state = STATE_READING


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	var who := "player %d" % (player_index + 1)
	main.draw_text(who, _centered_x(who), 208, Main.FONT_GRAY)
	main.draw_text("On either your keyboard", 144, 304, Main.FONT_GRAY)
	main.draw_text("or gamepad, press:", 224, 368, Main.FONT_GRAY)

	main.draw_text("escape cancels", _centered_x("escape cancels"), 800,
		Main.FONT_GRAY)

	if state == STATE_FADE_OUT or name_index >= NAMES.size():
		return

	var now := "now " + _current_binding()
	if state == STATE_READ_FADE:
		main.draw_text_alpha(NAMES[name_index], NAME_XS[name_index], 464,
			Main.FONT_ORANGE_GRAY, delay * I_FADE_TIME)
		main.draw_text_alpha(now, _centered_x(now), 560, Main.FONT_GRAY,
			delay * I_FADE_TIME)
	else:
		main.draw_text(NAMES[name_index], NAME_XS[name_index], 464,
			Main.FONT_ORANGE_GRAY)
		main.draw_text(now, _centered_x(now), 560, Main.FONT_GRAY)
