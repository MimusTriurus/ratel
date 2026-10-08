# The 3D preview's moments, big in the middle of the frame and gone again
# (level3d_preview.gd, _update_banners and _game_over):
#
#   * STAGE 1, while the Chinook flies the BTR in. The game shows the stage on
#     the map screen before it (MapMode); the preview has no map screen.
#   * WARNING, blinking from the boss's pan to its arena until the first of
#     it comes into the frame, the boss's name under it (Level3DBoss.NAME),
#     steady. Not the game's, whose pan is the only warning; the tilted view
#     sees further up the stage than the game's frame, so the pan starts from
#     where the arena is already half in sight and says less.
#   * GAME OVER, for GAME_OVER_TIME when every player is out and the stage
#     starts again. A STAGE that comes while it is up waits for it.
#
# The mission's end is not one of them: it has a summary of its own
# (Level3DSummary), which took the game's WELL DONE! / YOUR MISSION /
# ACCOMPLISHED. lines' place.
#
# In the preview's font (Level3DFont) on the summary's plate, a see-through band across the
# frame ringed in white with a thin black line (Level3DSummary.draw_plate):
# they used to be the system font's, the one place on the screen not in the
# game's letters. A plate round the line only was tried, and read as a box
# stood on the scene. WARNING's letters blink, its plate
# does not. Frozen with the tree under the Escape menu, so a banner is not
# missed behind it.
class_name Level3DBanners
extends Control

const GLYPH := Level3DFont.TITLE        # at 100%, as the summary's title
const STAGE_TIME := 3.0         # at most: it goes when the BTR is handed over
const GAME_OVER_TIME := 3.0
const FADE_TIME := 0.5
const WARNING_BLINK := 0.3      # on and off, each
const WARNING_COLOUR := Color(1.0, 0.32, 0.26)
const SUBTITLE := Level3DFont.SMALL     # the name under WARNING
const SUBTITLE_GAP := 0.4       # between the two lines, of the name's glyph

enum { NONE, STAGE, WARNING, GAME_OVER }

var scale_factor := 1.0

var _kind := NONE
var _text := ""
var _subtitle := ""             # under the text, "" none
var _time := 0.0                # since the banner came up
var _ending := -1.0             # when it starts to fade, -1 while it holds
var _stage_waiting := ""        # a STAGE's text that came under GAME OVER, "" none


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear() -> void:
	_kind = NONE
	_stage_waiting = ""
	queue_redraw()


# `round`: the stage's round (level3d_preview.gd, _round): STAGE 1 on the
# first, STAGE 1-2 on the second and so on.
func stage(number: int, round := 1) -> void:
	var text := "STAGE %d" % number if round <= 1 else "STAGE %d-%d" % [number, round]
	if _kind == GAME_OVER:
		_stage_waiting = text
		return
	_start(STAGE, text)


# The STAGE banner's end: fades from now, if it is still up.
func stage_over() -> void:
	_stage_waiting = ""
	if _kind == STAGE and _ending < 0.0:
		_ending = _time


func warning(name := "") -> void:
	_start(WARNING, "WARNING")
	_subtitle = name
	Level3DAudio.play("warning")


func warning_over() -> void:
	if _kind == WARNING:
		clear()


func game_over() -> void:
	_start(GAME_OVER, "GAME OVER")


func _start(kind: int, text: String) -> void:
	_kind = kind
	_text = text
	_subtitle = ""
	_time = 0.0
	_ending = -1.0
	queue_redraw()


func _process(delta: float) -> void:
	if _kind == NONE:
		return
	_time += delta
	if _ending < 0.0 and (_kind == STAGE and _time >= STAGE_TIME or _kind == GAME_OVER and _time >= GAME_OVER_TIME):
		_ending = _time
	if _ending >= 0.0 and _time >= _ending + FADE_TIME:
		var waiting := _stage_waiting
		clear()
		if waiting != "":
			_start(STAGE, waiting)
		return
	queue_redraw()


func _draw() -> void:
	if _kind == NONE:
		return
	texture_filter = Level3DFont.filter()
	var s := scale_factor
	var g := Level3DFont.size(GLYPH, s)
	var width := Level3DFont.width(_text, g)
	# The name under it, smaller: the plate round both, the pair in the middle.
	var sub_g := Level3DFont.size(SUBTITLE, s)
	var sub_width := Level3DFont.width(_subtitle, sub_g) if _subtitle != "" else 0.0
	var gap := roundf(sub_g * SUBTITLE_GAP) if _subtitle != "" else 0.0
	var block := Vector2(maxf(width, sub_width), g + (gap + sub_g if _subtitle != "" else 0.0))
	var plate := Rect2((size - block) * 0.5 - Level3DSummary.PADDING * s,
			block + Level3DSummary.PADDING * s * 2.0)
	plate.position = plate.position.round()
	var alpha := 1.0 if _ending < 0.0 else clampf(1.0 - (_time - _ending) / FADE_TIME, 0.0, 1.0)
	modulate.a = alpha
	Level3DSummary.draw_plate(self, plate, s)
	var top := roundf(size.y * 0.5 - block.y * 0.5)
	if _subtitle != "":
		Level3DFont.draw(self, _subtitle, roundf(size.x * 0.5 - sub_width * 0.5), top + g + gap, sub_g,
				Level3DFont.WHITE, Color.WHITE)
	if _kind == WARNING and int(_time / WARNING_BLINK) % 2 == 1:
		return
	var tint := WARNING_COLOUR if _kind == WARNING else Color.WHITE
	var x := roundf(size.x * 0.5 - width * 0.5)
	Level3DFont.draw(self, _text, x, top, g, Level3DFont.WHITE, tint)
