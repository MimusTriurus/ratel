# The 3D preview's three moments, big in the middle of the frame and gone
# again (level3d_preview.gd, _update_banners):
#
#   * STAGE 1, while the Chinook flies the BTR in. The game shows the stage on
#     the map screen before it (MapMode); the preview has no map screen.
#   * WARNING, blinking through the boss's pan to its arena. Not the game's,
#     whose pan is the only warning; the tilted view sees further up the stage
#     than the game's frame, so the pan starts from where the arena is
#     already half in sight and says less.
#   * WELL DONE! / YOUR MISSION / ACCOMPLISHED. when the fourth boss tank goes,
#     typed out as jackal.MissionAccomplished types them -- a letter every 8
#     ticks with the well-done sound, 64 between lines -- and then how many
#     prisoners were rescued. The game shows those lines only after the last
#     stage and ends stage 1 at once; the preview has nothing after it.
#
# White on a dark band across the frame, all three. MissionAccomplished types
# in the font's orange, which on stage 1's sand -- the same orange, nearly --
# read only by its outline; the band makes any ground behind the lines the
# same dark. It is as tall as the lines, laid out with them, and does not
# blink with WARNING's text.
#
# Label, as the HUD's line and the GAME OVER banner are: the preview has no
# Main to draw the game's font through. Frozen with the tree under the
# Escape menu, so a banner is not missed behind it.
class_name Level3DBanners
extends Control

const SOUND_PATH := "res://assets/soundeffects/well_done.ogg"
const FONT_SIZE := 64
const OUTLINE := 8
const LINE_GAP := 16
const BAND := Color(0.0, 0.0, 0.0, 0.55)
const BAND_PADDING := 40       # above the first line and below the last

const STAGE_TIME := 3.0        # at most: it goes when the BTR is handed over
const FADE_TIME := 0.5
const WARNING_BLINK := 0.3     # on and off, each
const TYPE_TIME := MissionAccomplished.TYPE_TIME / 100.0
const PAUSE_TIME := MissionAccomplished.PAUSE_TIME / 100.0
const MISSION_HOLD := 5.0      # after the last line, before it fades

enum { NONE, STAGE, WARNING, MISSION }

var _kind := NONE
var _time := 0.0               # since the banner came up
var _ending := -1.0            # when it starts to fade, -1 while it holds
var _lines: Array[String] = []
var _typed := 0                # characters typed over all the lines
var _next_letter := 0.0
var _band: PanelContainer
var _box: VBoxContainer
var _labels: Array[Label] = []
var _sound: AudioStreamPlayer


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The band: the frame's width, the lines' height, centred on the frame --
	# anchored to the middle and grown both ways as the lines need.
	_band = PanelContainer.new()
	_band.anchor_left = 0.0
	_band.anchor_right = 1.0
	_band.anchor_top = 0.5
	_band.anchor_bottom = 0.5
	_band.grow_vertical = Control.GROW_DIRECTION_BOTH
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BAND
	style.content_margin_top = BAND_PADDING
	style.content_margin_bottom = BAND_PADDING
	_band.add_theme_stylebox_override("panel", style)
	add_child(_band)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", LINE_GAP)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band.add_child(_box)
	_sound = AudioStreamPlayer.new()
	_sound.stream = load(SOUND_PATH)
	add_child(_sound)
	# Hidden until a banner comes: only _show hides it, and with the STAGE
	# banner off, or a run started on the ground, nothing calls that, which
	# left the empty band, its padding tall, across the middle of the frame.
	_show()


func clear() -> void:
	_kind = NONE
	_lines.clear()
	_show()


func stage(number: int) -> void:
	_start(STAGE, ["STAGE %d" % number] as Array[String])


# The STAGE banner's end: fades from now, if it is still up.
func stage_over() -> void:
	if _kind == STAGE and _ending < 0.0:
		_ending = _time


func warning() -> void:
	_start(WARNING, ["WARNING"] as Array[String])
	Level3DAudio.play("warning")


func warning_over() -> void:
	if _kind == WARNING:
		clear()


func mission(rescued: int) -> void:
	var lines: Array[String] = []
	lines.assign(MissionAccomplished.MESSAGES)
	lines.append("RESCUED %d" % rescued)
	_start(MISSION, lines)
	_typed = 0
	_next_letter = TYPE_TIME


func _start(kind: int, lines: Array[String]) -> void:
	_kind = kind
	_lines = lines
	_time = 0.0
	_ending = -1.0
	_typed = _letters()
	_show()


func _letters() -> int:
	var n := 0
	for line in _lines:
		n += line.length()
	return n


func _process(delta: float) -> void:
	if _kind == NONE:
		return
	_time += delta
	match _kind:
		STAGE:
			if _ending < 0.0 and _time >= STAGE_TIME:
				_ending = _time
		MISSION:
			_type()
	if _ending >= 0.0 and _time >= _ending + FADE_TIME:
		clear()
		return
	_show()


# MissionAccomplished.update: a letter at a time, the sound with each, and a
# pause at the end of every line.
func _type() -> void:
	var total := _letters()
	while _typed < total and _time >= _next_letter:
		_typed += 1
		_sound.play()
		_next_letter += TYPE_TIME
		var end := 0
		for line in _lines:
			end += line.length()
			if end == _typed:
				_next_letter += PAUSE_TIME - TYPE_TIME
				break
	if _typed == total and _ending < 0.0 and _time >= _next_letter + MISSION_HOLD:
		_ending = _time


func _show() -> void:
	while _labels.size() < _lines.size():
		var label := Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", FONT_SIZE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", OUTLINE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_box.add_child(label)
		_labels.append(label)
	var left := _typed
	for i in _labels.size():
		var label := _labels[i]
		label.visible = i < _lines.size()
		if not label.visible:
			continue
		var line := _lines[i]
		# The whole line laid out and the rest hidden: a centred line cut to
		# what is typed would re-centre, and jump, with every letter.
		label.text = line
		label.visible_characters = clampi(left, 0, line.length())
		left -= line.length()
	# The lines' height from the start, typed or not, so the band does not
	# grow as they come.
	# Only the height from the lines: reset_size() would shrink the width to
	# theirs as well, off the anchors' full frame.
	_band.visible = not _lines.is_empty()
	var half := _band.get_combined_minimum_size().y * 0.5
	_band.offset_left = 0.0
	_band.offset_right = 0.0
	_band.offset_top = -half
	_band.offset_bottom = half
	var alpha := 1.0
	if _ending >= 0.0:
		alpha = clampf(1.0 - (_time - _ending) / FADE_TIME, 0.0, 1.0)
	modulate.a = alpha
	_box.modulate.a = 0.0 if _kind == WARNING and int(_time / WARNING_BLINK) % 2 == 1 else 1.0
