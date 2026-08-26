# Port of jackal.InputMode: the control-remapping screen. Each prompt is
# answered by pressing the key or pad button to bind, and a binding already in
# use is simply ignored. Pressing a pad button binds grenade and gun and skips
# the four direction prompts.
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
var button_mapping: ButtonMapping
var state: int = STATE_FADE_IN
var name_index: int
var delay: int
var controller_pressed: bool


static func _static_init() -> void:
	NAME_XS.resize(NAMES.size())
	for i in NAMES.size():
		NAME_XS[i] = (Main.DISPLAY_WIDTH - (NAMES[i].length() << 5)) / 2.0


func init(p_main: Main) -> void:
	main = p_main
	button_mapping = p_main.button_mapping
	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_READING
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		button_mapping.save()
		main.request_mode(Modes.INTRO)


# Fed from Main._input.
func input_event(event: InputEvent) -> void:
	if state != STATE_READING:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_key_pressed(event.keycode)
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


func _key_pressed(keycode: int) -> void:
	var bm := button_mapping
	match name_index:
		0:
			bm.key_grenade = keycode
			_advance()
		1:
			if bm.key_grenade != keycode:
				bm.gun_key_mapped = true
				bm.key_gun = keycode
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

	main.draw_text("On either your keyboard", 144, 304, Main.FONT_GRAY)
	main.draw_text("or gamepad, press:", 224, 368, Main.FONT_GRAY)

	if state == STATE_FADE_OUT or name_index >= NAMES.size():
		return

	if state == STATE_READ_FADE:
		main.draw_text_alpha(NAMES[name_index], NAME_XS[name_index], 464,
			Main.FONT_ORANGE_GRAY, delay * I_FADE_TIME)
	else:
		main.draw_text(NAMES[name_index], NAME_XS[name_index], 464,
			Main.FONT_ORANGE_GRAY)
