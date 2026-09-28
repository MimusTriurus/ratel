# The level editor: a program of its own for the 3D levels, not a plugin in
# Godot's editor (docs/level-editor-plan.md, part 2).
#
#     godot --path . src/tools/level_editor.tscn
#
# New makes a level of a given length, the game's 64 tiles across; Open
# reads any level file under assets/level3d/; Save writes it back with its
# two rasters beside it and the polygons traced off them, which is what the
# Blender builder builds from (tools/blender/build_level.py).
#
# The ground is painted. Land and sea and river are hard-edged brushes, each
# leaving a band of shore round itself that the slope is built on; forest
# grows on land; raise, lower, smooth and flatten work the rise of the ground
# for hills. All of it is Level3DGround's, and what is drawn is
# Level3DGroundView's picture of it. A stroke is one undo.
#
#   left drag         paint
#   middle drag, WASD pan          right drag   turn and tilt
#   wheel             zoom          [ ]          brush size
#   1-9               tools         T            top down / tilted
#   F                 the whole level
#   Ctrl+Z, Ctrl+Y    undo, redo    Ctrl+N/O/S   new, open, save
#   Ctrl+B            build         F5           play
#
# Level -> Build saves, then runs the Blender builder in the background on
# the level file, into build/level3d/<name>.glb, and imports what it made;
# Play opens the preview on the level and that glb (src/tools/level3d_preview
# .tscn, --file and --level). Blender is the Store build's launcher unless
# user://level_editor.cfg says otherwise ([editor] blender="...").
#
# Everything else in the file -- nav, entities, objects, groups -- comes
# through a save untouched; placing them is the next step of the plan.
extends Node3D

const LEVEL_DIR := "res://assets/level3d/"
const SETTINGS := "user://level_editor.cfg"
const SIDEBAR_WIDTH := 250.0
const HEADER_HEIGHT := 30.0
const FOOTER_HEIGHT := 26.0

const TOOL_NAMES := {
	Level3DGround.Tool.LAND: "Land", Level3DGround.Tool.SEA: "Sea", Level3DGround.Tool.RIVER: "River", Level3DGround.Tool.FOREST: "Forest",
	Level3DGround.Tool.CLEAR_FOREST: "Clear forest", Level3DGround.Tool.RAISE: "Raise", Level3DGround.Tool.LOWER: "Lower",
	Level3DGround.Tool.SMOOTH: "Smooth", Level3DGround.Tool.FLATTEN: "Flatten",
}
const TOOL_ORDER: Array = [Level3DGround.Tool.LAND, Level3DGround.Tool.SEA, Level3DGround.Tool.RIVER, Level3DGround.Tool.FOREST, Level3DGround.Tool.CLEAR_FOREST,
		Level3DGround.Tool.RAISE, Level3DGround.Tool.LOWER, Level3DGround.Tool.SMOOTH, Level3DGround.Tool.FLATTEN]
const TOOL_TIPS := {
	Level3DGround.Tool.LAND: "Land, flat at the sand's height; where it meets water it leaves a shore",
	Level3DGround.Tool.SEA: "Sea, with surf; where it meets land it cuts a shore",
	Level3DGround.Tool.RIVER: "River: water as the sea is, without the surf",
	Level3DGround.Tool.FOREST: "Forest on land: trees by the level's rule",
	Level3DGround.Tool.CLEAR_FOREST: "Takes the forest away",
	Level3DGround.Tool.RAISE: "Raises the ground, most at the middle of the brush",
	Level3DGround.Tool.LOWER: "Lowers what was raised, down to the land's own height",
	Level3DGround.Tool.SMOOTH: "Evens out the rise",
	Level3DGround.Tool.FLATTEN: "Brings the rise to what it was where the stroke began",
}
# How far apart the dabs of a stroke are, in brush radii.
const DAB_SPACING := 0.25
const REFRESH_EVERY := 0.06
const BASE_BLEND := "res://resources/3d/jackal_stage1_lowpoly.blend"
const BUILDER := "res://tools/blender/build_level.py"
const BUILD_DIR := "res://build/level3d/"
const PREVIEW := "res://src/tools/level3d_preview.tscn"

var doc := {}
var path := ""
var ground: Level3DGround
var view: Level3DGroundView
var dirty := false
var tool: Level3DGround.Tool = Level3DGround.Tool.LAND
var radius := 1.5
var strength := 0.1
var shore := Level3DGround.SHORE

var _undo: Array = []
var _redo: Array = []
var _painting := false
var _last_dab := Vector2.INF
var _flat_target := 0.0
var _pending := Rect2i()
var _since_refresh := 0.0

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
var _tool_buttons := {}
var _radius_slider: HSlider
var _strength_slider: HSlider
var _shore_slider: HSlider
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


# --- Painting ------------------------------------------------------------------


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
		_undo.append(tiles)
		_redo.clear()
	_flush()


func _flush() -> void:
	if _pending.has_area():
		view.refresh(_pending)
		_pending = Rect2i()
	_since_refresh = 0.0


func _undo_step(from: Array, to: Array) -> void:
	if from.is_empty() or _painting:
		return
	var swapped := ground.swap(from.pop_back())
	to.append(swapped[0])
	var r: Rect2i = swapped[1]
	_pending = r if not _pending.has_area() else _pending.merge(r)
	_flush()
	_set_dirty(true)


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
	_cursor.visible = hit != null and not _over_ui()
	if hit == null:
		_footer_text(null)
		return
	var p: Vector2 = hit
	_cursor.position = Vector3(p.x, view.height_at(p) + 0.02, p.y)
	_cursor.scale = Vector3(radius, 1.0, radius)
	_footer_text(p)


func _footer_text(p: Variant) -> void:
	var name := path.get_file() if path != "" else "(new level)"
	var text := "%s%s   %s  r %.1f m" % [name, " *" if dirty else "", TOOL_NAMES[tool], radius]
	if tool in [Level3DGround.Tool.RAISE, Level3DGround.Tool.LOWER, Level3DGround.Tool.SMOOTH, Level3DGround.Tool.FLATTEN]:
		text += "  strength %.2f" % strength
	if tool in [Level3DGround.Tool.LAND, Level3DGround.Tool.SEA, Level3DGround.Tool.RIVER]:
		text += "  shore %.1f m" % shore
	if p != null:
		var at: Vector2 = p
		var bits := ground.bits_at(at)
		var kind := "land" if bits & Level3DGround.LAND else \
				("river" if bits & Level3DGround.RIVER else "sea") if bits & Level3DGround.WATER else "slope"
		if bits & Level3DGround.FOREST:
			kind += ", forest"
		var tile := Level3DIO.to_map(doc["grid"], at) / float(doc["grid"]["tile_px"])
		text += "   |  %.2f, %.2f  row %d col %d  %s  height %.2f m" % [at.x, at.y,
				floori(tile.y), floori(tile.x), kind, view.height_at(at)]
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
						_begin_stroke(hit)
				elif _painting:
					_end_stroke()
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
		elif _painting:
			var hit: Variant = _hit(motion.position)
			if hit != null:
				_stroke_to(hit)
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		_key(key)


func _key(key: InputEventKey) -> void:
	var ctrl := key.ctrl_pressed or key.meta_pressed
	match key.keycode:
		KEY_Z when ctrl and key.shift_pressed:
			_undo_step(_redo, _undo)
		KEY_Z when ctrl:
			_undo_step(_undo, _redo)
		KEY_Y when ctrl:
			_undo_step(_redo, _undo)
		KEY_S when ctrl and key.shift_pressed:
			_save_dialog.popup_centered_ratio(0.6)
		KEY_S when ctrl:
			_save()
		KEY_O when ctrl:
			_guard(func(): _open_dialog.popup_centered_ratio(0.6))
		KEY_N when ctrl:
			_guard(func(): _new_dialog.popup_centered())
		KEY_BRACKETLEFT:
			_radius_slider.value = radius / 1.2
		KEY_BRACKETRIGHT:
			_radius_slider.value = radius * 1.2
		KEY_T:
			_pitch = 55.0 if _pitch > 80.0 else 90.0
			_place_camera()
		KEY_F:
			_frame_level()
		KEY_B when ctrl:
			_build()
		KEY_F5:
			_play()
		_:
			var n := key.keycode - KEY_1
			if n >= 0 and n < TOOL_ORDER.size() and not ctrl:
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
	view.setup(doc, ground)
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
		# Stage 1's grid is the game's, and stays; a level made here takes its
		# grid from its ground until the grid can be painted.
		if int(doc["stage"]) != Level3DMap.STAGE:
			doc["nav"] = ground.derive_nav(doc)
		error = Level3DIO.save_path(doc, file_path)
	if error != OK:
		_tell("Saving %s failed (error %d)." % [file_path, error])
		return
	path = file_path
	get_window().title = "Level editor -- %s" % path.get_file()
	_set_dirty(false)
	_remember(path)
	_footer.text = "Saved %s in %.1f s: %d land, %d water, %d forest polygons" % [path.get_file(),
			(Time.get_ticks_msec() - started) / 1000.0, doc["terrain"]["land"].size(),
			doc["water"].size(), doc["forest"].size()]


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


# --- Building and playing ------------------------------------------------------


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
	edit.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_undo_step(_undo, _redo)
		else:
			_redo_step())
	bar.add_child(edit)

	var level := PopupMenu.new()
	level.name = "Level"
	level.add_item("Build in Blender  Ctrl+B", 0)
	level.add_item("Play              F5", 1)
	level.set_item_tooltip(0, "Saves, then builds the level in Blender into build/level3d/, "
			+ "and imports it -- half a minute or so")
	level.set_item_tooltip(1, "Opens the preview on the level as it was last built")
	level.id_pressed.connect(func(id: int) -> void:
		if id == 0:
			_build()
		else:
			_play())
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


func _redo_step() -> void:
	_undo_step(_redo, _undo)


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
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	box.add_child(_heading("Ground"))
	var group := ButtonGroup.new()
	for n in TOOL_ORDER.size():
		var t: Level3DGround.Tool = TOOL_ORDER[n]
		if t == Level3DGround.Tool.RAISE:
			box.add_child(_heading("Height"))
		var button := Button.new()
		button.text = "%d  %s" % [n + 1, TOOL_NAMES[t]]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE
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

	var help := Label.new()
	help.text = ("\nLeft drag paints.\nMiddle drag or WASD pans,\nright drag turns and tilts,"
			+ "\nwheel zooms. T top/tilted,\nF the whole level.")
	help.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	box.add_child(help)


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
	for mode in [FileDialog.FILE_MODE_OPEN_FILE, FileDialog.FILE_MODE_SAVE_FILE]:
		var dialog := FileDialog.new()
		dialog.file_mode = mode
		dialog.access = FileDialog.ACCESS_RESOURCES
		dialog.root_subfolder = LEVEL_DIR.trim_prefix("res://")
		dialog.filters = PackedStringArray(["*.json ; Level files"])
		_ui.add_child(dialog)
		if mode == FileDialog.FILE_MODE_OPEN_FILE:
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


func _set_tool(t: Level3DGround.Tool) -> void:
	tool = t
	if _tool_buttons.has(t):
		(_tool_buttons[t] as Button).button_pressed = true
	var height := t in [Level3DGround.Tool.RAISE, Level3DGround.Tool.LOWER, Level3DGround.Tool.SMOOTH, Level3DGround.Tool.FLATTEN]
	if _strength_slider:
		_strength_slider.get_parent().get_child(_strength_slider.get_index() - 1).modulate.a = 1.0 if height else 0.45
		_strength_slider.modulate.a = 1.0 if height else 0.45
		_shore_slider.get_parent().get_child(_shore_slider.get_index() - 1).modulate.a = 0.45 if height else 1.0
		_shore_slider.modulate.a = 0.45 if height else 1.0
