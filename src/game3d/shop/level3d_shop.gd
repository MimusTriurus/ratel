# The shop between the 3D preview's rounds (docs/shop-plan.md, section 4):
# once the mission's summary is closed (level3d_preview.gd, _round_won), the
# stage goes to black and the shop comes up out of it, the stage paused
# under it. The players' jeeps stand on turntables in a column at each of
# the frame's edges, the first's on the left, the second's on the right,
# with what they have bought on them; between them the goods, a matrix out
# of Level3DShopCatalog:
#
#     1P $38400                 SUPPLY - ROUND 2                 2P $21300
#     [TWIN GUN ...]   TWIN GUN    LAUNCHER     RADAR     [NITRO ......]
#          |           SPARES      ARMOR        RAM CAGE              |
#       [jeep]         NITRO       MINES        AIRSTRIKE    [jeep]   |
#                      LIFE ----------------------------          o---'
#                      (the paint, to come)
#     READY                                                        READY
#
# The side says no more than the money: the lives are on LIFE's tile, the
# launcher's step on the jeep and LAUNCHER's tile, and the device's slot is
# to go.
#
# Both players shop at once, each with a cursor of his own: a frame round a
# tile in his colour, the first's outside the second's when both are on one.
# A tile says, on each player's side of it -- the first's left, the
# second's right, as their jeeps stand -- what it is to him: its price, red
# when he is short of it, OWNED, IN SLOT for the device in his slot, MAX for
# the launcher at its last step and a life past MAX_LIVES. With one player,
# one status across the tile.
#
#   * Fire buys (the gun: L, the left button, right Alt for the second
#     player, Enter and Space for the first, a pad's A); a device already
#     owned goes in the slot instead. The rocket (P, the right button, right
#     Ctrl) takes back the last of that tile bought in this visit, its price
#     back on the score. Fire on READY, under the matrix, is the player's
#     word that he is done; the round starts when every player has given it.
#   * The jeep turns on its table to show the part the tile is about
#     (SHOWS), and a part not yet his stands on it see-through, pulsing --
#     the twin gun in the single one's place, the launcher's next step in
#     the one he has. What the tile is, its name and its words, is in a box
#     across his column, over the jeep whatever the tile, so that the eye
#     does not jump, with a line from the box to the part, his or on trial,
#     which follows it as the jeep turns: straight down, or for a part low
#     on the jeep down beside it and in at a right angle, so as not to
#     cross the hull. Under the jeep is kept for the paint. With one player
#     the second's column is empty.
#   * The first player has the mouse as well: over a tile picks it, a left
#     click buys, a right click takes back -- with the title's reticle
#     (Level3DReticle) in place of the system's pointer.
#   * Escape is nothing here: the Escape menu would unpause the stage under
#     it.
#
# Its own layer, processing while the tree is paused. The jeeps are in a
# world of their own (Bay), lit by a sun of their own; the preview's _toon and
# contour reach every mesh in the tree, a SubViewport's too, so they look as
# they do on the stage. Run on its own (F6, level3d_shop.tscn) it opens with
# made-up players, to lay it out.
class_name Level3DShop
extends CanvasLayer

const TITLE := "SUPPLY"
const TITLE_GLYPH := 48.0
const GLYPH := 24.0             # the tiles' names, the players' lines
const SMALL := 16.0             # the tiles' prices, the descriptions
const PLAYER_GLYPH := 32.0
# The layout, in the HUD's 2048 x 1152 at 100%.
const TITLE_Y := 48.0
const MATRIX := Rect2(640, 150, 768, 690)   # the goods: rows 0-2 and the life's
const TILE_GAP := 16.0
const LIFE_HEIGHT := 120.0
const SIDE_WIDTH := 560.0       # each player's column at the frame's edge
const SIDE_MARGIN := 40.0
const READY_Y := 1040.0
const TILE_FILL := Color(0.0, 0.0, 0.0, 0.62)
const RING := 2.0
const CURSOR := 4.0
const POOR := Color(1.0, 0.36, 0.3)
const DIM := Color(0.62, 0.62, 0.62)
const FADE_OUT := 0.6
const FADE_IN := 0.5
const LEAVE := 0.6
const READY_ROW := 4
const LIFE_ROW := 3
const LAUNCHER_NAMES := ["GRENADE", "MISSILE", "MISSILE+", "MISSILE++"]
# How the jeep shows a tile's part, and how the line from the words, always
# over the jeep, gets to it:
#   view   degrees off nose-to-camera, towards the frame's middle; 180 is
#          the tail (VIEW if not given)
#   spot   where on the part the line ends, a fraction of its box in the
#          jeep's frame -- x the nose, y up -- its middle if not given:
#          the nitro's pipes at its tail, the ram cage's grille at its nose
#   knee   for a part low on the jeep, which a line straight down would
#          reach across the hull: the line goes down beside the jeep
#          instead, this many pixels of the 2048 frame off the table's
#          middle, towards the frame's middle, and turns in to the part
#          at its height
# The words stay where they are whatever the tile, so that the eye does not
# jump; under the jeep is the paint's (to come).
const SHOWS := {
	"twin": {"view": 25.0},
	"launcher": {"view": 150.0},
	"radar": {"view": 40.0},
	"loopholes": {"view": 80.0},
	"zip": {"view": 95.0},
	"armor": {"view": 75.0},
	"hull": {"view": 60.0, "knee": 240.0, "spot": Vector3(1.0, 0.5, 0.5)},
	"nitro": {"view": 160.0, "knee": -265.0, "spot": Vector3(0.0, 0.5, 0.5)},
	"mines": {"view": 155.0, "knee": -265.0},
	"airstrike": {"view": 30.0},
}
const VIEW := 30.0
const TURN_RATE := 3.0          # of the way to the view, per second
const GHOST := Vector2(0.25, 0.7)   # a part on trial: its transparency, pulsing between
const GHOST_PULSE := 4.0
# The tile's words: a box in the player's column, over the jeep from
# WORDS_TOP, coming up over WORDS_FADE seconds when the tile changes; the
# line from it to the part, its dot.
const WORDS_TOP := 104.0
const WORDS_PAD := 16.0
const WORDS_FADE := 0.2
const LINE := 4.0
const DOT := 8.0

enum State { CLOSED, DARKENING, OPEN, LEAVING }

# `done.call(run)` under the black once every player is ready, the run as
# bought; the shop then lifts off the stage and is gone.
var done: Callable
var scale_factor := 1.0
var settings: Level3DSettings
# Per player: null for the first (the settings' keys and the mouse), the
# second's HumanInput; and their colours and their tints.
var inputs: Array = []
var colours: Array[Color] = []
var tints: Array[Vector3] = []

var _state := State.CLOSED
var _run: Level3DRun
var _players := 1
var _cursor: Array[Vector2i] = []   # (column, row)
var _set: Array[bool] = []          # each player's READY
var _bought: Array = []             # each player's ids bought this visit, in order
var _was: Array = []                # the second player's buttons last frame, for presses
var _bay: Bay
var _text: Control
var _veil: ColorRect
var _reticle: Level3DReticle
var _fade: Tween
var _time := 0.0
var _shown: Array[String] = []      # each player's tile his words are on, and since when
var _since: Array[float] = []
var _rects := {}                  # this frame's: Vector3i(column, row, player for READY) -> Rect2


func _init() -> void:
	layer = 51
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_bay = Bay.new()
	add_child(_bay)
	_text = Control.new()
	_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.draw.connect(_draw_text)
	add_child(_text)
	_reticle = Level3DReticle.new()
	_reticle.carries_mouse = true
	_reticle.shown = false
	add_child(_reticle)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0)
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)


# On its own: two made-up players, to lay it out.
func _ready() -> void:
	if get_tree().current_scene != self:
		return
	var run := Level3DRun.new()
	run.round = 2
	for i in 2:
		var k := Level3DRun.Kit.new()
		k.score = [38400, 21300][i]
		k.lives = [3, 2][i]
		k.lives_bought = [1, 0][i]
		k.set_weapon([1, 0][i])
		k.upgrades.assign([["radar", "zip", "nitro"], ["radar"]][i])
		k.device = ["nitro", ""][i]
		run.kits.append(k)
	colours.assign([Color("5ca83e"), Color("3e8fa8")])
	tints.assign([Vector3.ZERO, Vector3(80.0, 130.0, 100.0)])
	open(run, true)


func is_open() -> bool:
	return _state != State.CLOSED


# The system's pointer hidden while it is up, the reticle in its place, for
# Level3DCrosshair, which owns the mouse mode.
func pointer_hidden() -> bool:
	return is_open()


# The shop for `run`, whose kits it sells into; from the stage, to black
# over FADE_OUT, or `at_once` straight to it (--shop, F6).
func open(run: Level3DRun, at_once := false) -> void:
	_run = run
	_players = run.kits.size()
	_cursor.clear()
	_set.clear()
	_bought.clear()
	_was.clear()
	_shown.clear()
	_since.clear()
	for i in _players:
		_cursor.append(Vector2i(0, 0))
		_set.append(false)
		_bought.append([])
		_was.append({})
		_shown.append("")
		_since.append(0.0)
	visible = true
	_state = State.DARKENING
	_kill_fade()
	if at_once:
		_veil.color.a = 1.0
		_show()
		return
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 1.0, FADE_OUT * (1.0 - _veil.color.a))
	_fade.tween_callback(_show)


func close() -> void:
	_kill_fade()
	_state = State.CLOSED
	visible = false
	_veil.color.a = 0.0
	_reticle.shown = false
	_bay.clear()


func _show() -> void:
	_fade = null
	_bay.stage(_players, tints)
	_time = 0.0
	for i in _players:
		_dress(i)
	_state = State.OPEN
	_fade = create_tween()
	_fade.tween_property(_veil, "color:a", 0.0, FADE_IN)
	_fade.tween_callback(func(): _fade = null)
	await get_tree().process_frame
	_reticle.park()
	_reticle.aim(_reticle_slot, false)


func _kill_fade() -> void:
	if _fade != null:
		_fade.kill()
		_fade = null


# Every player ready: to black, the run handed back under it, and off the
# stage again.
func _leave() -> void:
	_state = State.LEAVING
	_reticle.fire()
	Level3DAudio.play("menu_pick")
	_kill_fade()
	_fade = create_tween()
	_fade.tween_interval(Level3DReticle.FIRE)
	_fade.tween_property(_veil, "color:a", 1.0, LEAVE)
	_fade.tween_callback(func():
		_bay.clear()
		_text.queue_redraw()
		if done.is_valid():
			done.call(_run)
		_fade = create_tween()
		_fade.tween_property(_veil, "color:a", 0.0, LEAVE)
		_fade.tween_callback(close))


# ---------------------------------------------------------------------------
# What a player does

func _item(player: int) -> Dictionary:
	var at := _cursor[player]
	if at.y == READY_ROW:
		return {}
	return Level3DShopCatalog.at(at.y, at.x)


func _move(player: int, by: Vector2i) -> void:
	var at := _cursor[player]
	var to := at
	if by.y != 0:
		to.y = clampi(at.y + by.y, 0, READY_ROW)
	elif at.y < LIFE_ROW:
		to.x = clampi(at.x + by.x, 0, Level3DShopCatalog.COLUMNS - 1)
	if to != at:
		_cursor[player] = to
		Level3DAudio.play("menu_move")
		_dress(player)
		if player == 0:
			_reticle.aim(_reticle_slot)


func _fire(player: int) -> void:
	if _state != State.OPEN:
		return
	if _cursor[player].y == READY_ROW:
		_set[player] = not _set[player]
		Level3DAudio.play("menu_pick")
		if _set.all(func(r: bool): return r):
			_leave()
		return
	var it := _item(player)
	var kit: Level3DRun.Kit = _run.kits[player]
	var state := Level3DShopCatalog.state(it.id, kit)
	if state == Level3DShopCatalog.State.BUY and Level3DShopCatalog.buy(it.id, kit):
		_bought[player].append(it.id)
		_set[player] = false
		Level3DAudio.play("extra_life" if it.kind == Level3DShopCatalog.Kind.SUPPLY else "upgrade")
		if player == 0:
			_reticle.fire()
		_dress(player)
	elif state == Level3DShopCatalog.State.OWNED and it.kind == Level3DShopCatalog.Kind.DEVICE \
			and kit.device != it.id:
		kit.device = it.id
		Level3DAudio.play("menu_pick")
	else:
		Level3DAudio.play("hit_dull")


func _take_back(player: int) -> void:
	if _state != State.OPEN:
		return
	var it := _item(player)
	var bought: Array = _bought[player]
	if it.is_empty() or not bought.has(it.id):
		Level3DAudio.play("hit_dull")
		return
	bought.remove_at(bought.rfind(it.id))
	Level3DShopCatalog.refund(it.id, _run.kits[player])
	_set[player] = false
	Level3DAudio.play("menu_move")
	_dress(player)


# A player's jeep as his kit has it, the tile under his cursor on trial,
# turned to show it; his words coming up anew when the tile is another.
func _dress(player: int) -> void:
	var it := _item(player)
	var id: String = it.get("id", "ready")
	var show: Dictionary = SHOWS.get(id, {})
	_bay.dress(player, _run.kits[player], id, show.get("spot", Vector3(0.5, 0.5, 0.5)))
	_bay.turn(player, show.get("view", VIEW))
	if _shown[player] != id:
		_shown[player] = id
		_since[player] = _time


func _process(delta: float) -> void:
	if _state == State.CLOSED:
		return
	_time += delta
	_reticle.shown = _state == State.OPEN and _veil.color.a < 0.5
	if _state == State.OPEN:
		for i in _players:
			if inputs.size() > i and inputs[i] is HumanInput:
				_poll(i, inputs[i])
	_text.texture_filter = Level3DFont.filter()
	_text.queue_redraw()


# The second player's buttons, read off his HumanInput as the stage does,
# a press each time one goes down.
func _poll(player: int, input: HumanInput) -> void:
	input.snap()
	var now := {"up": input.is_up(), "down": input.is_down(), "left": input.is_left(),
			"right": input.is_right(), "gun": input.is_gun(), "rocket": input.is_grenade()}
	var was: Dictionary = _was[player]
	for name in now:
		if now[name] and not was.get(name, false):
			match name:
				"up": _move(player, Vector2i(0, -1))
				"down": _move(player, Vector2i(0, 1))
				"left": _move(player, Vector2i(-1, 0))
				"right": _move(player, Vector2i(1, 0))
				"gun": _fire(player)
				"rocket": _take_back(player)
	_was[player] = now


func _input(event: InputEvent) -> void:
	if _state == State.CLOSED:
		return
	# Nothing gets past it to the stage paused under it.
	var key := event as InputEventKey
	if key != null:
		# The second player's keys go on to his HumanInput as KeySides
		# (level3d_preview.gd) would have sent them, had this not stopped them.
		HumanInput.key_event(key)
		get_viewport().set_input_as_handled()
		if not key.pressed or key.echo or _state != State.OPEN:
			return
		var code := key.keycode
		# The arrows are the second player's with two, as on the stage.
		var arrows := _players == 1
		if code == _key("up") or arrows and code == KEY_UP:
			_reticle.keys()
			_move(0, Vector2i(0, -1))
		elif code == _key("down") or arrows and code == KEY_DOWN:
			_reticle.keys()
			_move(0, Vector2i(0, 1))
		elif code == _key("left") or arrows and code == KEY_LEFT:
			_reticle.keys()
			_move(0, Vector2i(-1, 0))
		elif code == _key("right") or arrows and code == KEY_RIGHT:
			_reticle.keys()
			_move(0, Vector2i(1, 0))
		elif code == _key("gun") or code in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			_fire(0)
		elif code == _key("rocket"):
			_take_back(0)
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		if _state == State.OPEN and _reticle.mouse_has_it():
			var at := _cell_at(_text.get_local_mouse_position())
			var now := _cursor[0]
			if at.x >= 0 and (at.y != now.y or at.y < LIFE_ROW and at.x != now.x):
				_cursor[0] = Vector2i(at.x, at.y)
				Level3DAudio.play("menu_move")
				_dress(0)
		return
	var click := event as InputEventMouseButton
	if click != null and click.pressed:
		get_viewport().set_input_as_handled()
		if _state != State.OPEN:
			return
		var at := _cell_at(_text.get_local_mouse_position())
		if at.x < 0:
			return
		_cursor[0] = Vector2i(at.x, at.y)
		_dress(0)
		if click.button_index == MOUSE_BUTTON_LEFT:
			_fire(0)
		elif click.button_index == MOUSE_BUTTON_RIGHT:
			_take_back(0)
		return
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed:
		get_viewport().set_input_as_handled()
		if _state != State.OPEN:
			return
		match pad.button_index:
			JOY_BUTTON_DPAD_UP: _move(0, Vector2i(0, -1))
			JOY_BUTTON_DPAD_DOWN: _move(0, Vector2i(0, 1))
			JOY_BUTTON_DPAD_LEFT: _move(0, Vector2i(-1, 0))
			JOY_BUTTON_DPAD_RIGHT: _move(0, Vector2i(1, 0))
			JOY_BUTTON_A: _fire(0)
			JOY_BUTTON_B: _take_back(0)


func _key(action: String) -> Key:
	if settings != null:
		return settings.key(action)
	return Level3DSettings.DEFAULT_KEYS.get(action, KEY_NONE)


# The cell under `p`, (column, row), the first player's READY as row 4; x
# -1 for none.
func _cell_at(p: Vector2) -> Vector2i:
	for k in _rects:
		if (_rects[k] as Rect2).has_point(p):
			var cell: Vector3i = k
			if cell.y == READY_ROW and cell.z != 0:
				continue
			return Vector2i(cell.x, cell.y)
	return Vector2i(-1, -1)


func _reticle_slot() -> Vector2:
	var at := _cursor[0] if not _cursor.is_empty() else Vector2i.ZERO
	var rect: Rect2 = _rects.get(Vector3i(at.x if at.y < LIFE_ROW else 0, at.y, 0), Rect2())
	return Vector2(rect.position.x - 28.0 * scale_factor, rect.get_center().y)


# ---------------------------------------------------------------------------
# Drawing

func _draw_text() -> void:
	_rects.clear()
	if _state == State.CLOSED or _run == null or not _bay.staged:
		return
	# The frame's own layout, 2048 wide, whatever the HUD's size.
	var s := _text.size.x / 2048.0
	var tg := _whole(TITLE_GLYPH * s)
	var g := _whole(GLYPH * s)
	var sg := _whole(SMALL * s)
	var pg := _whole(PLAYER_GLYPH * s)
	var title := "%s - ROUND %d" % [TITLE, _run.round + 1]
	Level3DFont.draw(_text, title, roundf(_text.size.x * 0.5 - Level3DFont.width(title, tg) * 0.5),
			roundf(TITLE_Y * s), tg)
	# The goods.
	var m := Rect2(MATRIX.position * s, MATRIX.size * s)
	var gap := TILE_GAP * s
	var tile := Vector2((m.size.x - gap * 2.0) / 3.0, (m.size.y - LIFE_HEIGHT * s - gap * 3.0) / 3.0)
	for it in Level3DShopCatalog.ITEMS:
		var rect: Rect2
		if it.kind == Level3DShopCatalog.Kind.SUPPLY:
			rect = Rect2(m.position.x, m.position.y + (tile.y + gap) * 3.0, m.size.x, LIFE_HEIGHT * s)
		else:
			rect = Rect2(m.position + Vector2((tile.x + gap) * it.col, (tile.y + gap) * it.row), tile)
		rect = Rect2(rect.position.round(), rect.size.round())
		_rects[Vector3i(it.col, it.row, 0)] = rect
		_draw_tile(rect, it, s, g, sg)
	# Each player's side: his money, the tile's words, READY.
	for i in _players:
		_draw_side(i, s, g, sg, pg)
	# The cursors, the second's inside the first's.
	for i in range(_players - 1, -1, -1):
		var at := _cursor[i]
		var key := Vector3i(at.x if at.y < LIFE_ROW else 0, at.y, i if at.y == READY_ROW else 0)
		if not _rects.has(key):
			continue
		var r: Rect2 = _rects[key]
		var inset := 0.0
		if i == 1 and _cursor[0] == at and at.y != READY_ROW:
			inset = (CURSOR + 2.0) * s
		var c := maxf(roundf(CURSOR * s), 2.0)
		_text.draw_rect(r.grow(c - inset), Color.BLACK, false, c + 2.0)
		_text.draw_rect(r.grow(c - inset), colours[i] if i < colours.size() else Color.WHITE, false, c)


func _draw_tile(rect: Rect2, it: Dictionary, s: float, g: float, sg: float) -> void:
	var ring := maxf(roundf(RING * s), 1.0)
	_text.draw_rect(rect, TILE_FILL)
	_text.draw_rect(rect.grow(-ring * 0.5), Color(1, 1, 1, 0.85), false, ring)
	var pad := roundf(12.0 * s)
	var name: String = it.name
	Level3DFont.draw(_text, name, roundf(rect.get_center().x - Level3DFont.width(name, g) * 0.5),
			rect.position.y + pad, g)
	# Each player's corner: his mark when it is his.
	for i in _players:
		var kit: Level3DRun.Kit = _run.kits[i]
		if kit.upgrades.has(it.id):
			var corner := Vector2(rect.position.x + pad * 0.5, rect.position.y + pad * 0.5) if i == 0 \
					else Vector2(rect.end.x - pad * 0.5 - 14.0 * s, rect.position.y + pad * 0.5)
			_text.draw_rect(Rect2(corner, Vector2(14, 14) * s), colours[i] if i < colours.size() else Color.WHITE)
	# The status line at the bottom: one across with one player, one a side
	# with two.
	var y := rect.end.y - pad - sg
	if _players == 1:
		var t := _status(0, it)
		Level3DFont.draw(_text, t[0], roundf(rect.get_center().x - Level3DFont.width(t[0], sg) * 0.5), y, sg,
				Level3DFont.WHITE, t[1])
	else:
		for i in _players:
			var t := _status(i, it)
			var w := Level3DFont.width(t[0], sg)
			var x := rect.position.x + pad if i == 0 else rect.end.x - pad - w
			Level3DFont.draw(_text, t[0], roundf(x), y, sg, Level3DFont.WHITE, t[1])
	# The launcher's tile says which step it sells, the life's how many he has.
	if it.id == "launcher" or it.id == "life":
		for i in _players:
			var kit: Level3DRun.Kit = _run.kits[i]
			var line := ""
			if it.id == "launcher":
				line = LAUNCHER_NAMES[mini(kit.weapon() + 1, 3)] if kit.weapon() < 3 else LAUNCHER_NAMES[3]
			else:
				line = "x%d" % kit.lives
			var w := Level3DFont.width(line, sg)
			var x := rect.get_center().x - w * 0.5 if _players == 1 else \
					(rect.position.x + pad if i == 0 else rect.end.x - pad - w)
			# With two, one over the other, as MISSILE++ twice is wider than a tile.
			var at := rect.get_center().y - sg * 0.5 + 4.0 * s
			if _players > 1 and it.id == "launcher":
				at += (sg * 0.5 + 4.0 * s) * (-1.0 if i == 0 else 1.0)
			Level3DFont.draw(_text, line, roundf(x), roundf(at), sg,
					Level3DFont.GRAY, colours[i] if i < colours.size() else Color.WHITE)


# What tile `it` is to player `i`: [text, tint].
func _status(i: int, it: Dictionary) -> Array:
	var kit: Level3DRun.Kit = _run.kits[i]
	match Level3DShopCatalog.state(it.id, kit):
		Level3DShopCatalog.State.BUY:
			return ["$%d" % Level3DShopCatalog.price(it.id, kit), Color.WHITE]
		Level3DShopCatalog.State.POOR:
			return ["$%d" % Level3DShopCatalog.price(it.id, kit), POOR]
		Level3DShopCatalog.State.OWNED:
			var colour: Color = colours[i] if i < colours.size() else Color.WHITE
			return ["IN SLOT" if kit.device == it.id else "OWNED", colour]
	return ["MAX", DIM]


func _draw_side(i: int, s: float, g: float, sg: float, pg: float) -> void:
	var kit: Level3DRun.Kit = _run.kits[i]
	var colour: Color = colours[i] if i < colours.size() else Color.WHITE
	var x0 := SIDE_MARGIN * s if i == 0 else (2048.0 - SIDE_MARGIN - SIDE_WIDTH) * s
	var width := SIDE_WIDTH * s
	# 1P and the money.
	var y := roundf(TITLE_Y * s)
	var who := "%dP " % (i + 1)
	var money := "$%d" % kit.score
	var x := x0 if i == 0 else x0 + width - Level3DFont.width(who + money, pg)
	x = Level3DFont.draw(_text, who, roundf(x), y, pg, Level3DFont.WHITE, colour)
	Level3DFont.draw(_text, money, roundf(x), y, pg)
	_draw_words(i, Rect2(x0, 0.0, width, 0.0), s, g, sg)
	# READY.
	var ready := "READY!" if _set[i] else "READY"
	var rw := Level3DFont.width(ready, g)
	var rect := Rect2(roundf(x0 + width * 0.5 - rw * 0.5 - 24.0 * s), roundf(READY_Y * s - 12.0 * s),
			rw + 48.0 * s, g + 24.0 * s)
	_rects[Vector3i(0, READY_ROW, i)] = rect
	_text.draw_rect(rect, colour if _set[i] else TILE_FILL)
	_text.draw_rect(rect, Color(1, 1, 1, 0.85), false, maxf(roundf(RING * s), 1.0))
	Level3DFont.draw(_text, ready, roundf(rect.position.x + 24.0 * s), roundf(rect.position.y + 12.0 * s), g)


# Player `i`'s tile's name and its words in a box across his column
# (`column`'s x and width), over his jeep, and a line from it to the part
# where the jeep has one: straight down, leaving the box at the part's x,
# or down beside the jeep and in to the part (SHOWS' knee).
func _draw_words(i: int, column: Rect2, s: float, g: float, sg: float) -> void:
	var it := _item(i)
	var show: Dictionary = SHOWS.get(_shown[i], {})
	var colour: Color = colours[i] if i < colours.size() else Color.WHITE
	var name: String = it.get("name", "READY")
	var text: String = it.get("text", "EVERY PLAYER READY, AND THE ROUND STARTS.")
	var pad := roundf(WORDS_PAD * s)
	var lines := _wrap(text, sg, column.size.x - pad * 2.0)
	var height := pad * 2.0 + g + roundf(10.0 * s) + lines.size() * (sg + roundf(8.0 * s)) - roundf(8.0 * s)
	var box := Rect2(column.position.x, roundf(WORDS_TOP * s), column.size.x, height)
	var a := clampf((_time - _since[i]) / WORDS_FADE, 0.0, 1.0)
	var spot: Variant = _bay.spot(i)
	if spot != null:
		var to: Vector2 = spot
		var points := PackedVector2Array()
		if show.has("knee"):
			var x := roundf(_bay.middle(i).x + float(show.knee) * s * (1.0 if i == 0 else -1.0))
			x = clampf(x, box.position.x + pad, box.end.x - pad)
			points = PackedVector2Array([Vector2(x, box.end.y), Vector2(x, to.y), to])
		else:
			points = PackedVector2Array([Vector2(clampf(to.x, box.position.x + pad, box.end.x - pad), box.end.y), to])
		var w := maxf(roundf(LINE * s), 2.0)
		var r := maxf(roundf(DOT * s), 3.0)
		var edge := maxf(roundf(2.0 * s), 1.0)
		# The knee rounded, under the line and over it, as the lines meeting
		# there leave a notch.
		_text.draw_polyline(points, Color(0, 0, 0, a * 0.8), w + edge * 2.0, true)
		for k in range(1, points.size() - 1):
			_text.draw_circle(points[k], w * 0.5 + edge, Color(0, 0, 0, a * 0.8))
		_text.draw_circle(to, r + edge * 2.0, Color(0, 0, 0, a * 0.8))
		_text.draw_polyline(points, Color(colour, a), w, true)
		for k in range(1, points.size() - 1):
			_text.draw_circle(points[k], w * 0.5, Color(colour, a))
		_text.draw_circle(to, r + edge, Color(1, 1, 1, a))
		_text.draw_circle(to, r - edge, Color(colour, a))
	_text.draw_rect(box, Color(TILE_FILL, TILE_FILL.a * a))
	_text.draw_rect(box.grow(-1.0), Color(colour, a), false, maxf(roundf(RING * s), 1.0))
	var y := box.position.y + pad
	Level3DFont.draw(_text, name, roundf(box.position.x + pad), y, g, Level3DFont.WHITE, Color(colour, a))
	y += g + roundf(10.0 * s)
	for line in lines:
		Level3DFont.draw(_text, line, roundf(box.position.x + pad), y, sg, Level3DFont.GRAY, Color(1, 1, 1, a))
		y += sg + roundf(8.0 * s)


static func _wrap(text: String, g: float, width: float) -> Array[String]:
	var lines: Array[String] = []
	var line := ""
	for word in text.split(" ", false):
		var next := word if line == "" else line + " " + word
		if line != "" and Level3DFont.width(next, g) > width:
			lines.append(line)
			line = word
		else:
			line = next
	if line != "":
		lines.append(line)
	return lines


static func _whole(g: float) -> float:
	return maxf(roundf(g / 8.0), 1.0) * 8.0


# ---------------------------------------------------------------------------
# The jeeps: a world of their own behind the matrix, filling the frame.

class Bay:
	extends TextureRect

	const GROUND := Color(0.24, 0.22, 0.19)
	const TABLE := Color(0.36, 0.37, 0.35)
	# Where the tables stand and the camera looks from, level metres: a jeep
	# in the middle of either player's column, side on clear of the frame's
	# edge and of the matrix, between the two places of his words.
	const SPOT := Vector3(2.85, 0.0, -0.2)
	const CAMERA_AT := Vector3(0.0, 3.8, 6.2)
	const LOOK_AT := Vector3(0.0, -0.3, -0.9)
	const FOV := 36.0

	var staged := false
	var viewport: SubViewport
	var _tables: Array[Node3D] = []
	var _jeeps: Array[Level3DBtr] = []
	var _yaw: Array[float] = []
	var _want: Array[float] = []
	var _ghosts: Array = []         # per player, the meshes on trial
	var _spots: Array = []          # per player, the line's end on his jeep, its frame; null for none
	var _camera: Camera3D
	var _time := 0.0

	func _init() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		stretch_mode = TextureRect.STRETCH_SCALE
		viewport = SubViewport.new()
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
		viewport.msaa_3d = Viewport.MSAA_4X
		add_child(viewport)
		texture = viewport.get_texture()
		visible = false

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED and viewport != null:
			viewport.size = Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))

	# The bay for `players` jeeps, the second tinted by `tints[1]`.
	func stage(players: int, tints: Array[Vector3]) -> void:
		clear()
		viewport.size = Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))
		var root := Node3D.new()
		viewport.add_child(root)
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = GROUND.darkened(0.55)
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color(0.62, 0.66, 0.78)
		environment.ambient_light_energy = 0.4
		environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		var world_environment := WorldEnvironment.new()
		world_environment.environment = environment
		root.add_child(world_environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-50.0, 30.0, 0.0)
		sun.light_energy = 1.1
		sun.shadow_enabled = true
		root.add_child(sun)
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(40.0, 40.0)
		ground.mesh = plane
		ground.material_override = _matte(GROUND)
		root.add_child(ground)
		var camera := Camera3D.new()
		camera.fov = FOV
		root.add_child(camera)
		camera.look_at_from_position(CAMERA_AT, LOOK_AT, Vector3.UP)
		camera.current = true
		_camera = camera
		for i in players:
			var table := Node3D.new()
			table.position = Vector3(-SPOT.x if i == 0 else SPOT.x, SPOT.y, SPOT.z)
			root.add_child(table)
			var disc := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 1.0
			cylinder.bottom_radius = 1.04
			cylinder.height = 0.12
			cylinder.radial_segments = 32
			disc.mesh = cylinder
			disc.position.y = 0.06
			disc.material_override = _matte(TABLE)
			table.add_child(disc)
			var jeep := Level3DBtr.new()
			jeep.position.y = 0.12
			table.add_child(jeep)
			if i > 0 and i < tints.size() and tints[i] != Vector3.ZERO:
				jeep.tint(tints[i].x, tints[i].y, tints[i].z)
			_tables.append(table)
			_jeeps.append(jeep)
			_yaw.append(30.0)
			_want.append(30.0)
			_ghosts.append([])
			_spots.append(null)
		staged = true
		visible = true

	func clear() -> void:
		for child in viewport.get_children():
			child.queue_free()
		_tables.clear()
		_jeeps.clear()
		_yaw.clear()
		_want.clear()
		_ghosts.clear()
		_spots.clear()
		_camera = null
		staged = false
		visible = false

	static func _matte(colour: Color) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.roughness = 1.0
		return m

	# Player `i`'s jeep with what `kit` has on it, and `trial`'s part on trial;
	# the line to end at `fraction` of the part's box, his or on trial.
	func dress(i: int, kit: Level3DRun.Kit, trial: String, fraction: Vector3) -> void:
		if i >= _jeeps.size():
			return
		var jeep := _jeeps[i]
		for mesh in _ghosts[i]:
			if is_instance_valid(mesh):
				(mesh as GeometryInstance3D).transparency = 0.0
		_ghosts[i] = []
		var shown := kit.upgrades.duplicate()
		var part: Node3D = null
		# What the line goes to: the tile's part, his or on trial.
		var pointed := jeep.upgrade_part(trial)
		if not shown.has(trial) and jeep.upgrade_part(trial) != null:
			shown.append(trial)
			part = jeep.upgrade_part(trial)
		jeep.set_upgrades(shown)
		# The launcher: the step he has, or on trial the next one in its place.
		var step := kit.weapon()
		var trying := trial == "launcher" and step < Level3DShopCatalog.LAUNCHER_TOP
		# The spares' rack, where it has one, with the round of the fit shown.
		jeep.set_weapon_level(step + 1 if trying else step)
		var prefix: String = jeep.vehicle.prefix
		for k in Level3DLauncher.FITS.size():
			var base := jeep.launcher_node(prefix + String(Level3DLauncher.FITS[k].base).trim_prefix("BTR_"))
			if base == null:
				continue
			base.visible = k == (step + 1 if trying else step)
			if trying and k == step + 1:
				part = base
			if trial == "launcher" and base.visible:
				pointed = base
		if part != null:
			_ghosts[i] = part.find_children("*", "GeometryInstance3D", true, false)
			if part is GeometryInstance3D:
				_ghosts[i].append(part)
		_spots[i] = null
		if pointed != null:
			# The box of what of it shows, in the jeep's frame, which turns.
			var meshes := pointed.find_children("*", "MeshInstance3D", true, false)
			if pointed is MeshInstance3D:
				meshes.append(pointed)
			var into := jeep.global_transform.affine_inverse()
			var box: AABB
			var first := true
			for node in meshes:
				var mesh := node as MeshInstance3D
				if mesh.mesh == null or not mesh.is_visible_in_tree():
					continue
				var b := (into * mesh.global_transform) * mesh.get_aabb()
				box = b if first else box.merge(b)
				first = false
			if not first:
				_spots[i] = box.position + box.size * fraction

	# The middle of player `i`'s table, its top, in the bay's pixels: where
	# SHOWS' knees are measured from.
	func middle(i: int) -> Vector2:
		if _camera == null or i >= _tables.size():
			return Vector2.ZERO
		return _camera.unproject_position(_tables[i].global_position + Vector3.UP * 0.12)

	# Where player `i`'s line ends, in the bay's pixels, as his jeep stands
	# now; null for a tile with no part on the jeep.
	func spot(i: int) -> Variant:
		if _camera == null or i >= _spots.size() or _spots[i] == null:
			return null
		return _camera.unproject_position(_jeeps[i].global_transform * (_spots[i] as Vector3))

	# Player `i`'s jeep to turn `degrees` off facing the camera, towards the
	# frame's middle.
	func turn(i: int, degrees: float) -> void:
		if i < _want.size():
			_want[i] = degrees

	func _process(delta: float) -> void:
		if not staged:
			return
		_time += delta
		var wave := 0.5 + 0.5 * sin(_time * Level3DShop.GHOST_PULSE)
		var pulse := lerpf(Level3DShop.GHOST.x, Level3DShop.GHOST.y, wave)
		for i in _tables.size():
			_yaw[i] = lerpf(_yaw[i], _want[i], 1.0 - exp(-Level3DShop.TURN_RATE * delta))
			# Nose to the camera is the jeep's +X turned to +Z; the first's
			# turns right to show his side to the middle, the second's left.
			var side := 1.0 if i == 0 else -1.0
			_tables[i].rotation.y = -PI / 2.0 + deg_to_rad(_yaw[i]) * side
			for mesh in _ghosts[i]:
				if is_instance_valid(mesh):
					(mesh as GeometryInstance3D).transparency = pulse
