# The shop between the 3D preview's rounds (docs/shop-plan.md, section 4):
# once the mission's summary is closed (level3d_preview.gd, _round_won), the
# stage goes to black and the shop comes up out of it, the stage paused
# under it. The players' jeeps stand on one concrete, a landing spot's paint
# on it, the Littlebird that flew the supply in on its circle and crates
# round it (Bay), in a column at each of the frame's edges, the first's on the left, the second's on the right,
# with what they have bought on them; between them the goods, a matrix out
# of Level3DShopCatalog:
#
#     1P $38400                      SUPPLY                      2P $21300
#     [TWIN GUN ...]   TWIN GUN    LAUNCHER     RADAR     [NITRO ......]
#          |           SPARES      ARMOR        RAM CAGE              |
#       [jeep]         NITRO       MINES        AIRSTRIKE    [jeep]   |
#                      ARENA       ??? CLASSIFIED  ???            o---'
#                      ???         ???          ???
#                      LIFE ----------------------------
#     [paint swatches]                                  [paint swatches]
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
# one status across the tile. A CLASSIFIED tile (Level3DShopCatalog) says
# nothing but ??? under its stamp: not for sale, for the player to unlock
# later.
#
#   * Fire buys (the gun: L, the left button, right Alt for the second
#     player, Enter and Space for the first, a pad's A); a device already
#     owned goes in the slot instead. The rocket (P, the right button, right
#     Ctrl) takes back the last of that tile bought in this visit, its price
#     back on the score. Fire on READY, under the matrix, is the player's
#     word that he is done; the round starts when every player has given it:
#     the words and the goods go, the jeeps turn forward and drive off their
#     spots, out of the frame, and the black comes down over them (DRIVE_*).
#   * The jeep turns on its table to show the part the tile is about
#     (SHOWS), and a part not yet his stands on it see-through, pulsing --
#     the twin gun in the single one's place, the launcher's next step in
#     the one he has. What the tile is, its name and its words, is in a box
#     across his column, over the jeep whatever the tile, so that the eye
#     does not jump, with a line from the box to the part, his or on trial,
#     which follows it as the jeep turns: straight down, or for a part low
#     on the jeep down beside it and in at a right angle, so as not to
#     cross the hull.
#   * Under the jeep, over READY, the paints (Level3DBtr.PAINTS): a row of
#     swatches, free, left and right on it repainting the jeep there and
#     then, a click on one the mouse's way; another player's paint is not to
#     be had, two jeeps alike on the stage not telling whose is whose. The
#     preview keeps them in its settings, for the next game too.
#   * With one player there is no second column: the matrix stands at the
#     frame's right edge, the title over it, and the jeep, larger, has the
#     rest (SOLO_MATRIX_X, Bay.SOLO_ZOOM).
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
const PLAYER_GLYPH := 48.0     # the players' money, as large as the title
const READY_GLYPH := 32.0
const READY_PAD := Vector2(32.0, 16.0)
# The layout, in the HUD's 2048 x 1152 at 100%.
const TITLE_Y := 48.0
const MATRIX := Rect2(640, 150, 768, 832.5)   # the goods: five rows of tiles 126.5 high, and the life's
const TILE_GAP := 16.0
const LIFE_HEIGHT := 120.0
const SIDE_WIDTH := 560.0       # each player's column at the frame's edge
const SIDE_MARGIN := 40.0
# With one player the matrix is at the frame's right edge, and his column,
# his jeep larger in it (Bay.SOLO_ZOOM), is all the rest; his words' box no
# wider than WORDS_WIDTH, over the jeep's middle.
const SOLO_MATRIX_X := 2048.0 - SIDE_MARGIN - MATRIX.size.x
const WORDS_WIDTH := 800.0
const READY_Y := 1040.0
const TILE_FILL := Color(0.0, 0.0, 0.0, 0.62)
const RING := 2.0
const CURSOR := 4.0
const POOR := Color(1.0, 0.36, 0.3)
const STAMP := Color(0.86, 0.2, 0.16)   # CLASSIFIED's, and its tilt, degrees
const STAMP_TILT := -8.0
const DIM := Color(0.62, 0.62, 0.62)
const FADE_OUT := 0.6
const FADE_IN := 0.5
const LEAVE := 0.6
# Every player ready: the shop's words and frames gone over HUD_OUT, the
# jeeps turned DRIVE_VIEW off nose-to-camera (towards the middle) at
# DRIVE_TURN_RATE and away from a standstill at DRIVE_ACCEL, metres a second
# a second, their noses up DRIVE_SQUAT as they pull away; the black comes
# down DRIVE_TIME after.
const HUD_OUT := 0.25
const DRIVE_VIEW := 15.0
const DRIVE_TURN_RATE := 8.0
const DRIVE_ACCEL := 5.0
const DRIVE_SQUAT := 0.05
# And heard, as the title's jeeps are (Level3DSplash3D): each jeep's starter
# (jeep_start) from ENGINE_FROM into the file, the next jeep's ENGINE_STAGGER
# later. The file cranks, catches and revs, and has settled to a run by
# ENGINE_STARTED, 1.45 s in (its spectrum: the starter from 0.15 s, the
# flare to 1.1 s): only then does the jeep pull away (DRIVE_DELAY, the next
# one's ENGINE_STAGGER later), and the running engine (jeep_idle) comes in
# over ENGINE_RUN_IN as it does, pitched up with the speed to
# ENGINE_REV_PITCH at ENGINE_REV_SPEED m/s; all ENGINE_GAIN loud and dying
# away with the black, which comes down DRIVE_TIME after READY -- the start
# heard and DRIVE_MOVING of the drive seen.
const ENGINE_START := "jeep_start"
const ENGINE_LOOP := "jeep_idle"
const ENGINE_FROM := 0.12
const ENGINE_STARTED := 1.45
const ENGINE_STAGGER := 0.12
const DRIVE_DELAY := ENGINE_STARTED - ENGINE_FROM
const DRIVE_MOVING := 1.2
const DRIVE_TIME := DRIVE_DELAY + DRIVE_MOVING
const ENGINE_RUN := DRIVE_DELAY
const ENGINE_RUN_IN := 0.4
const ENGINE_REV_PITCH := 1.6
const ENGINE_REV_SPEED := 6.0
const ENGINE_GAIN := 0.8
const READY_ROW := 7
const PAINT_ROW := 6           # the swatches over READY, each player's own
const LIFE_ROW := 5            # and as many rows of tiles over it
const LAUNCHER_NAMES := ["GRENADE", "MISSILE", "MISSILE+", "MISSILE++"]
# How the jeep shows a tile's part, and how the line from the words, always
# over the jeep, gets to it:
#   view   degrees off nose-to-camera, towards the frame's middle; 180 is
#          the tail (VIEW if not given)
#   spot   where on the part the line ends, a fraction of its box in the
#          jeep's frame -- x the nose, y up, z across, 1 the side the first
#          player's jeep shows the camera, the second's mirrored -- its
#          middle if not given: the nitro's pipes at its tail, the ram
#          cage's grille at its nose, the armour's near door, under its
#          plates on the glass (y below 0)
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
	"zip": {"view": 150.0, "spot": Vector3(1.0, 1.0, 0.5)},
	"armor": {"view": 75.0, "spot": Vector3(0.45, -1.0, 1.0)},
	"hull": {"view": 60.0, "knee": 240.0, "spot": Vector3(1.0, 0.5, 0.5)},
	"nitro": {"view": 160.0, "knee": -265.0, "spot": Vector3(0.0, 0.5, 0.5)},
	"mines": {"view": 155.0, "knee": -265.0},
	"airstrike": {"view": 30.0},
	"arena": {"view": 35.0, "spot": Vector3(0.5, 1.0, 1.0)},
	"paint": {"view": 40.0},
}
const VIEW := 30.0
const TURN_RATE := 3.0          # of the way to the view, per second
const GHOST := Vector2(0.25, 0.7)   # a part on trial: its transparency, pulsing between
const GHOST_PULSE := 4.0
# The tile's words: a box in the player's column, over the jeep, its top in
# line with the matrix's, coming up over WORDS_FADE seconds when the tile
# changes; the line from it to the part, its dot.
const WORDS_TOP := MATRIX.position.y
const WORDS_PAD := 16.0
const WORDS_FADE := 0.2
# The paints' swatches (PAINT_ROW): their size and the gap between, over
# READY in the player's column; and what the words say of them.
const SWATCH := 44.0
const SWATCH_GAP := 12.0
const PAINT_TEXT := "THE JEEP'S PAINT, FREE. LEFT AND RIGHT FOR ANOTHER."
const LINE := 4.0
const DOT := 8.0

enum State { CLOSED, DARKENING, OPEN, LEAVING }

# `done.call(run)` under the black once every player is ready, the run as
# bought; the shop then lifts off the stage and is gone.
var done: Callable
var scale_factor := 1.0
var settings: Level3DSettings
# Per player: null for the first (the settings' keys and the mouse), the
# second's HumanInput; and their colours, and their jeeps' paints
# (Level3DBtr.PAINTS), which the shop changes and the preview keeps.
var inputs: Array = []
var colours: Array[Color] = []
var paints: Array[String] = []

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
static var _swatches: Array[Color] = []  # each paint's olive, Level3DBtr.paint_swatches
var _engines: Array = []            # per jeep driving off: [start, idle, since]
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
	paints.assign(["olive", "blue"])
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
	_stop_engines()
	_kill_fade()
	_state = State.CLOSED
	visible = false
	_veil.color.a = 0.0
	_reticle.shown = false
	_bay.clear()


func _show() -> void:
	_fade = null
	_text.modulate.a = 1.0
	_bay.stage(_players, paints)
	_swatch_colours()
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
	Level3DAudio.play("menu_pick")
	# The words, the goods and the reticle gone, the jeeps away.
	_text.create_tween().tween_property(_text, "modulate:a", 0.0, HUD_OUT)
	_bay.drive_off()
	_start_engines()
	_kill_fade()
	_fade = create_tween()
	_fade.tween_interval(DRIVE_TIME)
	_fade.tween_property(_veil, "color:a", 1.0, LEAVE)
	_fade.tween_callback(func():
		_stop_engines()
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
	if at.y == PAINT_ROW:
		var paint: Dictionary = Level3DBtr.PAINTS[Level3DBtr.paint_index(paints[player])]
		return {"id": "paint", "name": paint.name, "text": PAINT_TEXT}
	return Level3DShopCatalog.at(at.y, at.x)


func _move(player: int, by: Vector2i) -> void:
	var at := _cursor[player]
	var to := at
	if by.y != 0:
		to.y = clampi(at.y + by.y, 0, READY_ROW)
	elif at.y == PAINT_ROW:
		_repaint(player, Level3DBtr.paint_index(paints[player]) + by.x, by.x)
		return
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
	if _cursor[player].y == PAINT_ROW:
		Level3DAudio.play("menu_pick")
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
	_run_engines()


# Each jeep's engine started as it drives off (ENGINE_*).
func _start_engines() -> void:
	_stop_engines()
	for i in _players:
		var start := AudioStreamPlayer.new()
		var idle := AudioStreamPlayer.new()
		for player in [start, idle]:
			add_child(player)
		_engines.append([start, idle, _time + ENGINE_STAGGER * i])


func _run_engines() -> void:
	for engine in _engines:
		var start := engine[0] as AudioStreamPlayer
		var idle := engine[1] as AudioStreamPlayer
		var t: float = _time - float(engine[2])
		if t < 0.0:
			continue
		# The sound mode may change under it: the streams asked for as each starts.
		if not start.playing and t < ENGINE_RUN and start.stream == null:
			start.stream = Level3DAudio.stream(ENGINE_START)
			start.bus = Level3DAudio.bus(ENGINE_START)
			if start.stream != null:
				start.play(ENGINE_FROM)
		if not idle.playing and t >= ENGINE_RUN and idle.stream == null:
			idle.stream = Level3DAudio.stream(ENGINE_LOOP)
			idle.bus = Level3DAudio.bus(ENGINE_LOOP)
			if idle.stream != null:
				idle.play()
		var run := clampf((t - ENGINE_RUN) / ENGINE_RUN_IN, 0.0, 1.0)
		var out := ENGINE_GAIN * (1.0 - _veil.color.a)
		start.volume_db = Level3DAudio.volume_db(ENGINE_START) + linear_to_db(maxf(out * (1.0 - run), 0.0001))
		idle.volume_db = Level3DAudio.volume_db(ENGINE_LOOP) + linear_to_db(maxf(out * run, 0.0001))
		var moving := maxf(t - DRIVE_DELAY, 0.0) * DRIVE_ACCEL
		idle.pitch_scale = lerpf(1.0, ENGINE_REV_PITCH, clampf(moving / ENGINE_REV_SPEED, 0.0, 1.0))


func _stop_engines() -> void:
	for engine in _engines:
		for player in [engine[0], engine[1]]:
			if is_instance_valid(player):
				(player as Node).queue_free()
	_engines.clear()


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
			if at.y == PAINT_ROW:
				# Over a swatch: the row, the paint only by a click.
				at.x = now.x
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
		if at.y == PAINT_ROW:
			_cursor[0].y = PAINT_ROW
			_dress(0)
			if click.button_index == MOUSE_BUTTON_LEFT:
				_repaint(0, at.x, 0)
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


# The cell under `p`, (column, row), the first player's READY and swatches
# as their rows, a swatch's x its paint; x -1 for none.
func _cell_at(p: Vector2) -> Vector2i:
	for k in _rects:
		if (_rects[k] as Rect2).has_point(p):
			var cell: Vector3i = k
			if (cell.y == READY_ROW or cell.y == PAINT_ROW) and cell.z != 0:
				continue
			return Vector2i(cell.x, cell.y)
	return Vector2i(-1, -1)


# Player `player`'s jeep in the paint at `index` (Level3DBtr.PAINTS), or,
# that one being another player's, the next on the way `step` goes;
# nothing past either end, nor with `step` 0 (a click) on a taken one.
func _repaint(player: int, index: int, step: int) -> void:
	while index >= 0 and index < Level3DBtr.PAINTS.size() and _taken(player, Level3DBtr.PAINTS[index].id):
		if step == 0:
			index = -1
			break
		index += step
	if index < 0 or index >= Level3DBtr.PAINTS.size():
		Level3DAudio.play("hit_dull")
		return
	var id: String = Level3DBtr.PAINTS[index].id
	if id == paints[player]:
		return
	paints[player] = id
	_bay.paint(player, id)
	Level3DAudio.play("menu_move")


# Whether paint `id` is on another player's jeep: two alike on the stage
# would not tell which is whose.
func _taken(player: int, id: String) -> bool:
	for i in _players:
		if i != player and i < paints.size() and paints[i] == id:
			return true
	return false


func _swatch_colours() -> void:
	if _swatches.is_empty():
		_swatches = Level3DBtr.paint_swatches(Level3DBtr.VEHICLES[Level3DBtr.chosen()])


# Player `i`'s cursor's key in _rects.
func _cursor_key(i: int) -> Vector3i:
	var at := _cursor[i]
	if at.y == PAINT_ROW:
		return Vector3i(Level3DBtr.paint_index(paints[i]), PAINT_ROW, i)
	return Vector3i(at.x if at.y < LIFE_ROW else 0, at.y, i if at.y == READY_ROW else 0)


func _reticle_slot() -> Vector2:
	var rect: Rect2 = _rects.get(_cursor_key(0), Rect2()) if not _cursor.is_empty() else Rect2()
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
	# The goods, and the title over them.
	var m := Rect2(_matrix().position * s, MATRIX.size * s)
	var title := TITLE
	Level3DFont.draw(_text, title, roundf(m.get_center().x - Level3DFont.width(title, tg) * 0.5),
			roundf(TITLE_Y * s), tg)
	var gap := TILE_GAP * s
	var columns := float(Level3DShopCatalog.COLUMNS)
	var rows := float(LIFE_ROW)
	var tile := Vector2((m.size.x - gap * (columns - 1.0)) / columns, (m.size.y - LIFE_HEIGHT * s - gap * rows) / rows)
	for it in Level3DShopCatalog.ITEMS:
		var rect: Rect2
		if it.kind == Level3DShopCatalog.Kind.SUPPLY:
			rect = Rect2(m.position.x, m.position.y + (tile.y + gap) * rows, m.size.x, LIFE_HEIGHT * s)
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
		var key := _cursor_key(i)
		if not _rects.has(key):
			continue
		var r: Rect2 = _rects[key]
		var inset := 0.0
		if i == 1 and _cursor[0] == at and at.y != READY_ROW and at.y != PAINT_ROW:
			inset = (CURSOR + 2.0) * s
		var c := maxf(roundf(CURSOR * s), 2.0)
		_text.draw_rect(r.grow(c - inset), Color.BLACK, false, c + 2.0)
		_text.draw_rect(r.grow(c - inset), colours[i] if i < colours.size() else Color.WHITE, false, c)


func _draw_tile(rect: Rect2, it: Dictionary, s: float, g: float, sg: float) -> void:
	if it.kind == Level3DShopCatalog.Kind.CLASSIFIED:
		_draw_classified(rect, it, s, g, sg)
		return
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


# A tile not for sale yet: dimmer, its name a question, and a CLASSIFIED
# stamp across it, aslant, in STAMP's red -- no price, no status.
func _draw_classified(rect: Rect2, it: Dictionary, s: float, g: float, sg: float) -> void:
	var ring := maxf(roundf(RING * s), 1.0)
	_text.draw_rect(rect, Color(TILE_FILL, TILE_FILL.a * 0.6))
	_text.draw_rect(rect.grow(-ring * 0.5), Color(1, 1, 1, 0.35), false, ring)
	var pad := roundf(12.0 * s)
	var name: String = it.name
	Level3DFont.draw(_text, name, roundf(rect.get_center().x - Level3DFont.width(name, g) * 0.5),
			rect.position.y + pad, g, Level3DFont.GRAY)
	var word := "CLASSIFIED"
	var w := Level3DFont.width(word, sg)
	var inner := roundf(8.0 * s)
	var box := Rect2(-w * 0.5 - inner, -sg * 0.5 - inner, w + inner * 2.0, sg + inner * 2.0)
	_text.draw_set_transform(rect.get_center() + Vector2(0.0, roundf(10.0 * s)), deg_to_rad(STAMP_TILT))
	_text.draw_rect(box, Color(0, 0, 0, 0.35))
	_text.draw_rect(box, STAMP, false, maxf(roundf(2.0 * s), 1.0))
	Level3DFont.draw(_text, word, roundf(-w * 0.5), roundf(-sg * 0.5), sg, Level3DFont.WHITE, STAMP)
	_text.draw_set_transform(Vector2.ZERO)


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


# Where the matrix is, in the 2048 frame: in the middle with two players, at
# the right edge with one.
func _matrix() -> Rect2:
	return Rect2(SOLO_MATRIX_X, MATRIX.position.y, MATRIX.size.x, MATRIX.size.y) if _players == 1 else MATRIX


# Player `i`'s column, in the 2048 frame: x and width.
func _column(i: int) -> Vector2:
	if _players == 1:
		return Vector2(SIDE_MARGIN, SOLO_MATRIX_X - SIDE_MARGIN * 2.0)
	return Vector2(SIDE_MARGIN if i == 0 else 2048.0 - SIDE_MARGIN - SIDE_WIDTH, SIDE_WIDTH)


func _draw_side(i: int, s: float, g: float, sg: float, pg: float) -> void:
	var kit: Level3DRun.Kit = _run.kits[i]
	var colour: Color = colours[i] if i < colours.size() else Color.WHITE
	var x0 := _column(i).x * s
	var width := _column(i).y * s
	# 1P and the money.
	var y := roundf(TITLE_Y * s)
	var who := "%dP " % (i + 1)
	var money := "$%d" % kit.score
	var x := x0 if i == 0 else x0 + width - Level3DFont.width(who + money, pg)
	x = Level3DFont.draw(_text, who, roundf(x), y, pg, Level3DFont.WHITE, colour)
	Level3DFont.draw(_text, money, roundf(x), y, pg)
	_draw_words(i, Rect2(x0, 0.0, width, 0.0), s, g, sg)
	_draw_paints(i, x0, width, s)
	# READY.
	var ready := "READY!" if _set[i] else "READY"
	var rg := _whole(READY_GLYPH * s)
	var pad := (READY_PAD * s).round()
	var rw := Level3DFont.width(ready, rg)
	var rect := Rect2(roundf(x0 + width * 0.5 - rw * 0.5 - pad.x), roundf(READY_Y * s - pad.y),
			rw + pad.x * 2.0, rg + pad.y * 2.0)
	_rects[Vector3i(0, READY_ROW, i)] = rect
	_text.draw_rect(rect, colour if _set[i] else TILE_FILL)
	_text.draw_rect(rect, Color(1, 1, 1, 0.85), false, maxf(roundf(RING * s), 1.0))
	Level3DFont.draw(_text, ready, rect.position.x + pad.x, rect.position.y + pad.y, rg)


# Player `i`'s swatches over his READY, across the middle of his column,
# their bottom in line with the matrix's: each the olive in that paint, a
# bar over the one on his jeep, another
# player's dimmed and struck through.
func _draw_paints(i: int, x0: float, width: float, s: float) -> void:
	var n := Level3DBtr.PAINTS.size()
	var size := roundf(SWATCH * s)
	var gap := roundf(SWATCH_GAP * s)
	var x := roundf(x0 + width * 0.5 - (size * n + gap * (n - 1)) * 0.5)
	# Their bottom in line with LIFE's, the matrix's.
	var y := roundf((MATRIX.end.y - SWATCH) * s)
	var ring := maxf(roundf(RING * s), 1.0)
	for k in n:
		var rect := Rect2(x + (size + gap) * k, y, size, size)
		_rects[Vector3i(k, PAINT_ROW, i)] = rect
		var id: String = Level3DBtr.PAINTS[k].id
		var colour: Color = _swatches[k] if k < _swatches.size() else Color.GRAY
		var taken := _taken(i, id)
		_text.draw_rect(rect, colour.darkened(0.6) if taken else colour)
		_text.draw_rect(rect, Color(1, 1, 1, 0.35 if taken else 0.85), false, ring)
		if taken:
			_text.draw_line(rect.position, rect.end, Color(1, 1, 1, 0.5), ring)
		if id == paints[i]:
			_text.draw_rect(Rect2(rect.position.x, rect.position.y - roundf(10.0 * s), size, roundf(4.0 * s)),
					Color.WHITE)


# Player `i`'s tile's name and its words in a box across his column
# (`column`'s x and width) or WORDS_WIDTH of it in its middle, over his jeep, and a line from it to the part
# where the jeep has one: straight down, leaving the box at the part's x,
# or down beside the jeep and in to the part (SHOWS' knee).
func _draw_words(i: int, column: Rect2, s: float, g: float, sg: float) -> void:
	var it := _item(i)
	var show: Dictionary = SHOWS.get(_shown[i], {})
	var colour: Color = colours[i] if i < colours.size() else Color.WHITE
	if column.size.x > WORDS_WIDTH * s:
		column = Rect2(roundf(column.get_center().x - WORDS_WIDTH * s * 0.5), column.position.y,
				WORDS_WIDTH * s, column.size.y)
	# The name in full where the tile's is short for it (the catalog's title).
	var name: String = it.get("title", it.get("name", "READY"))
	var text: String = it.get("text", "EVERY PLAYER READY, AND THE ROUND STARTS.")
	var pad := roundf(WORDS_PAD * s)
	var heads := _wrap(name, g, column.size.x - pad * 2.0)
	var lines := _wrap(text, sg, column.size.x - pad * 2.0)
	var height := pad * 2.0 + heads.size() * (g + roundf(4.0 * s)) - roundf(4.0 * s) + roundf(10.0 * s) \
			+ lines.size() * (sg + roundf(8.0 * s)) - roundf(8.0 * s)
	var box := Rect2(column.position.x, roundf(WORDS_TOP * s), column.size.x, height)
	var a := clampf((_time - _since[i]) / WORDS_FADE, 0.0, 1.0)
	var spot: Variant = _bay.spot(i)
	if spot != null:
		var to: Vector2 = spot
		var points := PackedVector2Array()
		if show.has("knee"):
			var x := roundf(_bay.middle(i).x + float(show.knee) * _bay.zoom * s * (1.0 if i == 0 else -1.0))
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
	for head in heads:
		Level3DFont.draw(_text, head, roundf(box.position.x + pad), y, g, Level3DFont.WHITE, Color(colour, a))
		y += g + roundf(4.0 * s)
	y += roundf(6.0 * s)
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
	# Where the tables stand and the camera looks from, level metres: a jeep
	# in the middle of either player's column, side on clear of the frame's
	# edge and of the matrix, between the two places of his words.
	const SPOT := Vector3(2.85, 0.0, -0.2)
	const CAMERA_AT := Vector3(0.0, 3.8, 6.2)
	const LOOK_AT := Vector3(0.0, -0.3, -0.9)
	const FOV := 36.0
	# One concrete, the stage's helipad's (Helipad in its glb) and duller
	# (CONCRETE_DULL); on it, for each player, the pad's paint only, its
	# circle off his jeep -- with one player CIRCLE_AT, behind it and
	# towards the matrix, where there is room; with two DUO_CIRCLE_AT,
	# straight behind, over him on the screen, the second's mirrored -- and
	# its arrow on to him, his jeep at STOP; the paint PAD_SCALE of the stage's, the jeep being
	# as it is. On the circle the Littlebird that brought the supply, in his
	# jeep's paint, three quarters, its nose HELI_YAW round to the camera and
	# the frame's edge, smaller with two players.
	const STAGE := "res://resources/3d/jackal_stage1.glb"   # level3d_preview.gd's LEVEL_PATH
	const PAD_DULL := 0.45
	const CONCRETE_DULL := 0.25
	const PAD_SCALE := 0.65
	const CIRCLE_AT := Vector3(1.7, 0.0, -1.6)        # with one player
	const DUO_CIRCLE_AT := Vector3(0.2, 0.0, -2.0)    # with two: over his jeep
	const HELI_SCALE := 0.85
	const DUO_HELI_SCALE := 0.78
	const HELI_YAW := deg_to_rad(20.0)
	# The supply round the helicopter (jackal_supply.glb, its props life size
	# and here as the units are, MODEL_SCALE, PROP_SCALE larger to be read by
	# the jeep): off its circle's middle, mirrored for the second player's,
	# each [prop, offset -- x, z in shop metres, y up in the prop's own,
	# what it is stacked on -- yaw].
	const SUPPLY := "res://resources/3d/jackal_supply.glb"
	const PROP_SCALE := 1.3
	const PREFIX_SUPPLY := "Supply_"
	const CRATES_BY_HELI := [
			["Pallet", Vector3(-0.95, 0.0, -0.85), 0.1],
			["CrateLong", Vector3(-0.95, 0.15, -0.85), 0.1],
			["AmmoBox", Vector3(-1.0, 0.57, -0.84), 0.45],
			["CrateSquare", Vector3(-0.3, 0.0, -1.25), -0.2],
			["Drum", Vector3(-1.45, 0.0, -0.3), 0.0],
			["Drum", Vector3(-1.62, 0.0, -0.58), 0.6],
			["AmmoBox", Vector3(0.42, 0.0, -1.3), 0.3]]
	# The Littlebird as Level3DBtr.paint_model takes a vehicle: its olive
	# body's hues, and the turn of BLUE that puts it on the blue jeep's.
	const LITTLEBIRD := {"path": "res://resources/3d/jackal_littlebird.glb", "blue": Vector3(60.0, 100.0, 128.0)}
	# With one player: his jeep SOLO_ZOOM times as large, the camera that
	# much nearer along the same line to it -- so it is seen as with two, the
	# views and knees as they are -- and the lens shifted for the table's
	# middle to stand at SOLO_AT in the 2048 x 1152 frame.
	const SOLO_ZOOM := 1.4
	const SOLO_AT := Vector2(470.0, 660.0)
	# With two, the tables' middle this low: the first's pad's circle and
	# its helicopter, behind him, want the room over him.
	const DUO_Y := 760.0

	var staged := false
	var viewport: SubViewport
	var _tables: Array[Node3D] = []
	var _jeeps: Array[Level3DBtr] = []
	var _yaw: Array[float] = []
	var _want: Array[float] = []
	var _ghosts: Array = []         # per player, the meshes on trial
	var _spots: Array = []          # per player, the line's end on his jeep, its frame; null for none
	var _driving := -1.0             # seconds since drive_off, -1 before
	var _helis: Array = []          # per player, the helicopter by his jeep, in its paint
	var _camera: Camera3D
	var _time := 0.0
	var zoom := 1.0                 # the jeep's size, as with two players

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

	# The bay for `players` jeeps, each in his paint (`paints`).
	func stage(players: int, paints: Array[String]) -> void:
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
		var concrete := ShaderMaterial.new()
		concrete.shader = CONCRETE
		concrete.set_shader_parameter("albedo", _concrete())
		concrete.set_shader_parameter("slabs", _slabs())
		concrete.set_shader_parameter("grain", GRAIN)
		concrete.set_shader_parameter("tile", SLAB * SLABS)
		concrete.set_shader_parameter("slab", SLAB)
		concrete.set_shader_parameter("contrast", GRAIN_CONTRAST)
		ground.material_override = concrete
		root.add_child(ground)
		var camera := Camera3D.new()
		camera.fov = FOV
		root.add_child(camera)
		zoom = SOLO_ZOOM if players == 1 else 1.0
		var first := Vector3(-SPOT.x, SPOT.y, SPOT.z)
		camera.look_at_from_position(first + (CAMERA_AT - first) / zoom, first + (LOOK_AT - first) / zoom,
				Vector3.UP)
		camera.current = true
		_camera = camera
		for i in players:
			var table := Node3D.new()
			table.position = first if i == 0 else Vector3(SPOT.x, SPOT.y, SPOT.z)
			root.add_child(table)
			# Each jeep at the STOP of a landing spot of his own on the
			# concrete, the second's mirrored, the helicopter that brought
			# the supply standing on its circle, in the jeep's paint, the
			# crates round it.
			var heli: Node3D = null
			var pad := _helipad()
			if pad != null:
				root.add_child(pad)
				heli = _land(root, pad, table.position, 1.0 if i == 0 else -1.0)
				if i == 0:
					_lay(ground.material_override, pad, players > 1)
			_helis.append(heli)
			var jeep := Level3DBtr.new()
			table.add_child(jeep)
			if i < paints.size():
				jeep.paint(paints[i])
				_paint_heli(i, paints[i])
			_tables.append(table)
			_jeeps.append(jeep)
			_yaw.append(30.0)
			_want.append(30.0)
			_ghosts.append([])
			_spots.append(null)
		staged = true
		visible = true

	# Every jeep turned forward and driving off its spot (Level3DShop.DRIVE_*).
	func drive_off() -> void:
		_driving = 0.0
		for i in _want.size():
			_want[i] = Level3DShop.DRIVE_VIEW

	func clear() -> void:
		_driving = -1.0
		for child in viewport.get_children():
			child.queue_free()
		_tables.clear()
		_jeeps.clear()
		_yaw.clear()
		_want.clear()
		_ghosts.clear()
		_spots.clear()
		_helis.clear()
		_camera = null
		zoom = 1.0
		staged = false
		visible = false

	# A copy of the stage's helipad, its lamps and markings; null if the
	# stage has none. The stage is made once for it, and only the pad kept.
	static var _pad: PackedScene

	static func _helipad() -> Node3D:
		if _pad == null:
			_pad = PackedScene.new()
			var stage: Node = (load(STAGE) as PackedScene).instantiate()
			var pad := stage.find_child("Helipad", true, false) as Node3D
			if pad != null:
				pad.get_parent().remove_child(pad)
				pad.transform = Transform3D.IDENTITY
				# Without its lamps, which stand out over the matrix and the
				# swatches, and duller, the concrete and the paint, so that
				# the frame's words stay what is read.
				for beacon in pad.find_children("Beacon*", "", false, false):
					pad.remove_child(beacon)
					beacon.free()
				# Its slab, apron and kerb hidden: the paint is on the one
				# concrete, which is the slab's colour (_concrete).
				for name in ["Helipad_Pad", "Helipad_Apron", "Helipad_Kerb"]:
					var part := pad.find_child(name, true, false) as Node3D
					if part != null:
						part.visible = false
				for node in pad.find_children("*", "MeshInstance3D", true, false):
					var mesh := node as MeshInstance3D
					for surface in mesh.mesh.get_surface_count():
						var material := mesh.get_active_material(surface) as StandardMaterial3D
						if material == null or material.resource_name.ends_with("Contour"):
							continue
						var dull := material.duplicate() as StandardMaterial3D
						dull.albedo_color = material.albedo_color.darkened(PAD_DULL)
						mesh.set_surface_override_material(surface, dull)
				for node in pad.find_children("*", "", true, false):
					node.owner = pad
				_pad.pack(pad)
				pad.free()
			stage.free()
		return _pad.instantiate() as Node3D if _pad.can_instantiate() else null

	# The landing spot's markings laid on the concrete, its arrow from the
	# circle to the jeep at `at`, which stands short of STOP; the Littlebird
	# on the circle, three quarters, its nose to the frame's edge, `side` -1
	# mirroring it all for the second player; the supply round it.
	func _land(root: Node3D, pad: Node3D, at: Vector3, side: float) -> Node3D:
		# The circle at CIRCLE_AT off the jeep, mirrored for the second
		# (`side` -1), the arrow on to him.
		var off := CIRCLE_AT if zoom != 1.0 else DUO_CIRCLE_AT
		var target := at + Vector3(off.x * side, off.y, off.z)
		var way := Vector3(at.x - target.x, 0.0, at.z - target.z).normalized()
		pad.rotation.y = atan2(-way.z, way.x)
		pad.scale = Vector3.ONE * PAD_SCALE
		var circle := _box_of(pad, "Helipad_Disc")
		pad.position = target - pad.basis * Vector3(circle.get_center().x, 0.0, circle.get_center().z)
		# The paint down on the concrete, the slab's top at the ground's.
		pad.position.y = -_box_of(pad, "Helipad_Pad").end.y * PAD_SCALE + 0.005
		var middle := pad.transform * Vector3(circle.get_center().x, 0.0, circle.get_center().z)
		middle.y = 0.0
		_crates(root, middle, CRATES_BY_HELI, side)
		var heli: Node3D = (load(LITTLEBIRD.path) as PackedScene).instantiate()
		root.add_child(heli)
		heli.scale = Vector3.ONE * Level3DBtr.MODEL_SCALE * (HELI_SCALE if zoom != 1.0 else DUO_HELI_SCALE)
		heli.position = middle
		# Three quarters, its nose to the frame's edge and the camera.
		heli.rotation.y = HELI_YAW * side
		return heli

	# The concrete's slabs, SLAB m, laid along `pad`, the first landing
	# spot: its circle in the middle of one; the second's half mirrored.
	func _lay(concrete: ShaderMaterial, pad: Node3D, mirror: bool) -> void:
		var circle := _box_of(pad, "Helipad_Disc").get_center()
		var corner := pad.transform * Vector3(circle.x, 0.0, circle.z) 				- pad.basis.orthonormalized() * Vector3(SLAB, 0.0, SLAB) * 0.5
		concrete.set_shader_parameter("origin", Vector2(corner.x, corner.z))
		concrete.set_shader_parameter("angle", pad.rotation.y)
		concrete.set_shader_parameter("mirror", mirror)

	# Player `i`'s helicopter in his jeep's paint `id`, from its own colours.
	func _paint_heli(i: int, id: String) -> void:
		if i >= _helis.size() or _helis[i] == null:
			return
		var heli: Node3D = _helis[i]
		for node in heli.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			for surface in mesh.get_surface_override_material_count():
				mesh.set_surface_override_material(surface, null)
		Level3DBtr.paint_model(heli, LITTLEBIRD, id)

	# The concrete everywhere: the pad's own, as dull.
	static func _concrete() -> Color:
		var pad := _helipad()
		if pad == null:
			return GROUND
		var slab := pad.find_child("Helipad_Pad", true, false) as MeshInstance3D
		var material := slab.get_active_material(0) as StandardMaterial3D if slab != null else null
		var colour := material.albedo_color if material != null else GROUND
		pad.free()
		return colour.darkened(CONCRETE_DULL)

	# The supply's props `crates` (CRATES_BY_HELI) off `at`, `side` -1
	# mirroring them.
	static func _crates(root: Node3D, at: Vector3, crates: Array, side: float) -> void:
		var scene := load(SUPPLY) as PackedScene
		if scene == null:
			return
		var props: Node = scene.instantiate()
		var size := Level3DBtr.MODEL_SCALE * PROP_SCALE
		for c in crates:
			var prop := props.find_child(PREFIX_SUPPLY + String(c[0]), true, false) as Node3D
			if prop == null:
				continue
			var copy := prop.duplicate() as Node3D
			root.add_child(copy)
			var off: Vector3 = c[1]
			copy.position = at + Vector3(off.x * side, off.y * size, off.z)
			copy.rotation = Vector3(0.0, float(c[2]) * side, 0.0)
			copy.scale = Vector3.ONE * size
		props.free()

	static func _box_of(pad: Node3D, name: String) -> AABB:
		var mesh := pad.find_child(name, true, false) as MeshInstance3D
		return mesh.transform * mesh.get_aabb() if mesh != null else AABB()

	# The concrete's slabs, SLABS by SLABS of them a side, SLAB m each,
	# tiled: each a flat tone of its own (within SLAB_TONE), warmer than grey
	# (SLAB_WARM), dark seams (SEAM_TONE) between. Low in contrast: the words
	# are drawn over it.
	const SLAB := 4.0
	const SLABS := 4
	const SLAB_PIXELS := 128
	const SLAB_TONE := 0.09
	const SLAB_WARM := Color(1.0, 0.97, 0.92)
	const SEAM_PIXELS := 2
	const SEAM_TONE := 0.78
	static var _slab_texture: ImageTexture

	static func _slabs() -> ImageTexture:
		if _slab_texture != null:
			return _slab_texture
		var side := SLABS * SLAB_PIXELS
		var image := Image.create(side, side, false, Image.FORMAT_RGB8)
		var random := RandomNumberGenerator.new()
		random.seed = 1985
		for sy in SLABS:
			for sx in SLABS:
				var tone := 1.0 - SLAB_TONE + random.randf() * SLAB_TONE
				var colour := SLAB_WARM * tone
				image.fill_rect(Rect2i(sx * SLAB_PIXELS, sy * SLAB_PIXELS, SLAB_PIXELS, SLAB_PIXELS), colour)
				var seam := colour * SEAM_TONE
				image.fill_rect(Rect2i(sx * SLAB_PIXELS, sy * SLAB_PIXELS, SLAB_PIXELS, SEAM_PIXELS / 2), seam)
				image.fill_rect(Rect2i(sx * SLAB_PIXELS, (sy + 1) * SLAB_PIXELS - SEAM_PIXELS / 2, SLAB_PIXELS, SEAM_PIXELS / 2), seam)
				image.fill_rect(Rect2i(sx * SLAB_PIXELS, sy * SLAB_PIXELS, SEAM_PIXELS / 2, SLAB_PIXELS), seam)
				image.fill_rect(Rect2i((sx + 1) * SLAB_PIXELS - SEAM_PIXELS / 2, sy * SLAB_PIXELS, SEAM_PIXELS / 2, SLAB_PIXELS), seam)
		image.generate_mipmaps()
		_slab_texture = ImageTexture.create_from_image(image)
		return _slab_texture

	# The concrete's grain, one slab's (a CC0 photograph, grey, square),
	# GRAIN_CONTRAST of its contrast kept.
	const CONCRETE := preload("res://src/game3d/shop/level3d_shop_concrete.gdshader")
	const GRAIN := preload("res://src/game3d/shop/level3d_shop_concrete.png")
	const GRAIN_CONTRAST := 0.5

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
				# The second's jeep turns the other way, its other side to
				# the camera.
				var f := fraction if i == 0 else Vector3(fraction.x, fraction.y, 1.0 - fraction.z)
				_spots[i] = box.position + box.size * f

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

	# The lens shifted for the one table's middle to stand at SOLO_AT, at
	# whatever size the frame is.
	func _aim_solo() -> void:
		if _camera == null or _tables.is_empty():
			return
		var target := _tables[0].global_position + Vector3.UP * 0.12
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		var at := _camera.unproject_position(target)
		var want := SOLO_AT / Vector2(2048.0, 1152.0) * Vector2(viewport.size)
		if zoom == 1.0:
			# With two the tables stay across, only lower.
			want = Vector2(at.x, DUO_Y / 1152.0 * float(viewport.size.y))
		var depth := (target - _camera.global_position).dot(-_camera.global_basis.z)
		var per_pixel := 2.0 * depth * tan(deg_to_rad(_camera.fov) * 0.5) / float(viewport.size.y)
		_camera.h_offset = (at.x - want.x) * per_pixel
		_camera.v_offset = (want.y - at.y) * per_pixel

	# Player `i`'s jeep in paint `id` (Level3DBtr.PAINTS).
	func paint(i: int, id: String) -> void:
		if i < _jeeps.size():
			_jeeps[i].paint(id)
		_paint_heli(i, id)

	# Player `i`'s jeep to turn `degrees` off facing the camera, towards the
	# frame's middle.
	func turn(i: int, degrees: float) -> void:
		if i < _want.size():
			_want[i] = degrees

	func _process(delta: float) -> void:
		if not staged:
			return
		_time += delta
		_aim_solo()
		var wave := 0.5 + 0.5 * sin(_time * Level3DShop.GHOST_PULSE)
		var pulse := lerpf(Level3DShop.GHOST.x, Level3DShop.GHOST.y, wave)
		var rate := Level3DShop.TURN_RATE
		if _driving >= 0.0:
			_driving += delta
			rate = Level3DShop.DRIVE_TURN_RATE
			# Away from a standstill once its engine has started, each as
			# its own does (Level3DShop.ENGINE_*), nose up while it pulls.
			for k in _jeeps.size():
				var jeep := _jeeps[k]
				var t := maxf(_driving - Level3DShop.DRIVE_DELAY - Level3DShop.ENGINE_STAGGER * k, 0.0)
				var gone := 0.5 * Level3DShop.DRIVE_ACCEL * t * t
				var squat := Level3DShop.DRIVE_SQUAT * clampf(1.0 - t / 0.6, 0.0, 1.0) if t > 0.0 else 0.0
				jeep.carry(Vector3(gone, jeep.position.y, 0.0), 0.0, squat)
		for i in _tables.size():
			_yaw[i] = lerpf(_yaw[i], _want[i], 1.0 - exp(-rate * delta))
			# Nose to the camera is the jeep's +X turned to +Z; the first's
			# turns right to show his side to the middle, the second's left.
			var side := 1.0 if i == 0 else -1.0
			_tables[i].rotation.y = -PI / 2.0 + deg_to_rad(_yaw[i]) * side
			for mesh in _ghosts[i]:
				if is_instance_valid(mesh):
					(mesh as GeometryInstance3D).transparency = pulse
