# Port of jackal.MissionAccomplished: types out the three end-of-stage lines,
# then ends the stage.
class_name MissionAccomplished
extends GameElement

const STATE_TYPING := 0
const STATE_PAUSED := 1
const STATE_DONE := 2

const TYPE_TIME := 8
const PAUSE_TIME := 64

const MESSAGES: Array[String] = [
	"WELL DONE!",
	"YOUR MISSION",
	"ACCOMPLISHED.",
]

var state: int = STATE_TYPING
var message_index: int
var message_length: int
var delay: int = 1


func init() -> void:
	layer = 7


func update() -> void:
	match state:
		STATE_TYPING:
			delay -= 1
			if delay == 0:
				if message_length == MESSAGES[message_index].length():
					state = STATE_PAUSED
					delay = PAUSE_TIME
				else:
					main.play_sound_always(main.well_done_sound)
					message_length += 1
					delay = TYPE_TIME
		STATE_PAUSED:
			delay -= 1
			if delay == 0:
				message_length = 0
				message_index += 1
				if message_index == 3:
					state = STATE_DONE
					game_mode.mark_stage_completed()
				else:
					state = STATE_TYPING
					delay = 1


func render() -> void:
	for i in range(message_index - 1, -1, -1):
		main.draw_text(MESSAGES[i], 832, 736 + (i << 6), Main.FONT_ORANGE)
	if message_index < 3:
		main.draw_text(MESSAGES[message_index], 832, 736 + (message_index << 6),
			Main.FONT_ORANGE, message_length)
