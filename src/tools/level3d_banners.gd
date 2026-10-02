# The 3D preview's moments, big in the middle of the frame and gone again
# (level3d_preview.gd, _update_banners and _game_over):
#
#   * STAGE 1, while the Chinook flies the BTR in. The game shows the stage on
#     the map screen before it (MapMode); the preview has no map screen.
#   * WARNING, blinking through the boss's pan to its arena. Not the game's,
#     whose pan is the only warning; the tilted view sees further up the stage
#     than the game's frame, so the pan starts from where the arena is
#     already half in sight and says less.
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

const GLYPH := 48.0             # at 100%, as the summary's title
const STAGE_TIME := 3.0         # at most: it goes when the BTR is handed over
const GAME_OVER_TIME := 3.0
const FADE_TIME := 0.5
const WARNING_BLINK := 0.3      # on and off, each
const WARNING_COLOUR := Color(1.0, 0.32, 0.26)

enum { NONE, STAGE, WARNING, GAME_OVER }

var scale_factor := 1.0

var _kind := NONE
var _text := ""
var _time := 0.0                # since the banner came up
var _ending := -1.0             # when it starts to fade, -1 while it holds
var _stage_waiting := -1        # a STAGE that came under GAME OVER, -1 none


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear() -> void:
	_kind = NONE
	_stage_waiting = -1
	queue_redraw()


func stage(number: int) -> void:
	if _kind == GAME_OVER:
		_stage_waiting = number
		return
	_start(STAGE, "STAGE %d" % number)


# The STAGE banner's end: fades from now, if it is still up.
func stage_over() -> void:
	_stage_waiting = -1
	if _kind == STAGE and _ending < 0.0:
		_ending = _time


func warning() -> void:
	_start(WARNING, "WARNING")
	Level3DAudio.play("warning")


func warning_over() -> void:
	if _kind == WARNING:
		clear()


func game_over() -> void:
	_start(GAME_OVER, "GAME OVER")


func _start(kind: int, text: String) -> void:
	_kind = kind
	_text = text
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
		if waiting >= 0:
			stage(waiting)
		return
	queue_redraw()


func _draw() -> void:
	if _kind == NONE:
		return
	texture_filter = Level3DFont.filter()
	var s := scale_factor
	var g := maxf(roundf(GLYPH * s / 8.0), 1.0) * 8.0
	var width := Level3DFont.width(_text, g)
	var plate := Rect2((size - Vector2(width, g)) * 0.5 - Level3DSummary.PADDING * s,
			Vector2(width, g) + Level3DSummary.PADDING * s * 2.0)
	plate.position = plate.position.round()
	var alpha := 1.0 if _ending < 0.0 else clampf(1.0 - (_time - _ending) / FADE_TIME, 0.0, 1.0)
	modulate.a = alpha
	Level3DSummary.draw_plate(self, plate, s)
	if _kind == WARNING and int(_time / WARNING_BLINK) % 2 == 1:
		return
	var tint := WARNING_COLOUR if _kind == WARNING else Color.WHITE
	var x := roundf(size.x * 0.5 - width * 0.5)
	var y := roundf(size.y * 0.5 - g * 0.5)
	Level3DFont.draw(self, _text, x, y, g, Level3DFont.WHITE, tint)
