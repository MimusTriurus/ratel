# The controls, taught as they are first wanted, over the jeep that wants
# them (level3d_preview.gd, _update_hints): small plates with the keys in
# frames and a word, in the preview's font (Level3DFont), one at a time a player, gone once the
# player has done what they say. Nothing stops or darkens the game for them.
#
#     [W][A][S][D] MOVE        the BTR handed over by the Chinook
#     [LMB] FIRE               an enemy soldier or tank within a quarter more
#                              than the gun's reach
#     [RMB] ROCKET             a POW building or a gate within the launcher's
#                              reach and the BTR turned to it, or a round
#                              thudding on one (Level3DGun.dull): the gun
#                              cannot open them
#
# The keys are the ones bound now, for the firing mode on (the mouse's buttons
# when it aims, the keys when it does not), and the second player's his own
# (level3d_preview.gd, _hint_keys). What each hint asks and when it is done is
# the preview's; this only draws them. Off in the menu (Level3DSettings.
# hud_hints), and each shown until done once a run of the preview -- R does
# not bring them back.
#
# On the HUD's layer, at the HUD's size, as the pops are (Level3DScorePops):
# the same size wherever the jeep is in the tilted frame.
class_name Level3DHints
extends Control

const KEY_GLYPH := Level3DFont.CAPTION  # a key's letters at 100%
const WORD_GLYPH := Level3DFont.SMALL   # the word's
const KEY_PAD := Vector2(8, 6)  # round a key's letters, frame px at 100%
const KEY_GAP := 6.0
const WORD_GAP := 12.0
const HEIGHT := 2.6             # metres over the jeep's feet the plate's foot is
const FADE_IN := 0.25
const FADE_OUT := 0.4
const KEY_FILL := Color(0.0, 0.0, 0.0, 0.75)
const RING := 2.0
const RING_LINE := 1.0

var camera: Camera3D
var scale_factor := 1.0

# The hints up: {"keys": [String], "word", "at": Callable -> Vector3, "age",
# "leaving" -- seconds since it was done, -1 while it is not}.
var _hints: Array[Dictionary] = []


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


# A hint, `keys` in frames and `word` after them, over `at.call()`; returns
# it, for `done`.
func show_hint(keys: Array, word: String, at: Callable) -> Dictionary:
	var hint := {"keys": keys, "word": word, "at": at, "age": 0.0, "leaving": -1.0}
	_hints.append(hint)
	return hint


# It is done: it fades out.
func done(hint: Dictionary) -> void:
	if hint.leaving < 0.0:
		hint.leaving = 0.0


func clear() -> void:
	_hints.clear()
	queue_redraw()


func _process(delta: float) -> void:
	for hint in _hints:
		hint.age += delta
		if hint.leaving >= 0.0:
			hint.leaving += delta
	_hints = _hints.filter(func(h: Dictionary) -> bool: return h.leaving < FADE_OUT)
	queue_redraw()


func _draw() -> void:
	texture_filter = Level3DFont.filter()
	if camera == null:
		return
	var s := scale_factor
	var kg := Level3DFont.size(KEY_GLYPH, s)
	var wg := Level3DFont.size(WORD_GLYPH, s)
	var pad := (KEY_PAD * s).round()
	var key_h := kg + pad.y * 2.0
	var ring := maxf(roundf(RING * s), 1.0)
	var line_w := maxf(roundf(RING_LINE * s), 1.0)
	for hint in _hints:
		var at: Vector3 = hint.at.call()
		if camera.is_position_behind(at):
			continue
		var alpha := clampf(hint.age / FADE_IN, 0.0, 1.0)
		if hint.leaving >= 0.0:
			alpha *= clampf(1.0 - hint.leaving / FADE_OUT, 0.0, 1.0)
		var keys: Array = hint.keys
		var word: String = hint.word
		var width := 0.0
		for k in keys:
			width += Level3DFont.width(k, kg) + pad.x * 2.0 + roundf(KEY_GAP * s)
		width += roundf(WORD_GAP * s) - roundf(KEY_GAP * s) + Level3DFont.width(word, wg)
		var foot := camera.unproject_position(at)
		var x := roundf(foot.x - width * 0.5)
		var top := roundf(foot.y - key_h)
		for k in keys:
			var key: String = k
			var box := Rect2(x, top, roundf(Level3DFont.width(key, kg)) + pad.x * 2.0, key_h)
			draw_rect(box, Color(KEY_FILL, KEY_FILL.a * alpha))
			draw_rect(box.grow(ring + line_w * 0.5), Color(0, 0, 0, alpha), false, line_w)
			draw_rect(box.grow(ring * 0.5), Color(1, 1, 1, alpha), false, ring)
			_text(key, x + pad.x, top + pad.y, kg, alpha)
			x += box.size.x + roundf(KEY_GAP * s)
		x += roundf(WORD_GAP * s) - roundf(KEY_GAP * s)
		_text(word, x, roundf(top + (key_h - wg) * 0.5), wg, alpha)


func _text(text: String, x: float, y: float, g: float, alpha: float) -> void:
	Level3DFont.draw(self, text, x, y, g, Level3DFont.WHITE, Color(1, 1, 1, alpha))
