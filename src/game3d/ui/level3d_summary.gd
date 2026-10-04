# The mission's summary on the 3D preview, when the fourth boss tank goes
# (level3d_preview.gd, _update_banners), in place of the game's three lines
# and the count of the rescued under them:
#
#     MISSION ACCOMPLISHED!
#     [p][p][p][p][p][p][p][p][p][p][p][p][-][-][-]
#     RESCUED 19 OF 24
#     TIME 07:42
#     PRESS ANY KEY
#
#   * the title typed as jackal.MissionAccomplished types its lines, a letter
#     every TYPE_TIME with the well-done sound;
#   * then a prisoner for every one the level held (Level3DFriends.
#     prisoners_total), the rescued first, each in the colour of the player
#     who brought him in (the HUD's icons, "pow" and "pow_2"), the rest dark
#     -- left in a house, wandering, or lost with a jeep -- one every
#     ICON_TIME, the rescued with the helicopter's pickup sound: the row says
#     how many and how many not before the numbers do. Each ringed as the
#     HUD's icons are (Level3DHud.stamp_rings), thinner, ICON_RING: on the
#     dark plate the rescued's own black line was lost and the rest were grey
#     blots; the ring of the ones not rescued dimmed with them, LOST_RING;
#   * the count, all the players' together -- the row's colours say whose --
#     and the time from the BTR's handing over to the boss's end. Not the
#     score: the HUD has it on the screen under the plate;
#   * and it waits for a press (`dismiss`), any key or button -- the gun
#     alone was one more thing to know at the end -- PRESS ANY KEY
#     blinking: the game moved on to its next stage after its lines, and
#     the preview has none.
#     A press while it is still coming shows it all at once.
#
# On the HUD's layer and in its font, as the HUD is (Level3DHud), on a plate
# ringed as its icons are, white with a thin black line, across the frame
# and see-through (draw_plate, which the banners' plates are as well): the
# boss's burning wrecks show through it.
class_name Level3DSummary
extends Control

const SOUND_PATH := "res://assets/soundeffects/well_done.ogg"
const TITLE := "MISSION ACCOMPLISHED!"
const PROMPT := "PRESS ANY KEY"
const TITLE_GLYPH := 48.0
const GLYPH := 32.0
const PROMPT_GLYPH := 24.0
const ICON_HEIGHT := 64.0
const ICONS_PER_ROW := 16
const GAP := 20.0               # between the lines
const PADDING := Vector2(56, 40)
const PLATE := Color(0.0, 0.0, 0.0, 0.75)    # blended in linear light, which reads lighter than it says: the scene shows through
const RING := 3.0
const RING_LINE := 1.0
const LOST := Color(0.42, 0.42, 0.42)     # the ones not rescued, as a silhouette
const ICON_RING := 2.0          # the prisoners' white ring, px at 100%
const ICON_RING_LINE := 1.0     # the black line outside it
const LOST_RING := Level3DHud.DIM   # the alpha of the ring round one not rescued
const TYPE_TIME := MissionAccomplished.TYPE_TIME / 100.0
const ICON_TIME := 0.08
const STEP_TIME := 0.35         # between the row's end and each line under it
const BLINK := 0.5
const FADE_TIME := 0.3

# The HUD's icons, Level3DIcons.render_all's.
var icons := {}
var scale_factor := 1.0
var shown := false

var _sound: AudioStreamPlayer
var _lost_layer: Node2D
var _lost: Array[Rect2] = []    # this frame's places for the ones not rescued
var _icon_layer: Node2D         # the rescued, nearest whatever the font is drawn with
var _rescued: Array = []        # this frame's [texture, rect]
# Under them, the rings: [rescued, not], each this frame's [texture, rect,
# null] stamped in a CanvasGroup of its own, the second dimmed.
var _ring_groups: Array[CanvasGroup] = []
var _rings: Array = [[], []]
var _time := 0.0
var _closing := -1.0            # seconds since the press that closes it, -1 open
var _icons_from := 0.0          # when the row starts, the title typed
# What it says: set by `show_summary`.
var _rescued_by: Array[int] = []
var _total := 0
var _ticks := 0
var _letters_played := 0        # the title's letters and the rescued, sounded
var _rescued_played := 0


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = Level3DHud.TINT_SHADER
	var silhouette := ShaderMaterial.new()
	silhouette.shader = shader
	for i in 2:
		var group := CanvasGroup.new()
		group.self_modulate.a = 1.0 if i == 0 else LOST_RING
		var stamps := Node2D.new()
		stamps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		stamps.material = silhouette
		stamps.draw.connect(func():
			var white := maxf(roundf(ICON_RING * scale_factor), 1.0)
			var reach := white + maxf(roundf(ICON_RING_LINE * scale_factor), 1.0)
			Level3DHud.stamp_rings(stamps, _rings[i], white, reach))
		group.add_child(stamps)
		add_child(group)
		_ring_groups.append(group)
	# The ones not rescued, over the plate as grey silhouettes of the icon:
	# dimmed, the icon stayed a dark green, one of the rescued in shadow.
	_lost_layer = Node2D.new()
	_lost_layer.material = silhouette
	_lost_layer.draw.connect(func():
		var icon := icons.get("pow") as Texture2D
		if icon != null:
			for at in _lost:
				_lost_layer.draw_texture_rect(icon, at, false, LOST))
	_lost_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_lost_layer)
	_icon_layer = Node2D.new()
	_icon_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon_layer.draw.connect(func():
		for r in _rescued:
			_icon_layer.draw_texture_rect(r[0], r[1], false))
	add_child(_icon_layer)
	_sound = AudioStreamPlayer.new()
	_sound.stream = load(SOUND_PATH)
	add_child(_sound)
	visible = false


# `rescued_by` the player of each prisoner rescued, in the order they were;
# `total` every prisoner the level held; `ticks` the mission's time, logic
# ticks.
func show_summary(rescued_by: Array[int], total: int, ticks: int) -> void:
	_rescued_by = rescued_by.duplicate()
	_total = maxi(total, rescued_by.size())
	_ticks = ticks
	_time = 0.0
	_closing = -1.0
	_letters_played = 0
	_rescued_played = 0
	_icons_from = TITLE.length() * TYPE_TIME
	shown = true
	visible = true
	modulate.a = 1.0
	queue_redraw()


func clear() -> void:
	shown = false
	visible = false


# A press: all of it at once while it is still coming, and closed once it is
# all there.
func dismiss() -> void:
	if not shown or _closing >= 0.0:
		return
	if _time < _done_at():
		_time = _done_at()
		_letters_played = TITLE.length()
		_rescued_played = _rescued_by.size()
	else:
		_closing = 0.0


func _done_at() -> float:
	return _icons_from + _total * ICON_TIME + STEP_TIME * 3.0


func _process(delta: float) -> void:
	if not shown:
		return
	_time += delta
	if _closing >= 0.0:
		_closing += delta
		modulate.a = clampf(1.0 - _closing / FADE_TIME, 0.0, 1.0)
		if _closing >= FADE_TIME:
			clear()
			return
	# A letter's sound as it is typed, then a rescued prisoner's as he comes.
	var letters := mini(int(_time / TYPE_TIME) + 1, TITLE.length())
	if letters > _letters_played:
		_sound.play()
		_letters_played = letters
	if _time >= _icons_from:
		var rescued := mini(int((_time - _icons_from) / ICON_TIME) + 1, _rescued_by.size())
		if rescued > _rescued_played:
			Level3DAudio.play("rescue_pickup")
			_rescued_played = rescued
	queue_redraw()


func _draw() -> void:
	texture_filter = Level3DFont.filter()
	_lost.clear()
	_rescued.clear()
	_rings = [[], []]
	_lost_layer.queue_redraw()
	_icon_layer.queue_redraw()
	for group in _ring_groups:
		group.get_child(0).queue_redraw()
	if not shown:
		return
	var s := scale_factor
	var tg := _whole(TITLE_GLYPH * s)
	var g := _whole(GLYPH * s)
	var pg := _whole(PROMPT_GLYPH * s)
	var gap := roundf(GAP * s)
	var icon := icons.get("pow") as Texture2D
	var icon_h := roundf(ICON_HEIGHT * s)
	var icon_w := roundf(icon.get_width() * icon_h / icon.get_height()) if icon != null else roundf(icon_h * 0.5)
	# Apart by their rings as well, which would run into one band.
	var ring_reach := maxf(roundf(ICON_RING * s), 1.0) + maxf(roundf(ICON_RING_LINE * s), 1.0)
	var icon_step := icon_w + roundf(4.0 * s) + ring_reach * 2.0
	var rows := ceili(float(_total) / ICONS_PER_ROW)
	var per_row := mini(_total, ICONS_PER_ROW)

	var lines := _lines()
	var width := maxf(Level3DFont.width(TITLE, tg), per_row * icon_step)
	for line in lines:
		width = maxf(width, _width(line, g))
	var height := tg + gap + rows * (icon_h + gap) + lines.size() * (g + gap) + pg
	var plate := Rect2((size - Vector2(width, height)) * 0.5 - PADDING * s, Vector2(width, height) + PADDING * s * 2.0)
	plate.position = plate.position.round()
	draw_plate(self, plate, s)

	var y := plate.position.y + PADDING.y * s
	# The title, typed.
	var typed := TITLE.substr(0, mini(int(_time / TYPE_TIME) + 1, TITLE.length()))
	_text(typed, roundf(size.x * 0.5 - Level3DFont.width(TITLE, tg) * 0.5), y, tg, 0, Color.WHITE)
	y += tg + gap
	if _time < _icons_from:
		return
	# The row, a prisoner every ICON_TIME.
	var come := mini(int((_time - _icons_from) / ICON_TIME) + 1, _total)
	for i in come:
		var row := i / ICONS_PER_ROW
		var in_row := mini(_total - row * ICONS_PER_ROW, ICONS_PER_ROW)
		var x0 := roundf(size.x * 0.5 - in_row * icon_step * 0.5)
		var at := Rect2(x0 + (i % ICONS_PER_ROW) * icon_step, y + row * (icon_h + gap), icon_w, icon_h)
		if i < _rescued_by.size():
			var own: Texture2D = icons.get("pow_2" if _rescued_by[i] > 0 else "pow", icon)
			if own != null:
				_rescued.append([own, at])
				_rings[0].append([own, at, null])
		elif icon != null:
			_lost.append(at)
			_rings[1].append([icon, at, null])
	y += rows * (icon_h + gap)
	# The lines under it, one every STEP_TIME once the row is in.
	var row_done := _icons_from + _total * ICON_TIME
	for i in lines.size():
		if _time < row_done + STEP_TIME * i:
			return
		var line: Array = lines[i]
		_segments(line, roundf(size.x * 0.5 - _width(line, g) * 0.5), y, g)
		y += g + gap
	if _time >= _done_at() and int((_time - _done_at()) / BLINK) % 2 == 0:
		_text(PROMPT, roundf(size.x * 0.5 - Level3DFont.width(PROMPT, pg) * 0.5), y, pg, 1, Color.WHITE)


# The lines under the row, each [[text, font, colour], ...].
func _lines() -> Array:
	var count := [["RESCUED ", 1, Color.WHITE], ["%d OF %d" % [_rescued_by.size(), _total], 0, Color.WHITE]]
	var seconds := _ticks / Engine.physics_ticks_per_second
	var time := [["TIME ", 1, Color.WHITE], ["%02d:%02d" % [seconds / 60, seconds % 60], 0, Color.WHITE]]
	return [count, time]


# A plate at `plate`'s height, at the HUD's `s`, the frame's width: dark and
# see-through, ringed in white with a thin black line either side, as the
# HUD's icons are. The ring as frames, not
# fills: a fill under the plate would show through its dark.
static func draw_plate(on: CanvasItem, plate: Rect2, s: float) -> void:
	var ring := maxf(roundf(RING * s), 1.0)
	var line_w := maxf(roundf(RING_LINE * s), 1.0)
	# Across the whole frame, its ends off it, so that only the top and the
	# bottom of the ring show: a banner, as the band the banners had, rather
	# than a box on the scene.
	var margin := (ring + line_w) * 2.0
	plate = Rect2(-margin, plate.position.y, (on as Control).size.x + margin * 2.0, plate.size.y)
	on.draw_rect(plate, PLATE)
	on.draw_rect(plate.grow(ring + line_w * 0.5), Color.BLACK, false, line_w)
	on.draw_rect(plate.grow(ring * 0.5), Color.WHITE, false, ring)
	on.draw_rect(plate.grow(-line_w * 0.5), Color.BLACK, false, line_w)


func _width(line: Array, g: float) -> float:
	var w := 0.0
	for part in line:
		w += Level3DFont.width(part[0], g)
	return w


func _segments(line: Array, x: float, y: float, g: float) -> void:
	for part in line:
		x = _text(part[0], x, y, g, part[1], part[2])


func _text(text: String, x: float, y: float, g: float, font: int, tint: Color) -> float:
	return Level3DFont.draw(self, text, x, y, g, Level3DFont.WHITE if font == 0 else Level3DFont.GRAY, tint)


static func _whole(g: float) -> float:
	return maxf(roundf(g / 8.0), 1.0) * 8.0
