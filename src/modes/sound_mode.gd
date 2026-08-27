# Not in the original. A submenu of options: the music bus, the effects bus and
# the gain on the bus they both feed -- see AudioSettings, which owns all three.
#
# Every other menu mode leaves the screen the moment an entry is picked, so it
# can let Menu latch its selection and never look at it again. This one toggles
# in place, so the labels carry the state and the latch is released after each
# toggle. Only "done" leaves.
class_name SoundMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_MENU := 1
const STATE_FADE_OUT := 2
const STATE_DONE := 3

const MUSIC := 0
const SOUND := 1
const VOLUME := 2
const DONE := 3

var main: Main
var input: HumanInput
var state: int = STATE_FADE_IN
var menu: Menu
var chosen: bool


func init(p_main: Main) -> void:
	main = p_main
	input = p_main.input

	menu = Menu.new(448, 512, p_main, 0, Menu.ICON_GRENADE, self, _labels())

	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_MENU
	elif state == STATE_FADE_OUT:
		state = STATE_DONE
		# Back to options rather than the title: this is a submenu of it, and
		# the other three entries are still there to be reached.
		main.request_mode(Modes.OPTIONS)


func selection_changed(_index: int) -> void:
	pass


func option_selected(p_index: int) -> void:
	var audio := main.audio
	match p_index:
		MUSIC:
			audio.music_on = not audio.music_on
			audio.apply()
		SOUND:
			audio.sound_on = not audio.sound_on
			audio.apply()
			# Something to hear the answer with, when it was just switched on.
			main.play_sound(main.pickup_sound)
		VOLUME:
			audio.step_volume()
			# Likewise: the new gain is only meaningful next to a sound.
			main.play_sound(main.pickup_sound)
		DONE:
			chosen = true
			main.play_sound(main.missile_sound)

	if p_index == DONE:
		return

	audio.save()
	_relabel()
	# Menu takes one selection and stops listening; this screen is a set of
	# switches, so it is handed back.
	menu.selection_made = false


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

	# The glyphs are a fixed 32 px wide, so a centred string starts at
	# (1024 - 32 * length) / 2.
	main.draw_text("sound", 432, 384, Main.FONT_GRAY)
	menu.render()


func _labels() -> Array:
	var audio := main.audio
	return [
		"music %s" % ("on" if audio.music_on else "off"),
		"sound %s" % ("on" if audio.sound_on else "off"),
		"volume %d" % audio.volume,
		"done",
	]


# Menu keeps the array it was handed and reads it every frame, so the entries
# are rewritten in place rather than the menu rebuilt.
func _relabel() -> void:
	var labels := _labels()
	for i in labels.size():
		menu.options[i] = labels[i]
