# The level editor: a program of its own for the 3D levels, not a plugin in
# Godot's editor (docs/level-editor-plan.md, part 2).
#
#     godot --path . src/tools/level_editor.tscn
#
# New makes a level of a given length, the game's 64 tiles across, with the
# Chinook that flies the player in; Open reads any level file under
# assets/level3d/; Save writes it back with its two rasters beside it and the
# polygons traced off them, which is what the Blender builder builds from
# (tools/blender/build_level.py).
#
# Four modes, F1 to F4, each with its page of the sidebar:
#
#   Ground    painted. Land and sea and river are hard-edged brushes, each
#             leaving a band of shore round itself that the slope is built
#             on; forest grows on land; raise, lower, smooth and flatten work
#             the rise of the ground for hills. All of it is Level3DGround's,
#             and what is drawn is Level3DGroundView's picture of it.
#   Nav       the game's grid, painted a square of tiles at a time. On stage
#             1 it is the game's own; on a level made here it comes from the
#             ground (Level3DGround.derive_nav), and what is painted is kept
#             over it -- "nav_paint" in the file, "-" where the ground says --
#             so that painting the ground later still moves it. Auto takes a
#             tile back to the ground's.
#   Entities  the game's triggers, from the list: with a type picked in it
#             a click puts one down, on the difficulties ticked, snapped to
#             the tiles its footprint covers. A click on one picks it
#             whatever the list says, Shift+click adds it or lets go of it,
#             and with nothing in the list a drag over nothing draws a box
#             that picks what it covers (Esc or Select empties the list,
#             Ctrl+A picks all); a drag on a picked one moves them all. A
#             building finds the destruction group its probe cell is in. One
#             the catalogue gives an object -- a gun its bunker, the landing
#             port its pad -- comes with it, and goes where it goes. The
#             line across the map is the row the picked one fires on.
#   Objects   scenery from the catalogue, the same way, and walls and
#             bridges are picked with it; R and Shift+R turn the picked
#             objects, [ and ] scale them. Bridge is drawn instead, a drag
#             from one end to the other, and Wall and Side wall a path, a
#             click to a point (see Paths below) -- held to a multiple of 45
#             degrees unless Shift is down -- laid out as stage 1's are
#             (Level3DStructures); a picked one is dragged whole or by the
#             handles on its points, and its width, height, merlons and,
#             a path, smooth and closed are on the panel. A GATE entity
#             comes with its gate and the destruction group that opens it,
#             both moved with it, and goes into a path it is put down by.
#
# Delete removes what is picked; Esc first leaves putting down, then lets go. Every stroke, placing,
# move and removal is one undo. LevelEditorItems draws what is over the
# ground.
#
#   left drag         paint / place, pick and move
#   middle drag, WASD pan          right drag   turn and tilt
#   wheel             zoom          [ ]          brush size (objects: scale)
#   1-9               ground tools  T            top down / tilted
#   F1-F4             modes         F            the whole level
#   Ctrl+Z, Ctrl+Y    undo, redo    Ctrl+N/O/S   new, open, save
#   Ctrl+B            build         F5           play
#
# Level -> Build saves, then runs the Blender builder in the background on
# the level file, into build/level3d/<name>.glb, and imports what it made;
# Play opens the preview on the level and that glb (src/tools/level3d_preview
# .tscn, --file and --level), building it first when the level is newer, and
# the editor waits minimised until the game is left (--editor: its menu's
# exit is "back to the editor"). Check lists what Level3DIO.check finds, and on
# stage 1 Rebuild flow field writes its assets/level3d/dirs-0.dat from the
# grid (another level's is built when the preview loads it). Blender is the
# Store build's launcher unless user://level_editor.cfg says otherwise
# ([editor] blender="...").
extends Node3D

enum Mode { GROUND, NAV, ENTITIES, OBJECTS }
const MODE_NAMES := ["Ground", "Nav", "Entities", "Objects"]

const LEVEL_DIR := "res://assets/level3d/"
const SETTINGS := "user://level_editor.cfg"
const SIDEBAR_WIDTH := 270.0
const HEADER_HEIGHT := 30.0
const FOOTER_HEIGHT := 26.0

const T := Level3DGround.Tool
const TOOL_NAMES := {
	T.LAND: "Land", T.SEA: "Sea", T.RIVER: "River", T.FOREST: "Forest",
	T.CLEAR_FOREST: "Clear forest", T.RAISE: "Raise", T.LOWER: "Lower",
	T.SMOOTH: "Smooth", T.FLATTEN: "Flatten",
}
const TOOL_ORDER: Array = [T.LAND, T.SEA, T.RIVER, T.FOREST, T.CLEAR_FOREST,
		T.RAISE, T.LOWER, T.SMOOTH, T.FLATTEN]
const TOOL_TIPS := {
	T.LAND: "Land, flat at the sand's height; where it meets water it leaves a shore",
	T.SEA: "Sea, with surf; where it meets land it cuts a shore",
	T.RIVER: "River: water as the sea is, without the surf",
	T.FOREST: "Forest on land: trees by the level's rule",
	T.CLEAR_FOREST: "Takes the forest away",
	T.RAISE: "Raises the ground, most at the middle of the brush",
	T.LOWER: "Lowers what was raised, down to the land's own height",
	T.SMOOTH: "Evens out the rise",
	T.FLATTEN: "Brings the rise to what it was where the stroke began",
}
const HEIGHT_TOOLS: Array = [T.RAISE, T.LOWER, T.SMOOTH, T.FLATTEN]
const SHORE_TOOLS: Array = [T.LAND, T.SEA, T.RIVER]
# The nav brush's choices: "auto" (the ground's), then MapIO's types.
const NAV_AUTO := -1
# How far apart the dabs of a stroke are, in brush radii.
const DAB_SPACING := 0.25
const REFRESH_EVERY := 0.06
const TURN := 15.0
# The Objects page's tools: put a piece down, or draw a wall or a bridge.
enum Build { PLACE, WALL, SIDE, BRIDGE }
# What a press on the Objects page may change: a path moved takes the gates
# it goes through with it, and they their groups.
const OBJECT_KEYS := ["objects", "walls", "bridges", "paths", "entities", "groups"]
const ENTITY_KEYS := ["entities", "objects", "groups", "paths"]
# PLACE is the pointer: it picks, and puts down what the list has picked.
const BUILD_NAMES := ["Select", "Wall", "Side wall", "Bridge"]
const SNAP := 0.05
const BASE_BLEND := "res://resources/3d/jackal_stage1_lowpoly.blend"
const BUILDER := "res://tools/blender/build_level.py"
const BUILD_DIR := "res://build/level3d/"
const PREVIEW := "res://src/tools/level3d_preview.tscn"

var doc := {}
var path := ""
var ground: Level3DGround
var view: Level3DGroundView
var items: LevelEditorItems
var dirty := false
var mode: Mode = Mode.GROUND
var tool: Level3DGround.Tool = T.LAND
var radius := 1.5
var strength := 0.1
var shore := Level3DGround.SHORE
var nav_type := MapIO.TYPE_SOLID
var nav_brush := 1

# Each entry either {"ground": tiles} (a stroke's, Level3DGround.swap) or
# {"doc": {key: what doc[key] was, ...}}.
var _undo: Array = []
var _redo: Array = []
var _painting := false
var _last_dab := Vector2.INF
var _flat_target := 0.0
var _pending := Rect2i()
var _since_refresh := 0.0
# The nav the ground makes, worked out when it is wanted after the ground
# changed; empty until then.
var _derived: Array = []

# Picking and moving: what is being dragged, from how far off its middle, and
# whether the drag has changed anything yet (a click that only picks is no
# undo).
var _drag_id := ""
var _drag_changed := false
# A drag moves everything picked by where the pointer has gone since it was
# pressed: the point pressed, and each item's place then (id -> its "pos", or
# a wall's or bridge's [from, to]).
var _drag_start := Vector2.ZERO
var _drag_orig := {}
# What the drag moves: what is picked, a piece that belongs to an entity by
# its entity -- a gate's frame, a gun's bunker go where their owner goes.
var _drag_movers: Array = []
# A box drawn over the screen to pick with, from where it was pressed.
var _boxing := false
var _box_from := Vector2.ZERO
var _box_rect: ColorRect
var _nav_painting := false
var build: Build = Build.PLACE
# The wall or bridge being drawn, and where its drag began.
var _drawing := ""
var _draw_from := Vector2.ZERO
# The path being drawn, a point to a click: its last point follows the
# pointer until the next click puts it down.
var _path_drawing := ""
# The picked structure's point being dragged by its handle, or -1.
var _handle_drag := -1

var _camera: Camera3D
var _focus := Vector2.ZERO
var _distance := 40.0
var _pitch := 90.0
var _yaw := 0.0
var _dragging := -1
var _cursor: MeshInstance3D
var _mouse := Vector2.ZERO

var _ui: Control
var _footer: Label
var _pages := {}
var _mode_buttons := {}
var _tool_buttons := {}
var _radius_slider: HSlider
var _strength_slider: HSlider
var _shore_slider: HSlider
var _nav_buttons := {}
var _nav_auto: Button
var _nav_brush: SpinBox
var _entity_list: ItemList
var _entity_types: Array = []
var _new_normal: CheckBox
var _new_hard: CheckBox
var _entity_info: Label
var _entity_normal: CheckBox
var _entity_hard: CheckBox
var _entity_group: SpinBox
var _entity_box: Control
var _entity_multi: Label
var _object_multi: Label
var _asset_list: ItemList
var _assets: Array = []
var _object_info: Label
var _object_yaw: SpinBox
var _object_scale: SpinBox
var _object_box: Control
var _build_buttons := {}
var _structure_box: Control
var _structure_info: Label
var _structure_width: SpinBox
var _structure_height: SpinBox
var _structure_merlons: CheckBox
var _structure_smooth: CheckBox
var _structure_closed: CheckBox
var _syncing := false
var _open_dialog: FileDialog
var _save_dialog: FileDialog
var _new_dialog: ConfirmationDialog
var _new_name: LineEdit
var _new_rows: SpinBox
var _new_start: OptionButton
var _confirm: ConfirmationDialog
var _message: AcceptDialog
var _after_confirm: Callable
var _level_menu: PopupMenu
# The build under way: {"pid", "step" ("blender" or "import"), "started"}.
var _job := {}
# Play: a build it is waiting for, and the game while it runs -- its pid and
# the window mode the editor is given back in when it ends.
var _play_after_build := false
var _game := {}


func _ready() -> void:
	_build_world()
	_build_ui()
	var config := ConfigFile.new()
	config.load(SETTINGS)
	var last: String = config.get_value("editor", "last", Level3DIO.path(0))
	if not FileAccess.file_exists(last):
		last = Level3DIO.path(0)
	_open(last)


# --- The world ----------------------------------------------------------------


func _build_world() -> void:
	view = Level3DGroundView.new()
	view.name = "Ground"
	add_child(view)
	items = LevelEditorItems.new()
	items.name = "Items"
	add_child(items)
	_camera = Camera3D.new()
	_camera.fov = 40.0
	_camera.far = 800.0
	add_child(_camera)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 135, 0)
	add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.12, 0.13, 0.15)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	add_child(environment)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.96
	ring.outer_radius = 1.0
	ring.rings = 48
	ring.ring_segments = 4
	var cursor_material := StandardMaterial3D.new()
	cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_material.albedo_color = Color(1, 1, 1, 0.9)
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.no_depth_test = true
	ring.material = cursor_material
	_cursor = MeshInstance3D.new()
	_cursor.mesh = ring
	_cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_cursor)


func _place_camera() -> void:
	_camera.rotation = Vector3(-deg_to_rad(_pitch), deg_to_rad(_yaw), 0.0)
	_camera.position = Vector3(_focus.x, 0.0, _focus.y) + _camera.basis.z * _distance


func _frame_level() -> void:
	var b := ground.bounds()
	_focus = b.get_center()
	# The level's width across the window, or the window's height up its
	# length when that is the tighter fit.
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var fit := maxf(b.size.x / aspect, b.size.y * 0.25)
	_distance = fit * 0.5 / tan(deg_to_rad(_camera.fov * 0.5))
	# A long level is looked at from its start, the south end.
	_focus.y = b.end.y - fit * 0.5
	_place_camera()


# Where the pointer meets the ground, or null: the ray down to the water's
# plane, then walked onto the picture's heights.
func _hit(at: Vector2) -> Variant:
	var origin := _camera.project_ray_origin(at)
	var direction := _camera.project_ray_normal(at)
	if direction.y > -1e-4:
		return null
	var h := 0.0
	var p := Vector2.ZERO
	for i in 5:
		var t := (h - origin.y) / direction.y
		var q := origin + direction * t
		p = Vector2(q.x, q.z)
		h = view.height_at(p)
	return p


# --- Undo ------------------------------------------------------------------------


# Keeps what the document's lists are now as the undo of what is about to be
# done to them: one key, or several changed together.
func _record(keys: Variant) -> void:
	var was := {}
	# A list the level does not have yet comes back as not there: undoing the
	# first path takes "paths" away again, and stage 1's file never has one.
	for key in ([keys] if keys is String else keys):
		was[key] = (doc[key] as Array).duplicate(true) if doc.has(key) else null
	_undo.append({"doc": was})
	_redo.clear()
	_set_dirty(true)


func _undo_step(from: Array, to: Array) -> void:
	if from.is_empty() or _painting or _drag_id != "" or _nav_painting or _drawing != "" or _boxing \
			or _path_drawing != "":
		return
	var entry: Dictionary = from.pop_back()
	if entry.has("ground"):
		var swapped := ground.swap(entry["ground"])
		to.append({"ground": swapped[0]})
		var r: Rect2i = swapped[1]
		_pending = r if not _pending.has_area() else _pending.merge(r)
		_flush()
	else:
		var now := {}
		for key in entry["doc"]:
			now[key] = (doc[key] as Array).duplicate(true) if doc.has(key) else null
			if entry["doc"][key] == null:
				doc.erase(key)
			else:
				doc[key] = entry["doc"][key]
		to.append({"doc": now})
		for key in entry["doc"]:
			_refresh_doc(key)
	_set_dirty(true)


# Draws a list of the document again after it was replaced whole.
func _refresh_doc(key: String) -> void:
	match key:
		"entities", "objects":
			var picked := items.selected()
			items.setup(doc, view.height_at, ground.rise_at)
			if not items.find_entity(picked).is_empty() or not items.find_object(picked).is_empty():
				items.select(picked)
			_sync_selection()
		"nav", "nav_paint":
			_show_nav()
		"walls", "bridges", "paths":
			var picked := items.selected()
			items.setup(doc, view.height_at, ground.rise_at)
			if not items.find_structure(picked).is_empty():
				items.select(picked)
			_derived = []
			_sync_selection()
		"groups":
			_derived = []


func _redo_step() -> void:
	_undo_step(_redo, _undo)


# --- Painting the ground ---------------------------------------------------------


func _begin_stroke(at: Vector2) -> void:
	_painting = true
	_last_dab = Vector2.INF
	_flat_target = ground.rise_at(at)
	ground.begin_stroke()
	_stroke_to(at)


func _stroke_to(at: Vector2) -> void:
	var step := maxf(radius * DAB_SPACING, ground.grid.r)
	if _last_dab == Vector2.INF:
		_dab(at)
		_last_dab = at
		return
	var gap := _last_dab.distance_to(at)
	var n := floori(gap / step)
	for k in n:
		_last_dab = _last_dab.move_toward(at, step)
		_dab(_last_dab)


func _dab(at: Vector2) -> void:
	var r := ground.dab(tool, at, radius, strength, shore, _flat_target)
	if r.has_area():
		_pending = r if not _pending.has_area() else _pending.merge(r)
		_set_dirty(true)


func _end_stroke() -> void:
	_painting = false
	var tiles := ground.end_stroke()
	if not tiles.is_empty():
		_undo.append({"ground": tiles})
		_redo.clear()
	_flush()


func _flush() -> void:
	if _pending.has_area():
		view.refresh(_pending)
		_pending = Rect2i()
		_derived = []
		_lift_items()
	_since_refresh = 0.0


# The entities and objects stand on the ground; when it moves under them they
# are put back on it.
func _lift_items() -> void:
	for e in doc["entities"]:
		items.update_entity(e)
	for o in doc["objects"]:
		items.update_object(o)
	for w in doc.get("walls", []):
		items.update_wall(w)


# --- The nav grid ----------------------------------------------------------------


func _derives_nav() -> bool:
	return doc.has("nav_paint")


# The grid as it plays: stage 1's as painted; another level's the ground's
# with what was painted over it.
func _nav_rows() -> Array:
	if not _derives_nav():
		return doc["nav"]
	if _derived.is_empty():
		_derived = ground.derive_nav(doc)
	var out: Array = []
	var paint: Array = doc["nav_paint"]
	for y in _derived.size():
		var row: String = _derived[y]
		var over: String = paint[y]
		if over.count("-") == over.length():
			out.append(row)
			continue
		var chars := ""
		for x in row.length():
			chars += row[x] if over[x] == "-" else over[x]
		out.append(chars)
	return out


func _show_nav() -> void:
	items.show_nav(_nav_rows() if mode == Mode.NAV else [], mode == Mode.NAV)


func _paint_nav(p: Vector2) -> void:
	var centre := items.tile_at(p)
	if centre.x < 0:
		return
	var key := "nav_paint" if _derives_nav() else "nav"
	var rows: Array = doc[key]
	var char_ := "-" if nav_type == NAV_AUTO else MapIO.TYPE_CHAR[nav_type]
	var reach := nav_brush / 2
	var changed := false
	for y in range(maxi(centre.y - reach, 0), mini(centre.y + reach + 1, rows.size())):
		var row: String = rows[y]
		var chars := row
		for x in range(maxi(centre.x - reach, 0), mini(centre.x + reach + 1, row.length())):
			if chars[x] != char_:
				chars = chars.substr(0, x) + char_ + chars.substr(x + 1)
		if chars != row:
			rows[y] = chars
			changed = true
	if changed:
		_set_dirty(true)
		_show_nav()


# --- Entities and objects ---------------------------------------------------------


func _unique_id(stem: String) -> String:
	var taken := {}
	for e in doc["entities"]:
		taken[e["id"]] = true
	for o in doc["objects"]:
		taken[o["id"]] = true
	for key in LevelEditorItems.STRUCTURE_KEYS:
		for st in doc.get(key, []):
			taken[st["id"]] = true
	var n := 0
	while taken.has("%s_%d" % [stem, n]):
		n += 1
	return "%s_%d" % [stem, n]


# Entities and Objects pick the same way. A click on an item picks it --
# Shift adds it to what is picked or lets go of it -- and a drag from one
# moves everything picked. A press on nothing puts down what the list has
# picked, or, with nothing picked in the list, draws a box to pick with. So
# the list is what puts things down, and Esc or Select lets go of it.
func _press_item(p: Vector2, id: String, keys: Array) -> bool:
	if id == "":
		return false
	if Input.is_key_pressed(KEY_SHIFT):
		items.toggle(id)
		_sync_selection()
		return true
	if not items.is_selected(id):
		items.select(id)
	else:
		# Picked already: it becomes the one the panel shows.
		var ids := items.selection()
		ids.erase(id)
		ids.append(id)
		items.select_many(ids)
	_sync_selection()
	_begin_drag(p, keys)
	return true


func _begin_drag(p: Vector2, keys: Array) -> void:
	_record(keys)
	_drag_id = items.selected()
	_drag_changed = false
	_drag_start = p
	_drag_orig = {}
	_drag_movers = []
	for id in items.selection():
		var piece := items.find_object(id)
		if not piece.is_empty() and not items.find_entity(piece.get("entity", "")).is_empty():
			id = piece["entity"]
		if not _drag_movers.has(id):
			_drag_movers.append(id)
	for id in _drag_movers:
		var e := items.find_entity(id)
		if not e.is_empty():
			_drag_orig[id] = e["pos"].duplicate()
			for o in _belonging_to(id):
				_drag_orig[o["id"]] = o["pos"].duplicate()
		var o := items.find_object(id)
		if not o.is_empty():
			_drag_orig[id] = o["pos"].duplicate()
		var st := items.find_structure(id)
		if not st.is_empty():
			if Level3DStructures.is_path(st):
				_drag_orig[id] = (st["points"] as Array).duplicate(true)
				for gate in Level3DStructures.gates_in(st):
					_drag_orig[gate] = items.find_entity(gate)["pos"].duplicate()
					for piece in _belonging_to(gate):
						_drag_orig[piece["id"]] = piece["pos"].duplicate()
			else:
				_drag_orig[id] = [st["from"].duplicate(), st["to"].duplicate()]


func _begin_box() -> void:
	_boxing = true
	_box_from = _mouse
	_box_rect.position = _mouse
	_box_rect.size = Vector2.ZERO
	_box_rect.visible = true


# What the box has been drawn over: the items of the page whose anchors
# (LevelEditorItems.anchors) are inside it, added to what is picked with
# Shift. A box too small to be one is a click on nothing, which lets go.
func _end_box() -> void:
	_boxing = false
	_box_rect.visible = false
	var rect := Rect2(_box_from, _mouse - _box_from).abs()
	var ids: Array = items.selection() if Input.is_key_pressed(KEY_SHIFT) else []
	if rect.size.x >= 4.0 or rect.size.y >= 4.0:
		var kinds := ["entities"] if mode == Mode.ENTITIES else ["objects", "structures"]
		var anchors := items.anchors(kinds)
		for id in anchors:
			var at: Vector3 = anchors[id]
			if not _camera.is_position_behind(at) and rect.has_point(_camera.unproject_position(at)) \
					and not ids.has(id):
				ids.append(id)
	items.select_many(ids)
	_sync_selection()


func _page_items() -> Array:
	var kinds := ["entities"] if mode == Mode.ENTITIES else ["objects", "structures"]
	return items.anchors(kinds).keys()


func _press_entity(p: Vector2) -> void:
	var keys := ENTITY_KEYS
	if _press_item(p, items.entity_under(p), keys):
		return
	if _entity_list.get_selected_items().is_empty():
		_begin_box()
		return
	_record(keys)
	var type: String = _entity_types[_entity_list.get_selected_items()[0]]
	var difficulty: Array = []
	if _new_normal.button_pressed:
		difficulty.append("normal")
	if _new_hard.button_pressed:
		difficulty.append("hard")
	var e := _new_entity(type, p, difficulty)
	_put_down(p, e["id"])


# An entity of `type` at `p`, snapped to its tiles, with its group and the
# object the catalogue gives it, and into a wall it is put down on if it is
# a gate. Recorded already.
func _new_entity(type: String, p: Vector2, difficulty: Array) -> Dictionary:
	var at := items.snap_entity(type, p)
	var e := {"id": _unique_id(type.to_lower()), "type": type, "pos": [at.x, at.y],
			"difficulty": difficulty}
	(doc["entities"] as Array).append(e)
	_gate_group(e)
	_reprobe(e)
	items.update_entity(e)
	var asset: String = items.catalog["entities"].get(type, {}).get("object", "")
	if asset != "":
		var o := {"id": _unique_id(asset.to_lower()), "asset": asset,
				"pos": _object_pos(at), "yaw": 0.0, "scale": 1.0, "entity": e["id"]}
		(doc["objects"] as Array).append(o)
		items.update_object(o)
	_fit_gate(e)
	return e


# The entity an asset is only ever a part of, or "": the Gate, whose frame is
# nothing without the GATE that is blown and the group it opens -- a
# destructible the catalogue gives to one entity alone. Put down from the
# Objects page, it is put down as that entity; a bunker, which two guns
# share, and scenery are put down as themselves.
func _entity_for_asset(asset: String) -> String:
	if not items.catalog["assets"].get(asset, {}).has("destructible"):
		return ""
	var types: Array = []
	for type in items.catalog["entities"]:
		if items.catalog["entities"][type].get("object", "") == asset:
			types.append(type)
	return types[0] if types.size() == 1 else ""


func _press_object(p: Vector2) -> void:
	if build != Build.PLACE:
		_press_structure(p)
		return
	for key in ["walls", "bridges"]:
		if not doc.has(key):
			doc[key] = []
	var keys := OBJECT_KEYS
	# A picked wall's, path's or bridge's point, by its handle; Ctrl+click on
	# a picked path puts a new one in where it is clicked.
	var handle := items.handle_under(p)
	if handle < 0 and Input.is_key_pressed(KEY_CTRL):
		handle = _insert_point(p)
	if handle >= 0:
		_begin_handle(p, handle)
		return
	# With an asset picked in the list a click on a wall or a bridge puts the
	# asset down there -- a gate on a wall, a sandbag on a bridge -- and only
	# an object under the pointer is picked instead; with none, walls and
	# bridges are picked too.
	var id := items.object_under(p)
	if id == "" and _asset_list.get_selected_items().is_empty():
		id = items.structure_under(p)
	if _press_item(p, id, keys):
		return
	if _asset_list.get_selected_items().is_empty():
		_begin_box()
		return
	_record(keys)
	var asset: String = _assets[_asset_list.get_selected_items()[0]]
	var owner_type := _entity_for_asset(asset)
	if owner_type != "":
		var e := _new_entity(owner_type, p, ["normal", "hard"])
		var piece: Array = _belonging_to(e["id"])
		_put_down(p, piece[0]["id"] if not piece.is_empty() else e["id"])
		return
	var o := {"id": _unique_id(asset.to_lower()), "asset": asset,
			"pos": _object_pos(p), "yaw": 0.0, "scale": 1.0}
	(doc["objects"] as Array).append(o)
	items.update_object(o)
	_put_down(p, o["id"])


# What was just put down is picked, alone, and follows the pointer until it
# is let go: one undo with its putting down, which is recorded already.
func _put_down(p: Vector2, id: String) -> void:
	items.select(id)
	_sync_selection()
	_begin_drag(p, [])
	_undo.pop_back()
	_drag_changed = true


# An object's place in the file: its height over the ground, which on the
# slope is the slope's and on a hill nothing -- the builder adds the rise.
func _object_pos(p: Vector2) -> Array:
	return [Level3DIO.round_mm(p.x), Level3DIO.round_mm(view.height_at(p) - ground.rise_at(p)),
			Level3DIO.round_mm(p.y)]


# Draws a new wall or bridge from `p`. Picking one to drag it whole is
# Select's (_press_object).
func _press_structure(p: Vector2) -> void:
	for key in ["walls", "bridges"]:
		if not doc.has(key):
			doc[key] = []
	if build != Build.BRIDGE:
		_path_click(p)
		return
	_record(["walls", "bridges"])
	var at := p.snapped(Vector2(SNAP, SNAP))
	var st := Level3DStructures.new_bridge(_unique_id("bridge"), at, at)
	(doc["bridges"] as Array).append(st)
	_drawing = st["id"]
	_draw_from = at
	items.select(_drawing)


# --- Paths ------------------------------------------------------------------------
#
# Wall and Side wall draw a path (Level3DStructures): a click puts a point
# down, and the next follows the pointer -- held to a multiple of 45 degrees
# from the last unless Shift is down -- until the next click; a click on a
# gate takes the wall through it; a click on the first point closes it;
# Enter, a double click or Esc ends it, Backspace takes the last point back.
# The whole drawing is one undo.

func _path_click(p: Vector2) -> void:
	if _path_drawing == "":
		if not doc.has("paths"):
			_record(["paths"])
			doc["paths"] = []
		else:
			_record(["paths"])
		var at := _path_point(p, null)
		var path := Level3DStructures.new_path(_unique_id("wall" if build == Build.WALL else "side"),
				"wall" if build == Build.WALL else "side", [at, at.duplicate()])
		(doc["paths"] as Array).append(path)
		_path_drawing = path["id"]
		_gate_into_drawing(p, true)
		_relay(path)
		items.select(_path_drawing)
		_sync_selection()
		return
	var path := items.find_structure(_path_drawing)
	var elements: Array = path["points"]
	var first: Variant = elements[0]
	if elements.size() >= 3 and not Level3DStructures.is_gate_point(first) \
			and p.distance_to(Vector2(float(first[0]), float(first[1]))) < LevelEditorItems.HANDLE_PICK:
		# The point following the pointer is the first one again.
		elements.pop_back()
		path["closed"] = true
		_end_path()
		return
	match _gate_into_drawing(p, false):
		1:
			_relay(path)
			return
		-1:
			_footer.text = "A wall goes through a gate east to west only: its passage runs north to south, as the game scrolls."
			return
	elements.append((elements[-1] as Array).duplicate())
	_relay(path)


# A click on a gate while drawing: the gate takes the place of the point
# that follows the pointer, and a new one follows on from it -- 1 -- unless
# the wall comes to it from too far off its axis, north to south, which the
# gate refuses -- -1. 0 is no gate there.
func _gate_into_drawing(p: Vector2, first: bool) -> int:
	var gate := items.entity_under(p)
	if gate == "" or items.find_entity(gate)["type"] != "GATE" or _path_through(gate) != "":
		return 0
	var frame := Level3DStructures.gate_frame(doc, gate)
	if frame.is_empty():
		return 0
	var path := items.find_structure(_path_drawing)
	var elements: Array = path["points"]
	if not first and elements.size() >= 2:
		var from := _element_xz(path, elements.size() - 2, true)
		if not Level3DStructures.runs_across(from, frame["at"], frame["axis"]):
			return -1
	var live: Array = elements.pop_back()
	if first:
		# The path starts at the gate.
		elements.clear()
	elements.append({"gate": gate})
	elements.append(live)
	return 1


# The point a click at `p` puts down: to SNAP, and to a multiple of 45
# degrees from `from` unless Shift is down.
func _path_point(p: Vector2, from: Variant) -> Array:
	var to := p.snapped(Vector2(SNAP, SNAP))
	if from != null and not Input.is_key_pressed(KEY_SHIFT):
		var d := to - (from as Vector2)
		var angle := snappedf(d.angle(), PI / 4.0)
		to = ((from as Vector2) + Vector2.from_angle(angle) * d.length()).snapped(Vector2(SNAP, SNAP))
	return _v2a(to)


func _path_hover(p: Vector2) -> void:
	var path := items.find_structure(_path_drawing)
	var elements: Array = path["points"]
	var before: Variant = elements[-2] if elements.size() >= 2 else null
	var from: Variant = null
	if before != null:
		from = Level3DStructures.gate_posts(path, doc, elements.size() - 2)[-1] \
				if Level3DStructures.is_gate_point(before) else _v2(before)
	var at := _path_point(p, from)
	if at != elements[-1]:
		elements[-1] = at
		_relay(path)


func _end_path() -> void:
	var path := items.find_structure(_path_drawing)
	_path_drawing = ""
	if path.is_empty():
		return
	var elements: Array = path["points"]
	if not path["closed"]:
		elements.pop_back()
	if elements.size() < 2:
		# Nothing drawn: the drawing's undo goes, and a "paths" it made.
		(doc["paths"] as Array).erase(path)
		items.remove_structure(path["id"])
		var entry: Dictionary = _undo.pop_back()
		if entry["doc"].get("paths", []) == null:
			doc.erase("paths")
		_sync_selection()
		return
	_relay(path)
	items.select(path["id"])
	_sync_selection()


# Backspace while drawing: the last point put down goes, and with the first
# the whole path.
func _path_back() -> void:
	var path := items.find_structure(_path_drawing)
	var elements: Array = path["points"]
	if elements.size() <= 2:
		# Back past the first point: nothing is drawn.
		elements.resize(1)
		_end_path()
		return
	elements.remove_at(elements.size() - 2)
	_relay(path)


# A path laid out again and drawn: after a point, a setting or one of its
# gates moved. The nav grid a level derives has to be made again.
func _relay(path: Dictionary) -> void:
	Level3DStructures.lay_path(path, doc)
	items.update_path(path)
	_derived = []


func _path_through(gate: String) -> String:
	for path in doc.get("paths", []):
		if Level3DStructures.gates_in(path).has(gate):
			return path["id"]
	return ""


# A gate put down or let go of: if a path goes through it, the path follows;
# if none does and one passes near enough, the gate goes into it, the points
# within its frame giving way to it.
func _fit_gate(e: Dictionary) -> void:
	if e["type"] != "GATE":
		return
	var through := _path_through(e["id"])
	if through != "":
		_relay(items.find_structure(through))
		return
	var frame := Level3DStructures.gate_frame(doc, e["id"])
	if frame.is_empty():
		return
	for path in doc.get("paths", []):
		var place := Level3DStructures.gate_insertion(path, doc, frame["at"], frame["axis"])
		if place.is_empty():
			continue
		var elements: Array = path["points"]
		var at: int = int(place["after"]) + 1
		var inside: Array = place["inside"]
		inside.sort()
		for k in range(inside.size() - 1, -1, -1):
			if elements.size() <= 2:
				break
			elements.remove_at(inside[k])
			if inside[k] < at:
				at -= 1
		elements.insert(clampi(at, 0, elements.size()), {"gate": e["id"]})
		_relay(path)
		return


# A gate deleted: the paths through it close across where it stood.
func _unfit_gate(gate: String) -> void:
	for path in doc.get("paths", []):
		var elements: Array = path["points"]
		for k in range(elements.size() - 1, -1, -1):
			if Level3DStructures.is_gate_point(elements[k]) and elements[k]["gate"] == gate:
				var posts := Level3DStructures.gate_posts(path, doc, k)
				elements.remove_at(k)
				for q in range(posts.size() - 1, -1, -1):
					elements.insert(k, _v2a(posts[q]))
				_relay(path)


# A picked structure's point, dragged by its handle: a path's to SNAP, a
# wall's or bridge's end with its merlons or its piers laid out again.
func _begin_handle(p: Vector2, handle: int) -> void:
	_record(OBJECT_KEYS)
	_handle_drag = handle
	_drag_id = items.selected()
	_drag_changed = false
	_drag_start = p
	items.active_point = handle
	items.update_structure(items.find_structure(_drag_id))
	_sync_selection()


func _drag_handle(p: Vector2) -> void:
	var st := items.find_structure(_drag_id)
	var at := _v2a(p.snapped(Vector2(SNAP, SNAP)))
	if Level3DStructures.is_path(st):
		if st["points"][_handle_drag] == at:
			return
		st["points"][_handle_drag] = at
		_relay(st)
	else:
		var end := "from" if _handle_drag == 0 else "to"
		if st[end] == at:
			return
		st[end] = at
		if items.is_wall(st):
			Level3DStructures.lay_merlons(st)
		else:
			Level3DStructures.lay_bridge(st)
		items.update_structure(st)
		_derived = []
	_drag_changed = true
	_sync_selection()


# Ctrl+click on the picked path: a point put in on the way between the two
# it is nearest the line between, and its index, or -1.
func _insert_point(p: Vector2) -> int:
	var path := items.find_structure(items.selected())
	if path.is_empty() or not Level3DStructures.is_path(path) or items.selection().size() != 1:
		return -1
	var elements: Array = path["points"]
	var n := elements.size()
	var best := -1
	var best_d := INF
	for k in (n if path["closed"] else n - 1):
		var a := _element_xz(path, k, true)
		var b := _element_xz(path, (k + 1) % n, false)
		var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))
		if d < best_d:
			best_d = d
			best = k
	if best < 0 or best_d > float(path["width"]) + 1.0:
		return -1
	elements.insert(best + 1, _v2a(p.snapped(Vector2(SNAP, SNAP))))
	_relay(path)
	return best + 1


# Where element k of a path is, a gate by the post the path leaves it by
# (`leaving`) or comes into it by.
func _element_xz(path: Dictionary, k: int, leaving: bool) -> Vector2:
	var e: Variant = path["points"][k]
	if Level3DStructures.is_gate_point(e):
		var posts := Level3DStructures.gate_posts(path, doc, k)
		if not posts.is_empty():
			return posts[-1] if leaving else posts[0]
	return _v2(e) if not Level3DStructures.is_gate_point(e) else Vector2.ZERO


# Del on a picked path's point whose handle was taken last.
func _delete_point() -> bool:
	var path := items.find_structure(items.selected())
	var k := items.active_point
	if k < 0 or path.is_empty() or not Level3DStructures.is_path(path):
		return false
	var elements: Array = path["points"]
	if elements.size() <= 2 or k >= elements.size():
		return false
	_record(["paths"])
	elements.remove_at(k)
	if elements.size() < 3:
		path["closed"] = false
	items.active_point = -1
	_relay(path)
	_sync_selection()
	return true


static func _v2a(v: Vector2) -> Array:
	return [Level3DIO.round_mm(v.x), Level3DIO.round_mm(v.y)]


func _draw_to(p: Vector2) -> void:
	var st := items.find_structure(_drawing)
	var to := p.snapped(Vector2(SNAP, SNAP))
	if not Input.is_key_pressed(KEY_SHIFT):
		# Held to a multiple of 45 degrees.
		var d := to - _draw_from
		var angle := snappedf(d.angle(), PI / 4.0)
		to = (_draw_from + Vector2.from_angle(angle) * d.length()).snapped(Vector2(SNAP, SNAP))
	st["to"] = [Level3DIO.round_mm(to.x), Level3DIO.round_mm(to.y)]
	if items.is_wall(st):
		Level3DStructures.lay_merlons(st)
		items.update_wall(st)
	else:
		Level3DStructures.lay_bridge(st)
		items.update_bridge(st)


func _end_draw() -> void:
	var st := items.find_structure(_drawing)
	_drawing = ""
	if Level3DStructures.length_of(st) < 0.3:
		# A click, not a drag: nothing drawn.
		(doc["walls" if items.is_wall(st) else "bridges"] as Array).erase(st)
		items.remove_structure(st["id"])
		_undo.pop_back()
		return
	_derived = []
	_sync_selection()


# Everything picked, moved by as much as the pointer has since the press:
# entities by whole tiles -- the ones the one pressed on snaps to, so that
# they keep their places on the grid to one another -- with what belongs to
# them; walls and bridges to SNAP; objects as the pointer goes.
func _drag_to(p: Vector2) -> void:
	if _handle_drag >= 0:
		_drag_handle(p)
		return
	var delta := p - _drag_start
	var tiles := Vector2.ZERO
	var lead_id := _drag_id
	if items.find_entity(lead_id).is_empty():
		for id in _drag_movers:
			if not items.find_entity(id).is_empty():
				lead_id = id
				break
	var lead := items.find_entity(lead_id)
	if not lead.is_empty():
		var from := _v2(_drag_orig[lead_id])
		tiles = items.snap_entity(lead["type"], from + delta) - from
	var moved := false
	for id in _drag_movers:
		if not _drag_orig.has(id):
			continue
		var e := items.find_entity(id)
		if not e.is_empty():
			var from := _v2(_drag_orig[id])
			var at := items.snap_entity(e["type"], from + tiles)
			if at == _v2(e["pos"]):
				continue
			e["pos"] = [at.x, at.y]
			_gate_group(e)
			_reprobe(e)
			items.update_entity(e)
			for o in _belonging_to(id):
				var was: Array = _drag_orig.get(o["id"], o["pos"])
				o["pos"] = _object_pos(Vector2(float(was[0]), float(was[2])) + at - from)
				items.update_object(o)
			# A path through a gate goes where the gate goes.
			var through := _path_through(id)
			if through != "":
				_relay(items.find_structure(through))
			moved = true
			continue
		var st := items.find_structure(id)
		if not st.is_empty() and Level3DStructures.is_path(st):
			if _drag_path(st, delta):
				moved = true
			continue
		if not st.is_empty():
			var ends: Array = _drag_orig[id]
			var by := (_v2(ends[0]) + delta).snapped(Vector2(SNAP, SNAP)) - _v2(ends[0])
			if _v2(ends[0]) + by == _v2(st["from"]):
				continue
			for k in 2:
				var end := _v2(ends[k]) + by
				st[["from", "to"][k]] = [Level3DIO.round_mm(end.x), Level3DIO.round_mm(end.y)]
			if items.is_wall(st):
				items.update_wall(st)
			else:
				items.update_bridge(st)
			_derived = []
			moved = true
			continue
		var o := items.find_object(id)
		if not o.is_empty():
			var was: Array = _drag_orig[id]
			var pos := _object_pos(Vector2(float(was[0]), float(was[2])) + delta)
			if pos != o["pos"]:
				o["pos"] = pos
				items.update_object(o)
				moved = true
	if moved:
		_drag_changed = true
		_sync_selection()


# A path moved whole, by `delta` to SNAP -- or, through gates, by whole tiles,
# the gates going with it on the grid.
func _drag_path(path: Dictionary, delta: Vector2) -> bool:
	var was: Array = _drag_orig[path["id"]]
	var gates := Level3DStructures.gates_in(path)
	var by := delta.snapped(Vector2(SNAP, SNAP))
	if not gates.is_empty():
		var tile := items.tile_m()
		by = Vector2(roundf(delta.x / tile), roundf(delta.y / tile)) * tile
	var elements: Array = path["points"]
	var changed := false
	for k in elements.size():
		if Level3DStructures.is_gate_point(was[k]):
			continue
		var at := _v2a(_v2(was[k]) + by)
		if elements[k] != at:
			elements[k] = at
			changed = true
	for gate in gates:
		var e := items.find_entity(gate)
		var from := _v2(_drag_orig[gate])
		var at := items.snap_entity(e["type"], from + by)
		if at == _v2(e["pos"]):
			continue
		e["pos"] = [at.x, at.y]
		_gate_group(e)
		items.update_entity(e)
		for o in _belonging_to(gate):
			var orig: Array = _drag_orig.get(o["id"], o["pos"])
			o["pos"] = _object_pos(Vector2(float(orig[0]), float(orig[2])) + at - from)
			items.update_object(o)
		changed = true
	if changed:
		_relay(path)
	return changed


static func _v2(a: Array) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# The objects that belong to an entity: a gun's bunker, the landing port's pad.
func _belonging_to(id: String) -> Array:
	return (doc["objects"] as Array).filter(func(o): return o.get("entity", "") == id)


func _release_drag() -> void:
	if not _drag_changed:
		_undo.pop_back()
	# A gate let go of near a path it is not in goes into it.
	if _drag_changed:
		for id in _drag_movers:
			var e := items.find_entity(id)
			if not e.is_empty():
				_fit_gate(e)
	_drag_id = ""
	_drag_orig = {}
	_drag_movers = []
	_handle_drag = -1


# A gate opens the middle of its footprint when it is blown: a destruction
# group of those cells, made for it the first time and moved with it. Stage
# 1's is group 6, which this rewrites to the same cells. Every gate has its
# own, and none has group 0: BossHeadquarters blows groups[0] by number, and
# groups_map reads 0 wherever no group is. A level with no groups yet gets an
# empty group 0 first, which is nobody's.
func _gate_group(e: Dictionary) -> void:
	if e["type"] != "GATE":
		return
	var cells := Level3DStructures.gate_cells(items.entity_tile(e))
	var groups: Array = doc["groups"]
	var index := int(e.get("group", -1))
	for g in groups:
		if index > 0 and int(g["index"]) == index:
			g["cells"] = cells
			_derived = []
			return
	if groups.is_empty():
		groups.append({"index": 0, "cells": []})
	index = 1
	for g in groups:
		index = maxi(index, int(g["index"]) + 1)
	groups.append({"index": index, "cells": cells})
	e["group"] = index
	_derived = []


# A deleted gate takes its group with it. A group is its place in the list
# (Level3DIO.load_stage), so the ones after it move down one, and so do the
# entities that name them. Group 0 stays.
func _drop_group(index: int) -> void:
	if index <= 0:
		return
	var groups: Array = doc["groups"]
	for g in groups.duplicate():
		if int(g["index"]) == index:
			groups.erase(g)
		elif int(g["index"]) > index:
			g["index"] = int(g["index"]) - 1
	for other in doc["entities"]:
		if other.has("group") and int(other["group"]) > index:
			other["group"] = int(other["group"]) - 1
			items.update_entity(other)
	_derived = []


# A building's group is the one its probe cell is in, wherever it goes.
func _reprobe(e: Dictionary) -> void:
	var group := items.probed_group(e["type"], items.entity_tile(e))
	var index: int = MapIO.trigger_constants().get(e["type"], -1)
	if MapIO.GROUP_PROBES.has(index):
		if group >= 0:
			e["group"] = group
		else:
			e.erase("group")


# Removes everything picked, in one undo.
func _delete_selected() -> void:
	if _delete_point():
		return
	var ids := items.selection()
	if ids.is_empty():
		return
	_record(OBJECT_KEYS)
	var any := false
	for id in ids:
		any = _delete_one(id) or any
	if not any:
		_undo.pop_back()
	_sync_selection()


func _delete_one(id: String) -> bool:
	var st := items.find_structure(id)
	if not st.is_empty():
		(doc[items.structure_key(st)] as Array).erase(st)
		items.remove_structure(id)
		_derived = []
		return true
	var e := items.find_entity(id)
	if not e.is_empty():
		if e["type"] == "GATE":
			_unfit_gate(id)
		# And what belongs to it.
		for o in _belonging_to(id):
			(doc["objects"] as Array).erase(o)
			items.remove_object(o["id"])
		(doc["entities"] as Array).erase(e)
		items.remove_entity(id)
		if e["type"] == "GATE":
			_drop_group(int(e.get("group", -1)))
		return true
	var o := items.find_object(id)
	if o.is_empty():
		return false
	(doc["objects"] as Array).erase(o)
	items.remove_object(id)
	return true


# The picked objects, each round its own foot; walls, bridges and entities
# do not turn or scale.
func _picked_objects() -> Array:
	return items.selection().map(func(id): return items.find_object(id)).filter(func(o): return not o.is_empty())


func _turn_selected(degrees: float) -> void:
	var picked := _picked_objects()
	if picked.is_empty():
		return
	_record("objects")
	for o in picked:
		o["yaw"] = snappedf(wrapf(float(o["yaw"]) + degrees, -180.0, 180.0), 0.001)
		items.update_object(o)
	_sync_selection()


func _scale_selected(factor: float) -> void:
	var picked := _picked_objects()
	if picked.is_empty():
		return
	_record("objects")
	for o in picked:
		o["scale"] = snappedf(clampf(float(o["scale"]) * factor, 0.1, 10.0), 0.001)
		items.update_object(o)
	_sync_selection()


# The picked item's page of the sidebar, to what it is now.
func _sync_selection() -> void:
	_syncing = true
	var count := items.selection().size()
	for label in [_entity_multi, _object_multi]:
		label.visible = count > 1
		label.text = "%d picked\nDrag one to move them all; Del deletes\nthem, R and [ ] turn and scale objects.\nShift+click adds or lets go of one." % count
	# One picked is shown on the panel; several are not.
	var one := items.selected() if count == 1 else ""
	_sync_one(one)
	_syncing = false


func _sync_one(id: String) -> void:
	var e := items.find_entity(id)
	_entity_box.visible = not e.is_empty()
	if not e.is_empty():
		var tile := items.entity_tile(e)
		_entity_info.text = "%s\n%s, %s\nrow %d col %d" % [e["id"], e["type"], items.kind_of(e["type"]),
				tile.y, tile.x]
		_entity_normal.button_pressed = (e["difficulty"] as Array).has("normal")
		_entity_hard.button_pressed = (e["difficulty"] as Array).has("hard")
		_entity_group.value = int(e.get("group", -1))
		_entity_group.editable = MapIO.GROUP_PROBES.has(MapIO.trigger_constants().get(e["type"], -1))
	var st := items.find_structure(id)
	_structure_box.visible = not st.is_empty()
	var path := not st.is_empty() and Level3DStructures.is_path(st)
	_structure_smooth.get_parent().visible = path
	if path:
		var gates := Level3DStructures.gates_in(st)
		_structure_info.text = "%s\n%s path, %.2f m, %d points%s%s" % [st["id"], st["kind"],
				Level3DStructures.path_length(st), (st["points"] as Array).size() - gates.size(),
				("\nthrough " + ", ".join(gates)) if not gates.is_empty() else "",
				("\n%d merlons" % (st["merlon_at"] as Array).size()) if st.has("merlons") else ""]
		_structure_width.value = float(st["width"])
		_structure_height.value = float(st["height"])
		_structure_height.editable = true
		_structure_merlons.button_pressed = st.has("merlons")
		_structure_merlons.disabled = false
		_structure_smooth.button_pressed = st["smooth"]
		_structure_closed.button_pressed = st["closed"]
		_structure_closed.disabled = (st["points"] as Array).size() < 3
	elif not st.is_empty():
		var wall := items.is_wall(st)
		_structure_info.text = "%s\n%s, %.2f m long%s" % [st["id"], ("wall, " + st["style"]) if wall else "bridge",
				Level3DStructures.length_of(st),
				("\n%d merlons" % int(st["merlons"]["count"])) if wall and st.has("merlons") else
				("\n%d piers, %d plates" % [st["piers"].size(), int(st["plates"]["count"])]) if not wall else ""]
		_structure_width.value = float(st["width"])
		_structure_height.value = float(st["height"]) if wall else 0.0
		_structure_height.editable = wall
		_structure_merlons.button_pressed = st.has("merlons")
		_structure_merlons.disabled = not wall
	var o := items.find_object(id)
	_object_box.visible = not o.is_empty()
	if not o.is_empty():
		_object_info.text = "%s\n%s%s" % [o["id"], o["asset"],
				("\nbelongs to " + o["entity"]) if o.has("entity") else ""]
		_object_yaw.value = float(o["yaw"])
		_object_scale.value = float(o["scale"])


func _edit_entity(field: String, value: Variant) -> void:
	var e := items.find_entity(items.selected())
	if _syncing or e.is_empty():
		return
	_record("entities")
	match field:
		"normal", "hard":
			var difficulty: Array = []
			for d in ["normal", "hard"]:
				var on: bool = value if d == field else (e["difficulty"] as Array).has(d)
				if on:
					difficulty.append(d)
			e["difficulty"] = difficulty
		"group":
			if int(value) < 0:
				e.erase("group")
			else:
				e["group"] = int(value)
	items.update_entity(e)


func _edit_structure(field: String, value: Variant) -> void:
	var st := items.find_structure(items.selected())
	if _syncing or st.is_empty():
		return
	if Level3DStructures.is_path(st):
		_edit_path(st, field, value)
		return
	_record(["walls", "bridges"])
	match field:
		"width", "height":
			st[field] = snappedf(float(value), 0.01)
		"merlons":
			if value:
				st["merlons"] = {"side": "left", "first": Level3DStructures.MERLON_FIRST,
						"step": Level3DStructures.MERLON_STEP, "count": 0}
				Level3DStructures.lay_merlons(st)
			else:
				st.erase("merlons")
		"flip":
			if st.has("merlons"):
				st["merlons"]["side"] = "right" if st["merlons"]["side"] == "left" else "left"
	if items.is_wall(st):
		items.update_wall(st)
	else:
		Level3DStructures.lay_bridge(st)
		items.update_bridge(st)
	_derived = []
	_sync_selection()


func _edit_path(path: Dictionary, field: String, value: Variant) -> void:
	_record(["paths"])
	match field:
		"width", "height":
			path[field] = snappedf(float(value), 0.01)
		"merlons":
			if value:
				path["merlons"] = {"side": "left", "step": Level3DStructures.MERLON_STEP}
			else:
				path.erase("merlons")
		"flip":
			if path.has("merlons"):
				path["merlons"]["side"] = "right" if path["merlons"]["side"] == "left" else "left"
		"smooth":
			path["smooth"] = bool(value)
		"closed":
			path["closed"] = bool(value) and (path["points"] as Array).size() >= 3
	_relay(path)
	_sync_selection()


func _edit_object(field: String, value: float) -> void:
	var o := items.find_object(items.selected())
	if _syncing or o.is_empty():
		return
	_record("objects")
	o[field] = snappedf(value, 0.001)
	items.update_object(o)


# --- Input ------------------------------------------------------------------------


func _process(delta: float) -> void:
	_poll_job()
	_poll_game()
	_since_refresh += delta
	if _pending.has_area() and _since_refresh >= REFRESH_EVERY:
		_flush()
	var pan := Vector2.ZERO
	if not _typing():
		if Input.is_physical_key_pressed(KEY_A):
			pan.x -= 1.0
		if Input.is_physical_key_pressed(KEY_D):
			pan.x += 1.0
		if Input.is_physical_key_pressed(KEY_W):
			pan.y -= 1.0
		if Input.is_physical_key_pressed(KEY_S) and not Input.is_key_pressed(KEY_CTRL):
			pan.y += 1.0
	if pan != Vector2.ZERO:
		_focus += pan.normalized().rotated(-deg_to_rad(_yaw)) * _distance * 0.8 * delta
		_place_camera()
	_update_cursor()


func _update_cursor() -> void:
	var hit: Variant = _hit(_mouse) if ground else null
	_cursor.visible = hit != null and not _over_ui() and mode in [Mode.GROUND, Mode.NAV]
	if hit == null:
		_footer_text(null)
		return
	var p: Vector2 = hit
	_cursor.position = Vector3(p.x, view.height_at(p) + 0.02, p.y)
	var r := radius if mode == Mode.GROUND else nav_brush * items.tile_m() * 0.5
	_cursor.scale = Vector3(r, 1.0, r)
	_footer_text(p)


func _footer_text(p: Variant) -> void:
	if not _job.is_empty():
		return
	var name := path.get_file() if path != "" else "(new level)"
	var text := "%s%s   %s" % [name, " *" if dirty else "", MODE_NAMES[mode]]
	match mode:
		Mode.GROUND:
			text += ": %s  r %.1f m" % [TOOL_NAMES[tool], radius]
			if tool in HEIGHT_TOOLS:
				text += "  strength %.2f" % strength
			if tool in SHORE_TOOLS:
				text += "  shore %.1f m" % shore
		Mode.NAV:
			text += ": %s  %d tiles" % ["auto" if nav_type == NAV_AUTO else MapIO.TYPE_NAME[nav_type], nav_brush]
		Mode.ENTITIES:
			text += ": %d, %s picked" % [(doc["entities"] as Array).size(), items.selected() if items.selected() != "" else "none"]
		Mode.OBJECTS:
			text += ": %d, %s picked" % [(doc["objects"] as Array).size(), items.selected() if items.selected() != "" else "none"]
	if p != null:
		var at: Vector2 = p
		var bits := ground.bits_at(at)
		var kind := "land" if bits & Level3DGround.LAND else \
				("river" if bits & Level3DGround.RIVER else "sea") if bits & Level3DGround.WATER else "slope"
		if bits & Level3DGround.FOREST:
			kind += ", forest"
		var tile := items.tile_at(at)
		text += "   |  %.2f, %.2f" % [at.x, at.y]
		if tile.x >= 0:
			var nav: String = (_nav_rows()[tile.y] as String)[tile.x] if mode == Mode.NAV else ""
			text += "  row %d col %d%s" % [tile.y, tile.x,
					(" " + MapIO.TYPE_NAME[MapIO.TYPE_CHARS.get(nav, 1)]) if nav != "" else ""]
		text += "  %s  height %.2f m" % [kind, view.height_at(at)]
	_footer.text = text


func _over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered != null and hovered != _ui


func _typing() -> bool:
	return get_viewport().gui_get_focus_owner() is LineEdit \
			or get_viewport().gui_get_focus_owner() is SpinBox


func _unhandled_input(event: InputEvent) -> void:
	if ground == null:
		return
	var button := event as InputEventMouseButton
	if button:
		_mouse = button.position
		match button.button_index:
			MOUSE_BUTTON_LEFT:
				if button.pressed and button.double_click and _path_drawing != "":
					_end_path()
				elif button.pressed:
					var hit: Variant = _hit(button.position)
					if hit != null:
						_press(hit)
				else:
					_release()
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_dragging = button.button_index if button.pressed else -1
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					_distance = maxf(_distance / 1.15, 2.0)
					_place_camera()
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					_distance = minf(_distance * 1.15, 600.0)
					_place_camera()
		return
	var motion := event as InputEventMouseMotion
	if motion:
		_mouse = motion.position
		if _dragging == MOUSE_BUTTON_MIDDLE:
			var metres := _distance * 2.0 * tan(deg_to_rad(_camera.fov * 0.5)) \
					/ get_viewport().get_visible_rect().size.y
			_focus -= motion.relative.rotated(-deg_to_rad(_yaw)) * metres
			_place_camera()
		elif _dragging == MOUSE_BUTTON_RIGHT:
			_yaw -= motion.relative.x * 0.3
			_pitch = clampf(_pitch + motion.relative.y * 0.3, 25.0, 90.0)
			_place_camera()
		elif _path_drawing != "" and _drag_id == "":
			var hit: Variant = _hit(motion.position)
			if hit != null:
				_path_hover(hit)
		elif _boxing:
			_box_rect.position = Vector2(minf(_box_from.x, _mouse.x), minf(_box_from.y, _mouse.y))
			_box_rect.size = (_mouse - _box_from).abs()
		elif _painting or _drag_id != "" or _nav_painting or _drawing != "":
			var hit: Variant = _hit(motion.position)
			if hit != null:
				_move(hit)
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		_key(key)


func _press(p: Vector2) -> void:
	match mode:
		Mode.GROUND:
			_begin_stroke(p)
		Mode.NAV:
			_record("nav_paint" if _derives_nav() else "nav")
			_nav_painting = true
			_paint_nav(p)
		Mode.ENTITIES:
			_press_entity(p)
		Mode.OBJECTS:
			_press_object(p)


func _move(p: Vector2) -> void:
	if _drawing != "":
		_draw_to(p)
	elif _painting:
		_stroke_to(p)
	elif _nav_painting:
		_paint_nav(p)
	elif _drag_id != "":
		_drag_to(p)


func _release() -> void:
	if _boxing:
		_end_box()
	elif _drawing != "":
		_end_draw()
	elif _painting:
		_end_stroke()
	elif _nav_painting:
		_nav_painting = false
	elif _drag_id != "":
		_release_drag()


func _key(key: InputEventKey) -> void:
	var ctrl := key.ctrl_pressed or key.meta_pressed
	if _path_drawing != "":
		match key.keycode:
			KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE:
				_end_path()
				return
			KEY_BACKSPACE:
				_path_back()
				return
	match key.keycode:
		KEY_Z when ctrl and key.shift_pressed:
			_redo_step()
		KEY_Z when ctrl:
			_undo_step(_undo, _redo)
		KEY_Y when ctrl:
			_redo_step()
		KEY_S when ctrl and key.shift_pressed:
			_save_dialog.popup_centered_ratio(0.6)
		KEY_S when ctrl:
			_save()
		KEY_O when ctrl:
			_guard(func(): _open_dialog.popup_centered_ratio(0.6))
		KEY_N when ctrl:
			_guard(func(): _new_dialog.popup_centered())
		KEY_B when ctrl:
			_build()
		KEY_F1, KEY_F2, KEY_F3, KEY_F4:
			_set_mode(key.keycode - KEY_F1)
		KEY_F5:
			_play()
		KEY_BRACKETLEFT:
			if mode == Mode.OBJECTS:
				_scale_selected(1.0 / 1.1)
			elif mode == Mode.NAV:
				_nav_brush.value = nav_brush - 2
			else:
				_radius_slider.value = radius / 1.2
		KEY_BRACKETRIGHT:
			if mode == Mode.OBJECTS:
				_scale_selected(1.1)
			elif mode == Mode.NAV:
				_nav_brush.value = nav_brush + 2
			else:
				_radius_slider.value = radius * 1.2
		KEY_R when mode == Mode.OBJECTS:
			_turn_selected(-TURN if key.shift_pressed else TURN)
		KEY_DELETE, KEY_BACKSPACE:
			_delete_selected()
		KEY_A when ctrl and mode in [Mode.ENTITIES, Mode.OBJECTS]:
			items.select_many(_page_items())
			_sync_selection()
		KEY_ESCAPE:
			# First off a point, then out of putting down, then out of what is
			# picked.
			if items.active_point >= 0:
				items.active_point = -1
				var st := items.find_structure(items.selected())
				if not st.is_empty():
					items.update_structure(st)
			elif not _disarm():
				items.select("")
				_sync_selection()
		KEY_T:
			_pitch = 55.0 if _pitch > 80.0 else 90.0
			_place_camera()
		KEY_F:
			_frame_level()
		_:
			var n := key.keycode - KEY_1
			if mode == Mode.GROUND and n >= 0 and n < TOOL_ORDER.size() and not ctrl:
				_set_tool(TOOL_ORDER[n])


# --- Files ---------------------------------------------------------------------


func _open(file_path: String) -> void:
	var read := Level3DIO.read_path(file_path)
	if read.is_empty() or not read.has("terrain"):
		_tell("Cannot open %s: not a level file with ground." % file_path)
		return
	var of := Level3DGround.load_for(read, file_path.get_base_dir())
	if of == null:
		_tell("Cannot read the rasters of %s." % file_path)
		return
	_start(read, of, file_path)
	_set_dirty(false)
	_remember(file_path)


func _start(new_doc: Dictionary, of: Level3DGround, file_path: String) -> void:
	doc = new_doc
	ground = of
	path = file_path
	_undo.clear()
	_redo.clear()
	_pending = Rect2i()
	_derived = []
	view.setup(doc, ground)
	items.setup(doc, view.height_at, ground.rise_at)
	_show_nav()
	_sync_selection()
	_frame_level()
	get_window().title = "Level editor -- %s" % (path.get_file() if path != "" else "new level")


func _save() -> void:
	if path == "":
		_save_dialog.popup_centered_ratio(0.6)
		return
	_save_to(path)


func _save_to(file_path: String) -> void:
	_footer.text = "Saving %s ..." % file_path.get_file()
	await get_tree().process_frame
	await get_tree().process_frame
	var started := Time.get_ticks_msec()
	var error := ground.save_rasters(doc, file_path.get_base_dir(), file_path.get_file().get_basename())
	if error == OK:
		ground.trace(doc)
		# What the paths make, laid out again from their points and gates as
		# they are now; a level with none keeps no "paths".
		if doc.has("paths") and (doc["paths"] as Array).is_empty():
			doc.erase("paths")
		for path_ in doc.get("paths", []):
			Level3DStructures.lay_path(path_, doc)
		# Stage 1's grid is the game's, and stays; a level made here plays the
		# ground's, with what was painted over it.
		if _derives_nav():
			doc["nav"] = _nav_rows()
		error = Level3DIO.save_path(doc, file_path)
	if error != OK:
		_tell("Saving %s failed (error %d)." % [file_path, error])
		return
	path = file_path
	get_window().title = "Level editor -- %s" % path.get_file()
	_set_dirty(false)
	_remember(path)
	_footer.text = "Saved %s in %.1f s: %d land, %d water, %d forest polygons, %d entities, %d objects" % [
			path.get_file(), (Time.get_ticks_msec() - started) / 1000.0, doc["terrain"]["land"].size(),
			doc["water"].size(), doc["forest"].size(), doc["entities"].size(), doc["objects"].size()]


func _new_level(name: String, rows: int, start: int) -> void:
	var stage := Level3DIO.read(0)
	var profile: Dictionary = stage["terrain"]["profiles"]["shore"] if not stage.is_empty() else \
			{"slope": [[0.0, 0.0], [1.0, -1.0]], "foot": [[0.0, -1.0], [0.1, -1.3]]}
	var new_doc := Level3DIO.new_level(rows, profile)
	var of := Level3DGround.new(Level3DGround.bounds_of(new_doc))
	match start:
		0:
			of.fill(Level3DGround.LAND)
		1:
			of.fill(Level3DGround.LAND)
			# The sea west of the map, as stage 1 has it, and a shore.
			var coast := Level3DMap.ORIGIN.x - 1.0
			for j in of.grid.h:
				for i in of.grid.w:
					var x := of.grid.x0 + (i + 0.5) * of.grid.r
					if x < coast:
						of.ground[j * of.grid.w + i] = Level3DGround.WATER
					elif x < coast + shore:
						of.ground[j * of.grid.w + i] = 0
		2:
			of.fill(Level3DGround.WATER)
	# The Chinook that flies the player in, where stage 1 has it from its
	# south end.
	if not stage.is_empty():
		for e in stage["entities"]:
			if e["type"] == "CHINOOK":
				var sizes := Level3DIO.footprints()
				var tile := Level3DIO.entity_tile(stage["grid"], sizes["CHINOOK"],
						Vector2(float(e["pos"][0]), float(e["pos"][1])))
				tile.y += rows - int(stage["grid"]["height"])
				var at := Level3DIO.entity_pos(new_doc["grid"], sizes["CHINOOK"], tile)
				new_doc["entities"].append({"id": "chinook_0", "type": "CHINOOK",
						"pos": [Level3DIO.round_mm(at.x), Level3DIO.round_mm(at.y)],
						"difficulty": ["normal", "hard"]})
	var file_path := LEVEL_DIR + name + ".json"
	_start(new_doc, of, "")
	if not FileAccess.file_exists(file_path):
		path = file_path
	_set_dirty(true)


func _remember(file_path: String) -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	config.set_value("editor", "last", file_path)
	config.save(SETTINGS)


# Runs `then` now, or after the user agrees to lose the unsaved changes.
func _guard(then: Callable) -> void:
	if not dirty:
		then.call()
		return
	_after_confirm = then
	_confirm.dialog_text = "%s has unsaved changes. Discard them?" % (path.get_file() if path else "The new level")
	_confirm.popup_centered()


func _tell(text: String) -> void:
	_message.dialog_text = text
	_message.popup_centered()


func _set_dirty(value: bool) -> void:
	dirty = value


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_guard(func(): get_tree().quit())


# --- Checking, building and playing ------------------------------------------------


func _check() -> void:
	var checked := doc.duplicate()
	checked["nav"] = _nav_rows()
	var problems := Level3DIO.check(checked, items.catalog)
	if problems.is_empty():
		_tell("Level3DIO.check finds nothing wrong with %s." % (path.get_file() if path else "the level"))
	else:
		_tell("%d problems:\n\n%s" % [problems.size(), "\n".join(problems.slice(0, 30))])


# Stage 1's flow field, from its grid as painted, into assets/level3d/,
# where Level3DMap prefers it to the game's. Another level's is built when
# the preview loads it.
func _rebuild_flow_field() -> void:
	if _derives_nav() or int(doc["stage"]) != Level3DMap.STAGE:
		_tell("Only stage 1 keeps a flow field; the preview builds any other level's as it loads it.")
		return
	_footer.text = "Building the flow field ..."
	await get_tree().process_frame
	var built := Stage.new()
	Level3DIO.load_stage(doc, built, MapIO.load_trigger_sizes())
	FlowField.build(built)
	var error := FlowField.save(Level3DMap.STAGE, built, Level3DIO.DIR)
	_tell("Flow field %s: %s" % ["written" if error == OK else "FAILED (%d)" % error,
			Level3DIO.flow_field_path(Level3DMap.STAGE)])


func _level_name() -> String:
	return path.get_file().get_basename()


func _built_glb() -> String:
	return BUILD_DIR + _level_name() + ".glb"


func _build() -> void:
	if not _job.is_empty():
		return
	if dirty or path == "" or not FileAccess.file_exists(path):
		if path == "":
			_tell("Save the level first: it is built from its file.")
			return
		await _save_to(path)
		if dirty:
			return
	var blender := _blender()
	if blender == "":
		_tell("Blender was not found. Set [editor] blender=\"<path to blender.exe>\" in %s."
				% ProjectSettings.globalize_path(SETTINGS))
		return
	DirAccess.make_dir_recursive_absolute(BUILD_DIR)
	var report := BUILD_DIR + _level_name() + "-report.txt"
	if FileAccess.file_exists(report):
		DirAccess.remove_absolute(report)
	var args := PackedStringArray(["-b", ProjectSettings.globalize_path(BASE_BLEND),
		"--python", ProjectSettings.globalize_path(BUILDER), "--",
		path.trim_prefix("res://"),
		"--out", (BUILD_DIR + _level_name() + ".blend").trim_prefix("res://"),
		"--glb", _built_glb().trim_prefix("res://"),
		"--report", report.trim_prefix("res://")])
	var pid := OS.create_process(blender, args)
	if pid <= 0:
		_tell("Could not start Blender (%s)." % blender)
		return
	_job = {"pid": pid, "step": "blender", "started": Time.get_ticks_msec(), "report": report}


func _blender() -> String:
	var config := ConfigFile.new()
	config.load(SETTINGS)
	var configured: String = config.get_value("editor", "blender", "")
	if configured != "":
		return configured
	var store := OS.get_environment("LOCALAPPDATA").path_join("Microsoft/WindowsApps/blender-launcher.exe")
	return store if FileAccess.file_exists(store) else ""


func _poll_job() -> void:
	if _job.is_empty():
		return
	var seconds := (Time.get_ticks_msec() - int(_job["started"])) / 1000.0
	if OS.is_process_running(int(_job["pid"])):
		_footer.text = "%s %s ... %d s" % ["Building in Blender" if _job["step"] == "blender" else "Importing",
				_level_name(), seconds]
		return
	if _job["step"] == "blender":
		var text := FileAccess.get_file_as_string(_job["report"])
		if text == "" or text.contains("Traceback") or not text.contains("exported"):
			_job = {}
			_play_after_build = false
			var lines := text.strip_edges().split("\n")
			_tell("The build failed. The end of %s:\n\n%s" % [(BUILD_DIR + _level_name() + "-report.txt"),
					"\n".join(lines.slice(maxi(0, lines.size() - 14)))])
			return
		# The preview loads the glb as an imported scene.
		var pid := OS.create_process(OS.get_executable_path(), PackedStringArray([
			"--path", ProjectSettings.globalize_path("res://"), "--headless", "--import"]))
		_job = {"pid": pid, "step": "import", "started": _job["started"]}
		return
	_job = {}
	_footer.text = "Built %s in %d s: %s" % [_level_name(), seconds, _built_glb()]
	if _play_after_build:
		_play_after_build = false
		_play()


# Play: the preview on the level as it is now -- saved and built first when
# the level is newer than its glb -- in a process of its own, with --editor,
# which makes its menu's exit "back to the editor". The editor steps out of
# the way while it runs and comes back when it ends, however it ends: the
# menu, the window's close button, a crash. A process of its own rather than
# the preview inside this one: the preview keeps state in statics
# (Level3DMap.file, the audio buses, the tree's pause, the mouse mode) that
# nothing would put back for the editor afterwards.
func _play() -> void:
	if not _game.is_empty():
		return
	if not _job.is_empty():
		_play_after_build = true
		_footer.text = "Playing once the build is done ..."
		return
	if path == "" or dirty or _needs_build():
		if path == "":
			_tell("Save the level first: it is built from its file.")
			return
		_play_after_build = true
		await _build()
		if _job.is_empty():
			_play_after_build = false
		return
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"), PREVIEW, "--",
		"--file", path, "--level", _built_glb(), "--editor"]))
	if pid <= 0:
		_tell("Could not start the preview.")
		return
	_game = {"pid": pid, "mode": DisplayServer.window_get_mode()}
	_footer.text = "Playing %s ..." % _level_name()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)


# Whether the glb is missing or older than the level file or its rasters.
func _needs_build() -> bool:
	if not ResourceLoader.exists(_built_glb()):
		return true
	var built := FileAccess.get_modified_time(_built_glb())
	var sources: Array = [path]
	var raster: Dictionary = doc.get("terrain", {}).get("raster", {})
	for key in ["ground", "height"]:
		if raster.has(key):
			sources.append(path.get_base_dir().path_join(raster[key]))
	for source in sources:
		if FileAccess.file_exists(source) and FileAccess.get_modified_time(source) > built:
			return true
	return false


func _poll_game() -> void:
	if _game.is_empty() or OS.is_process_running(int(_game["pid"])):
		return
	var was: DisplayServer.WindowMode = _game["mode"]
	_game = {}
	DisplayServer.window_set_mode(was if was != DisplayServer.WINDOW_MODE_MINIMIZED
			else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_move_to_foreground()
	_footer.text = "Back from %s." % _level_name()


# --- The interface -------------------------------------------------------------


func _build_ui() -> void:
	get_tree().auto_accept_quit = false
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	_box_rect = ColorRect.new()
	_box_rect.color = Color(0.55, 0.8, 1.0, 0.18)
	_box_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_rect.visible = false
	var edge := ReferenceRect.new()
	edge.border_color = Color(0.55, 0.8, 1.0, 0.9)
	edge.editor_only = false
	edge.set_anchors_preset(Control.PRESET_FULL_RECT)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box_rect.add_child(edge)
	_ui.add_child(_box_rect)
	_build_header()
	_build_sidebar()
	_build_footer()
	_build_dialogs()
	_set_tool(tool)
	_set_nav_type(nav_type)
	_set_mode(mode)


func _build_header() -> void:
	var panel := PanelContainer.new()
	panel.anchor_right = 1.0
	panel.offset_bottom = HEADER_HEIGHT
	_ui.add_child(panel)
	var bar := MenuBar.new()
	bar.flat = true
	bar.focus_mode = Control.FOCUS_NONE
	panel.add_child(bar)

	# A PopupMenu's node name is the title MenuBar shows for it.
	var file := PopupMenu.new()
	file.name = "File"
	file.add_item("New level...      Ctrl+N", 0)
	file.add_item("Open...           Ctrl+O", 1)
	file.add_separator()
	file.add_item("Save              Ctrl+S", 2)
	file.add_item("Save as...        Ctrl+Shift+S", 3)
	file.add_separator()
	file.add_item("Quit", 4)
	file.id_pressed.connect(_on_file_menu)
	bar.add_child(file)

	var edit := PopupMenu.new()
	edit.name = "Edit"
	edit.add_item("Undo              Ctrl+Z", 0)
	edit.add_item("Redo              Ctrl+Y", 1)
	edit.add_separator()
	edit.add_item("Delete picked     Del", 2)
	edit.id_pressed.connect(_on_edit_menu)
	bar.add_child(edit)

	var level := PopupMenu.new()
	level.name = "Level"
	level.add_item("Build in Blender  Ctrl+B", 0)
	level.add_item("Play              F5", 1)
	level.add_separator()
	level.add_item("Check", 2)
	level.add_item("Rebuild flow field (stage 1)", 3)
	level.set_item_tooltip(0, "Saves, then builds the level in Blender into build/level3d/, "
			+ "and imports it -- half a minute or so")
	level.set_item_tooltip(1, "Opens the preview on the level as it was last built")
	level.set_item_tooltip(2, "What Level3DIO.check finds: an enemy in a wall, a building off "
			+ "its group, an asset the catalogue does not know, no Chinook")
	level.id_pressed.connect(_on_level_menu)
	bar.add_child(level)
	_level_menu = level

	var view_menu := PopupMenu.new()
	view_menu.name = "View"
	view_menu.add_item("Top down / tilted   T", 0)
	view_menu.add_item("Whole level         F", 1)
	view_menu.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_pitch = 55.0 if _pitch > 80.0 else 90.0
			_place_camera()
		else:
			_frame_level())
	bar.add_child(view_menu)


func _on_edit_menu(id: int) -> void:
	match id:
		0:
			_undo_step(_undo, _redo)
		1:
			_redo_step()
		2:
			_delete_selected()


func _on_level_menu(id: int) -> void:
	match id:
		0:
			_build()
		1:
			_play()
		2:
			_check()
		3:
			_rebuild_flow_field()


func _on_file_menu(id: int) -> void:
	match id:
		0:
			_guard(func(): _new_dialog.popup_centered())
		1:
			_guard(func(): _open_dialog.popup_centered_ratio(0.6))
		2:
			_save()
		3:
			_save_dialog.popup_centered_ratio(0.6)
		4:
			_guard(func(): get_tree().quit())


func _build_sidebar() -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_top = HEADER_HEIGHT
	panel.offset_right = SIDEBAR_WIDTH
	panel.offset_bottom = -FOOTER_HEIGHT
	_ui.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	margin.add_child(outer)

	var modes := GridContainer.new()
	modes.columns = 2
	var group := ButtonGroup.new()
	for m in MODE_NAMES.size():
		var button := _toggle("F%d %s" % [m + 1, MODE_NAMES[m]], group)
		button.pressed.connect(_set_mode.bind(m))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		modes.add_child(button)
		_mode_buttons[m] = button
	outer.add_child(modes)
	outer.add_child(HSeparator.new())

	for m in MODE_NAMES.size():
		var page := VBoxContainer.new()
		page.add_theme_constant_override("separation", 4)
		page.size_flags_vertical = Control.SIZE_EXPAND_FILL
		outer.add_child(page)
		_pages[m] = page
	_build_ground_page(_pages[Mode.GROUND])
	_build_nav_page(_pages[Mode.NAV])
	_build_entity_page(_pages[Mode.ENTITIES])
	_build_object_page(_pages[Mode.OBJECTS])

	var help := Label.new()
	help.text = "Middle drag or WASD pans, right drag\nturns and tilts, wheel zooms."
	help.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	help.add_theme_font_size_override("font_size", 12)
	outer.add_child(help)


func _build_ground_page(box: VBoxContainer) -> void:
	var group := ButtonGroup.new()
	for n in TOOL_ORDER.size():
		var t: Level3DGround.Tool = TOOL_ORDER[n]
		if t == T.RAISE:
			box.add_child(_heading("Height"))
		var button := _toggle("%d  %s" % [n + 1, TOOL_NAMES[t]], group)
		button.tooltip_text = TOOL_TIPS[t]
		button.pressed.connect(_set_tool.bind(t))
		box.add_child(button)
		_tool_buttons[t] = button
	box.add_child(_heading("Brush"))
	_radius_slider = _slider(box, "Size (radius, m)  [ ]", 0.2, 12.0, 0.05, radius, true,
			func(v: float) -> void: radius = v)
	_strength_slider = _slider(box, "Strength (m a dab)", 0.01, 0.5, 0.01, strength, false,
			func(v: float) -> void: strength = v)
	_shore_slider = _slider(box, "Shore width (m)", 0.2, 3.0, 0.05, shore, false,
			func(v: float) -> void: shore = v)


func _build_nav_page(box: VBoxContainer) -> void:
	box.add_child(_heading("Paint the grid"))
	var group := ButtonGroup.new()
	_nav_auto = _toggle("Auto (the ground's)", group)
	_nav_auto.tooltip_text = "Takes a tile back to what the ground makes it: land empty, forest solid, water and slope water"
	_nav_auto.pressed.connect(_set_nav_type.bind(NAV_AUTO))
	box.add_child(_nav_auto)
	for t in MapIO.TYPE_NAME.size():
		var button := _toggle("%s  %s" % [MapIO.TYPE_CHAR[t], MapIO.TYPE_NAME[t]], group)
		button.add_theme_color_override("font_color", Color(LevelEditorItems.TYPE_COLORS[t], 1.0).lightened(0.35) \
				if t != MapIO.TYPE_EMPTY else Color.WHITE)
		button.pressed.connect(_set_nav_type.bind(t))
		box.add_child(button)
		_nav_buttons[t] = button
	box.add_child(_label("Brush, tiles  [ ]"))
	_nav_brush = SpinBox.new()
	_nav_brush.min_value = 1
	_nav_brush.max_value = 15
	_nav_brush.step = 2
	_nav_brush.value = nav_brush
	_nav_brush.focus_mode = Control.FOCUS_NONE
	_nav_brush.get_line_edit().focus_mode = Control.FOCUS_NONE
	_nav_brush.value_changed.connect(func(v: float) -> void: nav_brush = int(v))
	box.add_child(_nav_brush)


func _build_entity_page(box: VBoxContainer) -> void:
	var select := Button.new()
	select.text = "Select  (Esc)"
	select.focus_mode = Control.FOCUS_NONE
	select.tooltip_text = "Stop putting down: a click picks, a drag on nothing draws a box to pick with"
	select.pressed.connect(func() -> void: _entity_list.deselect_all())
	box.add_child(select)
	box.add_child(_heading("Put down"))
	box.add_child(_hint("Pick a type, then click the map. With none\npicked a click picks, a drag draws a box."))
	_entity_list = ItemList.new()
	_entity_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_entity_list.custom_minimum_size.y = 180
	_entity_list.focus_mode = Control.FOCUS_NONE
	var catalog := Level3DIO.read_catalog()
	var kinds: Array = catalog["entity_kinds"]
	var names: Array = MapIO.trigger_constants().keys()
	names.sort_custom(func(a, b):
		var ka := kinds.find(catalog["entities"].get(a, {}).get("kind", "enemy"))
		var kb := kinds.find(catalog["entities"].get(b, {}).get("kind", "enemy"))
		return ka < kb or (ka == kb and a < b))
	for name in names:
		var kind: String = catalog["entities"].get(name, {}).get("kind", "enemy")
		var index := _entity_list.add_item(name)
		_entity_list.set_item_custom_fg_color(index, LevelEditorItems.KIND_COLORS.get(kind, Color.WHITE).lightened(0.3))
		_entity_list.set_item_tooltip(index, kind)
		_entity_types.append(name)
	box.add_child(_entity_list)
	var on := HBoxContainer.new()
	_new_normal = _checkbox("normal", true)
	_new_hard = _checkbox("hard", true)
	on.add_child(_new_normal)
	on.add_child(_new_hard)
	box.add_child(on)

	_entity_multi = _label("")
	_entity_multi.visible = false
	box.add_child(_entity_multi)
	_entity_box = VBoxContainer.new()
	_entity_box.add_child(_heading("Picked"))
	_entity_info = _label("")
	_entity_box.add_child(_entity_info)
	var difficulty := HBoxContainer.new()
	_entity_normal = _checkbox("normal", true)
	_entity_hard = _checkbox("hard", true)
	_entity_normal.toggled.connect(func(v: bool) -> void: _edit_entity("normal", v))
	_entity_hard.toggled.connect(func(v: bool) -> void: _edit_entity("hard", v))
	difficulty.add_child(_entity_normal)
	difficulty.add_child(_entity_hard)
	_entity_box.add_child(difficulty)
	var group_row := HBoxContainer.new()
	group_row.add_child(_label("Group"))
	_entity_group = SpinBox.new()
	_entity_group.min_value = -1
	_entity_group.max_value = 99
	_entity_group.tooltip_text = "The destruction group a building sets off; found from its probe cell when it is put down or moved"
	_entity_group.value_changed.connect(func(v: float) -> void: _edit_entity("group", v))
	group_row.add_child(_entity_group)
	_entity_box.add_child(group_row)
	var remove := Button.new()
	remove.text = "Delete  (Del)"
	remove.focus_mode = Control.FOCUS_NONE
	remove.pressed.connect(_delete_selected)
	_entity_box.add_child(remove)
	box.add_child(_entity_box)


func _build_object_page(box: VBoxContainer) -> void:
	var tools := GridContainer.new()
	tools.columns = 2
	var group := ButtonGroup.new()
	for b in BUILD_NAMES.size():
		var button := _toggle(BUILD_NAMES[b], group)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void:
			if _path_drawing != "":
				_end_path()
			build = b as Build
			# Select lets go of the list; drawing does not use it.
			_asset_list.deselect_all()
			_asset_list.visible = build == Build.PLACE)
		tools.add_child(button)
		_build_buttons[b] = button
	(_build_buttons[Build.PLACE] as Button).button_pressed = true
	box.add_child(tools)
	box.add_child(_heading("Put down"))
	box.add_child(_hint("Pick an asset, then click the map. With\nnone picked a click picks, a drag draws a box."))
	_asset_list = ItemList.new()
	_asset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_list.custom_minimum_size.y = 180
	_asset_list.focus_mode = Control.FOCUS_NONE
	var catalog := Level3DIO.read_catalog()
	_assets = catalog["assets"].keys()
	_assets.sort()
	for name in _assets:
		var index := _asset_list.add_item(name)
		_asset_list.set_item_tooltip(index, "collision: %s" % catalog["assets"][name].get("collision", "none"))
	box.add_child(_asset_list)

	_object_multi = _label("")
	_object_multi.visible = false
	box.add_child(_object_multi)
	_object_box = VBoxContainer.new()
	_object_box.add_child(_heading("Picked"))
	_object_info = _label("")
	_object_box.add_child(_object_info)
	var yaw_row := HBoxContainer.new()
	yaw_row.add_child(_label("Turn (R)"))
	_object_yaw = SpinBox.new()
	_object_yaw.min_value = -180
	_object_yaw.max_value = 180
	_object_yaw.step = 0.5
	_object_yaw.value_changed.connect(func(v: float) -> void: _edit_object("yaw", v))
	yaw_row.add_child(_object_yaw)
	_object_box.add_child(yaw_row)
	var scale_row := HBoxContainer.new()
	scale_row.add_child(_label("Scale  [ ]"))
	_object_scale = SpinBox.new()
	_object_scale.min_value = 0.1
	_object_scale.max_value = 10
	_object_scale.step = 0.01
	_object_scale.value_changed.connect(func(v: float) -> void: _edit_object("scale", v))
	scale_row.add_child(_object_scale)
	_object_box.add_child(scale_row)
	var remove := Button.new()
	remove.text = "Delete  (Del)"
	remove.focus_mode = Control.FOCUS_NONE
	remove.pressed.connect(_delete_selected)
	_object_box.add_child(remove)
	box.add_child(_object_box)

	_structure_box = VBoxContainer.new()
	_structure_box.add_child(_heading("Picked"))
	_structure_info = _label("")
	_structure_box.add_child(_structure_info)
	var width_row := HBoxContainer.new()
	width_row.add_child(_label("Width"))
	_structure_width = SpinBox.new()
	_structure_width.min_value = 0.1
	_structure_width.max_value = 8.0
	_structure_width.step = 0.01
	_structure_width.value_changed.connect(func(v: float) -> void: _edit_structure("width", v))
	width_row.add_child(_structure_width)
	_structure_box.add_child(width_row)
	var height_row := HBoxContainer.new()
	height_row.add_child(_label("Height"))
	_structure_height = SpinBox.new()
	_structure_height.min_value = 0.0
	_structure_height.max_value = 6.0
	_structure_height.step = 0.01
	_structure_height.value_changed.connect(func(v: float) -> void: _edit_structure("height", v))
	height_row.add_child(_structure_height)
	_structure_box.add_child(height_row)
	var merlon_row := HBoxContainer.new()
	_structure_merlons = _checkbox("merlons", true)
	_structure_merlons.toggled.connect(func(v: bool) -> void: _edit_structure("merlons", v))
	merlon_row.add_child(_structure_merlons)
	var flip := Button.new()
	flip.text = "Other side"
	flip.focus_mode = Control.FOCUS_NONE
	flip.pressed.connect(func() -> void: _edit_structure("flip", true))
	merlon_row.add_child(flip)
	_structure_box.add_child(merlon_row)
	var shape_row := HBoxContainer.new()
	_structure_smooth = _checkbox("smooth", false)
	_structure_smooth.tooltip_text = "A curve through the points rather than straight from one to the next"
	_structure_smooth.toggled.connect(func(v: bool) -> void: _edit_structure("smooth", v))
	shape_row.add_child(_structure_smooth)
	_structure_closed = _checkbox("closed", false)
	_structure_closed.tooltip_text = "Round from the last point to the first again"
	_structure_closed.toggled.connect(func(v: bool) -> void: _edit_structure("closed", v))
	shape_row.add_child(_structure_closed)
	_structure_box.add_child(shape_row)
	_structure_box.add_child(_hint("Drag a point's handle; Ctrl+click on the\nwall puts one in, Del takes the last one\ntaken out. Drawing: Enter ends, a click on\nthe first point closes, on a gate goes\nthrough it, Backspace takes one back."))
	var remove_structure := Button.new()
	remove_structure.text = "Delete  (Del)"
	remove_structure.focus_mode = Control.FOCUS_NONE
	remove_structure.pressed.connect(_delete_selected)
	_structure_box.add_child(remove_structure)
	box.add_child(_structure_box)


func _toggle(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE
	return button


func _checkbox(text: String, on: bool) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = on
	box.focus_mode = Control.FOCUS_NONE
	return box


func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.65, 0.8, 1.0))
	return label


func _slider(box: VBoxContainer, title: String, lo: float, hi: float, step: float, value: float,
		exponential: bool, changed: Callable) -> HSlider:
	var label := Label.new()
	box.add_child(label)
	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.exp_edit = exponential
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE
	var show := func(v: float) -> void:
		label.text = "%s: %.2f" % [title, v]
		changed.call(v)
	slider.value_changed.connect(show)
	show.call(value)
	box.add_child(slider)
	return slider


func _build_footer() -> void:
	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -FOOTER_HEIGHT
	_ui.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	panel.add_child(margin)
	_footer = Label.new()
	_footer.clip_text = true
	_footer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	margin.add_child(_footer)


func _build_dialogs() -> void:
	for dialog_mode in [FileDialog.FILE_MODE_OPEN_FILE, FileDialog.FILE_MODE_SAVE_FILE]:
		var dialog := FileDialog.new()
		dialog.file_mode = dialog_mode
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.root_subfolder = LEVEL_DIR.trim_prefix("res://")
		dialog.filters = PackedStringArray(["*.json ; Level files"])
		_ui.add_child(dialog)
		if dialog_mode == FileDialog.FILE_MODE_OPEN_FILE:
			dialog.title = "Open a level"
			dialog.file_selected.connect(_open)
			_open_dialog = dialog
		else:
			dialog.title = "Save the level as"
			dialog.file_selected.connect(_save_to)
			_save_dialog = dialog

	_new_dialog = ConfirmationDialog.new()
	_new_dialog.title = "New level"
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	_new_dialog.add_child(grid)
	grid.add_child(_label("Name"))
	_new_name = LineEdit.new()
	_new_name.text = "new-level"
	_new_name.custom_minimum_size.x = 220
	grid.add_child(_new_name)
	grid.add_child(_label("Length (map rows)"))
	_new_rows = SpinBox.new()
	_new_rows.min_value = 40
	_new_rows.max_value = 2000
	_new_rows.value = 359
	_new_rows.tooltip_text = "Stage 1 is 359 rows, 168 m; the width is always the game's 64 tiles"
	grid.add_child(_new_rows)
	grid.add_child(_label("Start with"))
	_new_start = OptionButton.new()
	for text in ["Land", "Land, the sea to the west", "Water"]:
		_new_start.add_item(text)
	_new_start.select(1)
	grid.add_child(_new_start)
	_new_dialog.confirmed.connect(func() -> void:
		var name := _new_name.text.strip_edges().replace(" ", "-")
		if name == "" or not name.is_valid_filename():
			_tell("'%s' cannot be a file name." % name)
			return
		_new_level(name, int(_new_rows.value), _new_start.selected))
	_ui.add_child(_new_dialog)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Unsaved changes"
	_confirm.ok_button_text = "Discard"
	_confirm.confirmed.connect(func() -> void:
		dirty = false
		_after_confirm.call())
	_ui.add_child(_confirm)

	_message = AcceptDialog.new()
	_message.title = "Level editor"
	_ui.add_child(_message)


func _hint(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	label.add_theme_font_size_override("font_size", 12)
	return label


# Out of putting down, back to the pointer with nothing in the list, and
# whether there was anything to come out of.
func _disarm() -> bool:
	match mode:
		Mode.ENTITIES:
			if not _entity_list.get_selected_items().is_empty():
				_entity_list.deselect_all()
				return true
		Mode.OBJECTS:
			if build != Build.PLACE:
				build = Build.PLACE
				(_build_buttons[Build.PLACE] as Button).button_pressed = true
				_asset_list.visible = true
				return true
			if not _asset_list.get_selected_items().is_empty():
				_asset_list.deselect_all()
				return true
	return false


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _set_mode(m: int) -> void:
	if _path_drawing != "":
		_end_path()
	if _painting or _drag_id != "" or _nav_painting or _drawing != "" or _boxing:
		return
	var was := mode
	mode = m as Mode
	for k in _pages:
		(_pages[k] as Control).visible = k == mode
	if _mode_buttons.has(mode):
		(_mode_buttons[mode] as Button).button_pressed = true
	if doc.is_empty():
		return
	# Each page picks its own: an entity picked on the Objects page would be
	# deleted by a Del that nothing on the page shows.
	if mode != was or mode in [Mode.GROUND, Mode.NAV]:
		items.select("")
		_sync_selection()
	_show_nav()
	# Auto is a tile given back to the ground, which stage 1's grid is not.
	_nav_auto.disabled = not _derives_nav()
	if nav_type == NAV_AUTO and not _derives_nav():
		_set_nav_type(MapIO.TYPE_SOLID)


func _set_tool(t: Level3DGround.Tool) -> void:
	tool = t
	if _tool_buttons.has(t):
		(_tool_buttons[t] as Button).button_pressed = true
	var height := t in HEIGHT_TOOLS
	if _strength_slider:
		_strength_slider.get_parent().get_child(_strength_slider.get_index() - 1).modulate.a = 1.0 if height else 0.45
		_strength_slider.modulate.a = 1.0 if height else 0.45
		_shore_slider.get_parent().get_child(_shore_slider.get_index() - 1).modulate.a = 0.45 if height else 1.0
		_shore_slider.modulate.a = 0.45 if height else 1.0


func _set_nav_type(t: int) -> void:
	nav_type = t
	var button: Button = _nav_auto if t == NAV_AUTO else _nav_buttons.get(t)
	if button:
		button.button_pressed = true
