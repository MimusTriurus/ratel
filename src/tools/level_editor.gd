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
#   Entities  the game's triggers, from the list: a click puts one down, on
#             the difficulties ticked, snapped to the tiles its footprint
#             covers; a click on one picks it, and dragging moves it. A
#             building finds the destruction group its probe cell is in. One
#             the catalogue gives an object -- a gun its bunker, the landing
#             port its pad -- comes with it, and goes where it goes. The
#             line across the map is the row the picked one fires on.
#   Objects   scenery from the catalogue, the same way; R and Shift+R turn
#             the picked one, [ and ] scale it. Wall, Side wall and Bridge
#             are drawn instead, a drag from one end to the other -- held to
#             a multiple of 45 degrees unless Shift is down -- and laid out
#             as stage 1's are (Level3DStructures); a picked one is dragged
#             whole, and its width, height and merlons are on the panel. A
#             GATE entity comes with its gate and the destruction group
#             that opens it, both moved with it.
#
# Delete removes what is picked, Esc lets go of it. Every stroke, placing,
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
# .tscn, --file and --level). Check lists what Level3DIO.check finds, and on
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
const BUILD_NAMES := ["Place", "Wall", "Side wall", "Bridge"]
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
var _drag_offset := Vector2.ZERO
var _drag_changed := false
var _nav_painting := false
var build: Build = Build.PLACE
# The wall or bridge being drawn, and where its drag began.
var _drawing := ""
var _draw_from := Vector2.ZERO

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
	for key in ([keys] if keys is String else keys):
		was[key] = (doc[key] as Array).duplicate(true)
	_undo.append({"doc": was})
	_redo.clear()
	_set_dirty(true)


func _undo_step(from: Array, to: Array) -> void:
	if from.is_empty() or _painting or _drag_id != "" or _nav_painting or _drawing != "":
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
			now[key] = (doc[key] as Array).duplicate(true)
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
		"walls", "bridges":
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
	for key in ["walls", "bridges"]:
		for st in doc.get(key, []):
			taken[st["id"]] = true
	var n := 0
	while taken.has("%s_%d" % [stem, n]):
		n += 1
	return "%s_%d" % [stem, n]


func _press_entity(p: Vector2) -> void:
	var id := items.entity_under(p)
	_record(["entities", "objects", "groups"])
	if id == "":
		if _entity_list.get_selected_items().is_empty():
			_undo.pop_back()
			return
		var type: String = _entity_types[_entity_list.get_selected_items()[0]]
		var difficulty: Array = []
		if _new_normal.button_pressed:
			difficulty.append("normal")
		if _new_hard.button_pressed:
			difficulty.append("hard")
		var at := items.snap_entity(type, p)
		var e := {"id": _unique_id(type.to_lower()), "type": type, "pos": [at.x, at.y],
				"difficulty": difficulty}
		(doc["entities"] as Array).append(e)
		_gate_group(e)
		_reprobe(e)
		items.update_entity(e)
		id = e["id"]
		var asset: String = items.catalog["entities"].get(type, {}).get("object", "")
		if asset != "":
			var o := {"id": _unique_id(asset.to_lower()), "asset": asset,
					"pos": _object_pos(at), "yaw": 0.0, "scale": 1.0, "entity": id}
			(doc["objects"] as Array).append(o)
			items.update_object(o)
		_drag_changed = true
	else:
		_drag_changed = false
	var e := items.find_entity(id)
	_drag_id = id
	_drag_offset = Vector2(float(e["pos"][0]), float(e["pos"][1])) - p
	items.select(id)
	_sync_selection()


func _press_object(p: Vector2) -> void:
	var picked := items.structure_under(p) if build == Build.PLACE else ""
	if build != Build.PLACE or picked != "":
		_press_structure(p, picked)
		return
	var id := items.object_under(p)
	_record("objects")
	if id == "":
		if _asset_list.get_selected_items().is_empty():
			_undo.pop_back()
			return
		var asset: String = _assets[_asset_list.get_selected_items()[0]]
		var o := {"id": _unique_id(asset.to_lower()), "asset": asset,
				"pos": _object_pos(p), "yaw": 0.0, "scale": 1.0}
		(doc["objects"] as Array).append(o)
		items.update_object(o)
		id = o["id"]
		_drag_changed = true
	else:
		_drag_changed = false
	var o := items.find_object(id)
	_drag_id = id
	_drag_offset = Vector2(float(o["pos"][0]), float(o["pos"][2])) - p
	items.select(id)
	_sync_selection()


# An object's place in the file: its height over the ground, which on the
# slope is the slope's and on a hill nothing -- the builder adds the rise.
func _object_pos(p: Vector2) -> Array:
	return [Level3DIO.round_mm(p.x), Level3DIO.round_mm(view.height_at(p) - ground.rise_at(p)),
			Level3DIO.round_mm(p.y)]


# Draws a new wall or bridge from `p`, or picks `picked` to drag it whole.
func _press_structure(p: Vector2, picked: String) -> void:
	for key in ["walls", "bridges"]:
		if not doc.has(key):
			doc[key] = []
	_record(["walls", "bridges"])
	if picked != "":
		var st := items.find_structure(picked)
		_drag_id = picked
		_drag_offset = Vector2(float(st["from"][0]), float(st["from"][1])) - p
		_drag_changed = false
		items.select(picked)
		_sync_selection()
		return
	var at := p.snapped(Vector2(SNAP, SNAP))
	var st: Dictionary
	if build == Build.BRIDGE:
		st = Level3DStructures.new_bridge(_unique_id("bridge"), at, at)
		(doc["bridges"] as Array).append(st)
	else:
		st = Level3DStructures.new_wall(_unique_id("wall"), "wall" if build == Build.WALL else "side", at, at)
		(doc["walls"] as Array).append(st)
	_drawing = st["id"]
	_draw_from = at
	items.select(_drawing)


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


func _drag_to(p: Vector2) -> void:
	var target := p + _drag_offset
	var st := items.find_structure(_drag_id)
	if not st.is_empty():
		var a := target.snapped(Vector2(SNAP, SNAP))
		var by := a - Vector2(float(st["from"][0]), float(st["from"][1]))
		if by != Vector2.ZERO:
			for end in ["from", "to"]:
				st[end] = [Level3DIO.round_mm(float(st[end][0]) + by.x), Level3DIO.round_mm(float(st[end][1]) + by.y)]
			if items.is_wall(st):
				items.update_wall(st)
			else:
				items.update_bridge(st)
			_drag_changed = true
			_derived = []
		return
	if mode == Mode.ENTITIES:
		var e := items.find_entity(_drag_id)
		var at := items.snap_entity(e["type"], target)
		if at.x != float(e["pos"][0]) or at.y != float(e["pos"][1]):
			var by := at - Vector2(float(e["pos"][0]), float(e["pos"][1]))
			e["pos"] = [at.x, at.y]
			_gate_group(e)
			_reprobe(e)
			items.update_entity(e)
			for o in _belonging_to(e["id"]):
				o["pos"] = _object_pos(Vector2(float(o["pos"][0]), float(o["pos"][2])) + by)
				items.update_object(o)
			_drag_changed = true
			_sync_selection()
	else:
		var o := items.find_object(_drag_id)
		var pos := _object_pos(target)
		if pos != o["pos"]:
			o["pos"] = pos
			items.update_object(o)
			_drag_changed = true


# The objects that belong to an entity: a gun's bunker, the landing port's pad.
func _belonging_to(id: String) -> Array:
	return (doc["objects"] as Array).filter(func(o): return o.get("entity", "") == id)


func _release_drag() -> void:
	if not _drag_changed:
		_undo.pop_back()
	_drag_id = ""


# A gate opens the middle of its footprint when it is blown: a destruction
# group of those cells, made for it the first time and moved with it. Stage
# 1's is group 6, which this rewrites to the same cells.
func _gate_group(e: Dictionary) -> void:
	if e["type"] != "GATE":
		return
	var cells := Level3DStructures.gate_cells(items.entity_tile(e))
	var groups: Array = doc["groups"]
	var index := int(e.get("group", -1))
	for g in groups:
		if int(g["index"]) == index:
			g["cells"] = cells
			_derived = []
			return
	index = 0
	for g in groups:
		index = maxi(index, int(g["index"]) + 1)
	groups.append({"index": index, "cells": cells})
	e["group"] = index
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


func _delete_selected() -> void:
	var id := items.selected()
	if id == "":
		return
	_record(["entities", "objects", "walls", "bridges"] if doc.has("walls") else ["entities", "objects"])
	var st := items.find_structure(id)
	if not st.is_empty():
		(doc["walls" if items.is_wall(st) else "bridges"] as Array).erase(st)
		items.remove_structure(id)
		_derived = []
		_sync_selection()
		return
	var e := items.find_entity(id)
	if not e.is_empty():
		# And what belongs to it.
		for o in _belonging_to(id):
			(doc["objects"] as Array).erase(o)
			items.remove_object(o["id"])
		(doc["entities"] as Array).erase(e)
		items.remove_entity(id)
	else:
		var o := items.find_object(id)
		if o.is_empty():
			_undo.pop_back()
			return
		(doc["objects"] as Array).erase(o)
		items.remove_object(id)
	_sync_selection()


func _turn_selected(degrees: float) -> void:
	var o := items.find_object(items.selected())
	if o.is_empty():
		return
	_record("objects")
	o["yaw"] = snappedf(wrapf(float(o["yaw"]) + degrees, -180.0, 180.0), 0.001)
	items.update_object(o)
	_sync_selection()


func _scale_selected(factor: float) -> void:
	var o := items.find_object(items.selected())
	if o.is_empty():
		return
	_record("objects")
	o["scale"] = snappedf(clampf(float(o["scale"]) * factor, 0.1, 10.0), 0.001)
	items.update_object(o)
	_sync_selection()


# The picked item's page of the sidebar, to what it is now.
func _sync_selection() -> void:
	_syncing = true
	var e := items.find_entity(items.selected())
	_entity_box.visible = not e.is_empty()
	if not e.is_empty():
		var tile := items.entity_tile(e)
		_entity_info.text = "%s\n%s, %s\nrow %d col %d" % [e["id"], e["type"], items.kind_of(e["type"]),
				tile.y, tile.x]
		_entity_normal.button_pressed = (e["difficulty"] as Array).has("normal")
		_entity_hard.button_pressed = (e["difficulty"] as Array).has("hard")
		_entity_group.value = int(e.get("group", -1))
		_entity_group.editable = MapIO.GROUP_PROBES.has(MapIO.trigger_constants().get(e["type"], -1))
	var st := items.find_structure(items.selected())
	_structure_box.visible = not st.is_empty()
	if not st.is_empty():
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
	var o := items.find_object(items.selected())
	_object_box.visible = not o.is_empty()
	if not o.is_empty():
		_object_info.text = "%s\n%s%s" % [o["id"], o["asset"],
				("\nbelongs to " + o["entity"]) if o.has("entity") else ""]
		_object_yaw.value = float(o["yaw"])
		_object_scale.value = float(o["scale"])
	_syncing = false


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
				if button.pressed:
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
	if _drawing != "":
		_end_draw()
	elif _painting:
		_end_stroke()
	elif _nav_painting:
		_nav_painting = false
	elif _drag_id != "":
		_release_drag()


func _key(key: InputEventKey) -> void:
	var ctrl := key.ctrl_pressed or key.meta_pressed
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
		KEY_ESCAPE:
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


func _play() -> void:
	if not ResourceLoader.exists(_built_glb()):
		_tell("%s has not been built yet: Level -> Build in Blender." % _level_name())
		return
	OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--path", ProjectSettings.globalize_path("res://"), PREVIEW, "--",
		"--file", path, "--level", _built_glb()]))


# --- The interface -------------------------------------------------------------


func _build_ui() -> void:
	get_tree().auto_accept_quit = false
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
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
	box.add_child(_heading("Put down"))
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
	_entity_list.select(maxi(_entity_types.find("SOLDIER_WALKER"), 0))
	box.add_child(_entity_list)
	var on := HBoxContainer.new()
	_new_normal = _checkbox("normal", true)
	_new_hard = _checkbox("hard", true)
	on.add_child(_new_normal)
	on.add_child(_new_hard)
	box.add_child(on)

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
			build = b as Build
			_asset_list.visible = build == Build.PLACE)
		tools.add_child(button)
		_build_buttons[b] = button
	(_build_buttons[Build.PLACE] as Button).button_pressed = true
	box.add_child(tools)
	box.add_child(_heading("Put down"))
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
	_asset_list.select(maxi(_assets.find("Palm_0"), 0))
	box.add_child(_asset_list)

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


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _set_mode(m: int) -> void:
	if _painting or _drag_id != "" or _nav_painting or _drawing != "":
		return
	mode = m as Mode
	for k in _pages:
		(_pages[k] as Control).visible = k == mode
	if _mode_buttons.has(mode):
		(_mode_buttons[mode] as Button).button_pressed = true
	if doc.is_empty():
		return
	if mode in [Mode.GROUND, Mode.NAV]:
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
