# Port of jackal.HardEndingMode.
#
# The hard-mode ending: a congratulations card, then one card per crew member,
# then a scrolling credits roll, then the jeep drives across revealing the
# final score.
class_name HardEndingMode
extends RefCounted

const STATE_TYPING := 0
const STATE_PAUSED := 1
const STATE_FADE_OUT := 2
const STATE_FADE_IN := 3
const STATE_CREDITS := 4
const STATE_FINAL_SCORE_FADE_IN := 5
const STATE_FINAL_SCORE_JEEP := 6
const STATE_FINAL_SCORE := 7
const STATE_FINAL_SCORE_FADE_OUT := 8
const STATE_DONE := 9

const CARDS: Array = [
	["Congratulations!!!",
	 "",
	 "Missing for years, but",
	 "never forgotten, the",
	 "men that you brought home",
	 "thank you. ",
	 "",
	 "You have demonstrated the",
	 "level of courage, cunning",
	 "and ferocity of a",
	 "wild jackal."],

	["Having proven his driving",
	 "skills out in the field,",
	 "he returned to civilian",
	 "life and his one true",
	 "love: IndyCar racing."],

	["Having accomplished his",
	 "mission, the finest",
	 "sharpshooter in the",
	 "history of the service",
	 "retired to Thailand where",
	 "he discovered a talent",
	 "for stick fighting."],

	["Having faced countless",
	 "missions against a",
	 "seemingly unstoppable",
	 "force, he left the",
	 "service and he ultimately",
	 "reinvented himself as a",
	 "Hollywood stunt driver."],

	["After commanding this",
	 "mission, his engaging war",
	 "stories inspired an",
	 "award-winning series of",
	 "video games that are",
	 "enjoyed by players",
	 "worldwide to this day."],
]

const NAMES: Array[String] = [
	"Sergeant Quint (Driver)",
	"Lieutenant Bob (Gunner)",
	"Corporal Grey (Driver)",
	"Colonel Decker (Gunner)",
]

# Which large soldier portrait goes with each name.
const NAME_PORTRAITS: Array[int] = [2, 1, 3, 0]

const CREDITS: Array[String] = [
	"programmed by",
	"michael birken",
	"",

	"inspired by",
	"`jackal\" for the",
	"nintendo entertainment system",
	"and the brilliant works of",
	"konami",
	"",

	"based on graphics designed by",
	"shimoide",
	"satoh",
	"",

	"adopted music by",
	"sakamoto",
	"fujio",
	"",

	"based on characters created by",
	"fujiwara",
	"yoshimoto",
	"maruo",
	"",

	"based on code by",
	"hori",
	"yanagisawa",
	"",

	"presented by",
	"meatfighter.com",
	"",

	"thanks for playing",
	"you are a super player!!!",
]

const TYPE_DELAY := 11
const PAUSE_DELAY := 1 * 91
const CREDITS_TIME := 45 * 91

static var NAME_XS: PackedInt32Array = PackedInt32Array()
static var CARD0_Y: float = 0.0
static var CREDITS_HEIGHT: int = 0
static var CREDITS_SPEED: float = 0.0

var final_score: String
var final_score_x: float

var main: Main
var input: HumanInput
var state: int = STATE_TYPING
var line_index: int
var line_length: int
var card_index: int
var delay: int = TYPE_DELAY
var credits_y: float = Main.DISPLAY_HEIGHT
var jeep_x: float = -50
var rumble: int


static func _static_init() -> void:
	NAME_XS.resize(NAMES.size())
	for i in NAMES.size():
		NAME_XS[i] = (Main.DISPLAY_WIDTH - (NAMES[i].length() << 5)) >> 1

	CARD0_Y = float((Main.DISPLAY_HEIGHT
		- ((((CARDS[0] as Array).size() << 1) - 1) << 5)) >> 1)

	# Blank lines act as paragraph breaks and take extra vertical space.
	var indent := false
	var y := 0
	for i in CREDITS.size():
		if not indent:
			y += 16
		indent = CREDITS[i].length() > 0
		if not indent:
			y += 32
		y += 32
	CREDITS_HEIGHT = y

	CREDITS_SPEED = (Main.DISPLAY_HEIGHT + CREDITS_HEIGHT) / float(CREDITS_TIME)


func init(p_main: Main) -> void:
	main = p_main
	input = p_main.input

	final_score = "final score: " + p_main.score_str
	final_score_x = float((Main.DISPLAY_WIDTH - (final_score.length() << 5)) >> 1)


func _update_typing() -> void:
	delay -= 1
	if delay != 0:
		return
	var card: Array = CARDS[card_index]
	if line_index == card.size():
		state = STATE_PAUSED
		delay = PAUSE_DELAY
	elif line_length == (card[line_index] as String).length():
		line_length = 0
		line_index += 1
		delay = TYPE_DELAY
	else:
		line_length += 1
		delay = TYPE_DELAY


func _update_paused() -> void:
	delay -= 1
	if delay == 0:
		state = STATE_FADE_OUT
		main.start_fade(true, self)


func _update_credits() -> void:
	credits_y -= CREDITS_SPEED
	if credits_y < -(32 + CREDITS_HEIGHT):
		state = STATE_FINAL_SCORE_FADE_IN
		main.start_fade(false, self)


func _update_final_score_jeep() -> void:
	if jeep_x < Main.DISPLAY_WIDTH + 50:
		jeep_x += Player.SPEED
	else:
		state = STATE_FINAL_SCORE
		input.clear_key_pressed_record()


func _update_final_score() -> void:
	if input.is_fire() or input.is_shoot() or input.is_enter():
		state = STATE_FINAL_SCORE_FADE_OUT
		main.stop_song()
		main.start_fade(true, self)


func fade_completed() -> void:
	if state == STATE_FINAL_SCORE_FADE_OUT:
		state = STATE_DONE
		main.request_mode(Modes.INTRO)
	elif state == STATE_FINAL_SCORE_FADE_IN:
		state = STATE_FINAL_SCORE_JEEP
	elif state == STATE_FADE_OUT:
		line_index = 0
		line_length = 0
		card_index += 1
		if card_index == CARDS.size():
			state = STATE_CREDITS
		else:
			state = STATE_FADE_IN
			main.start_fade(false, self)
	else:
		state = STATE_TYPING
		delay = TYPE_DELAY


func update() -> void:
	match state:
		STATE_TYPING:
			_update_typing()
		STATE_PAUSED:
			_update_paused()
		STATE_CREDITS:
			_update_credits()
		STATE_FINAL_SCORE_JEEP:
			_update_final_score_jeep()
		STATE_FINAL_SCORE:
			_update_final_score()


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	if state == STATE_DONE:
		return

	if state >= STATE_FINAL_SCORE_FADE_IN:
		_render_final_score()
	elif state == STATE_CREDITS:
		_render_credits()
	elif card_index == 0:
		_render_card(96, CARD0_Y)
	else:
		main.soldiers[NAME_PORTRAITS[card_index - 1]].draw(main, 368, 32)
		main.draw_text(NAMES[card_index - 1], NAME_XS[card_index - 1], 384,
			Main.FONT_GRAY)
		_render_card(96, 480)


func _render_card(x: float, y0: float) -> void:
	var card: Array = CARDS[card_index]
	for i in line_index:
		main.draw_text(card[i], x, y0 + (i << 6), Main.FONT_GRAY)
	if line_index != card.size():
		main.draw_text(card[line_index], x, y0 + (line_index << 6),
			Main.FONT_GRAY, line_length)


func _render_credits() -> void:
	main.translate_graphics(0, credits_y)
	var indent := false
	var y := 0
	for i in CREDITS.size():
		main.draw_text(CREDITS[i], 64 if indent else 32, y,
			Main.FONT_GRAY if indent else Main.FONT_ORANGE_GRAY)
		if not indent:
			y += 16
		indent = CREDITS[i].length() > 0
		if not indent:
			y += 32
		y += 32
	main.pop_graphics()


func _render_final_score() -> void:
	main.draw_text("THE END", 400, 432, Main.FONT_ORANGE_GRAY)

	if state == STATE_FINAL_SCORE:
		main.draw_text(final_score, final_score_x, 496, Main.FONT_GRAY)
	elif state == STATE_FINAL_SCORE_JEEP:
		# The jeep "wipes" the score into view as it drives across.
		if jeep_x > 0:
			main.set_clip(0, 494, jeep_x, 38)
			main.draw_text(final_score, final_score_x, 496, Main.FONT_GRAY)
			main.clear_clip()

		rumble += 1
		if rumble == 17:
			rumble = 0
		main.draw_vehicle(main.players[0], jeep_x, 512 + Player.RUMBLE[rumble], 0)
