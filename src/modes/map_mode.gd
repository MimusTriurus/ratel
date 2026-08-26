# Port of jackal.MapMode: the between-stage map. The jeep creeps up to the next
# stage marker while the rescued prisoners are cashed in at 2000 points each.
class_name MapMode
extends RefCounted

const STATE_FADE_IN := 0
const STATE_PAUSED := 1
const STATE_MOVING := 2
const STATE_PAUSED_2 := 3
const STATE_FADE_OUT := 4
const STATE_DONE := 5

const PAUSE_DELAY := 91
const SOLDIER_DELAY := 14
const PAUSE_DELAY_2 := 3 * 91

const JEEP_SPEED := 2.25

const JEEP_YS: Array[int] = [759, 631, 503, 379, 259]

var main: Main
var state: int = STATE_FADE_IN
var delay: int = PAUSE_DELAY
var jeep_y: float = 868
var soldier_delay: int = SOLDIER_DELAY
var target_jeep_y: float


func init(p_main: Main) -> void:
	main = p_main
	target_jeep_y = JEEP_YS[p_main.stage_index]
	p_main.start_fade(false, self)


func fade_completed() -> void:
	if state == STATE_FADE_IN:
		state = STATE_PAUSED
	else:
		state = STATE_DONE
		main.advance_stage_index()
		main.request_mode(Modes.GAME)


func update() -> void:
	match state:
		STATE_PAUSED:
			delay -= 1
			if delay == 0:
				state = STATE_MOVING
		STATE_MOVING:
			if main.friendly_soldiers_picked_up > 0:
				soldier_delay -= 1
				if soldier_delay == 0:
					soldier_delay = SOLDIER_DELAY
					main.friendly_soldiers_picked_up -= 1
					main.add_points(2000)
			jeep_y -= JEEP_SPEED
			if jeep_y <= target_jeep_y:
				jeep_y = target_jeep_y
				if main.friendly_soldiers_picked_up == 0:
					state = STATE_PAUSED_2
					delay = PAUSE_DELAY_2
		STATE_PAUSED_2:
			delay -= 1
			if delay == 0:
				# Wait for the map jingle to finish before fading out.
				if main.is_song_playing():
					delay = 1
				else:
					state = STATE_FADE_OUT
					main.start_fade(true, self)


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	if state == STATE_DONE:
		return

	main.map.draw(main, 124, 92)

	main.draw_scaled(main.players[0][2], 288, jeep_y, 0.5)

	main.draw(main.friendly_soldiers[0][8], 552, 344)

	main.draw_text("1P SCORE", 416, 256, Main.FONT_GRAY)
	main.draw_text(main.score_str, 704, 256, Main.FONT_GRAY)
	main.draw_number(main.friendly_soldiers_picked_up, 2, 608, 352, Main.FONT_GRAY)
