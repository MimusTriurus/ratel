# A read-only view of a stage: the tile grid as the game draws it, with the
# collision types, the destruction groups and the spawn triggers laid over it.
#
#     godot --path . src/tools/map_viewer.tscn
#
# Nothing here is part of the game. It loads the same data the game does --
# MapIO for assets/maps/stage-N.json, Main.load_tiles for the tile sheets -- so
# what it shows is what GameMode would draw, and it is the fastest way to answer
# "what is actually at row 260 of stage 4".
#
# The one thing worth looking at that the game never shows: a trigger does not
# fire on its own row. It fires when the bottom of its footprint is one tile
# above the top of the frame, so it is filed under tile_y + height - 1, and the
# whole row goes off at once. Hover a trigger to see that row drawn.
extends Control

const SIDEBAR_WIDTH := 320.0
const TILE := 32.0
const MIN_ZOOM := 0.2
const MAX_ZOOM := 4.0

# GameMode.TYPE_* , for the overlay.
const TYPE_NAMES: Array[String] = [
	"SOLID", "EMPTY", "SHIELD", "WATER", "SWAMP", "CONVEYOR",
]
const TYPE_COLORS: Array[Color] = [
	Color(0.90, 0.20, 0.20, 0.40),  # solid
	Color(0.30, 0.85, 0.35, 0.10),  # empty
	Color(0.95, 0.85, 0.20, 0.45),  # shield
	Color(0.20, 0.45, 0.95, 0.35),  # water
	Color(0.65, 0.30, 0.85, 0.40),  # swamp
	Color(0.95, 0.55, 0.15, 0.45),  # conveyor
]

const COLOR_TRIGGER := Color(0.20, 0.90, 0.90)
const COLOR_TRIGGER_BOSS := Color(1.00, 0.35, 0.85)
const COLOR_TRIGGER_PLAYER := Color(1.00, 1.00, 1.00)
const COLOR_GROUP := Color(1.00, 0.75, 0.20)
const COLOR_FIRE_ROW := Color(1.00, 0.95, 0.40, 0.85)
const COLOR_HOVER := Color(1.00, 1.00, 1.00, 0.85)

var stage: Stage
var stage_index := 0
var hard := false
var trigger_sizes: Array = []       # adjusted; boss entries are four rows short
var trigger_footprints: Array = []  # as authored, for drawing the box
var trigger_names: Array = []       # index -> Triggers constant name

var zoom := 1.0
var view_offset := Vector2.ZERO
var panning := false
var hover_tile := Vector2i(-1, -1)

var layers := {
	"tiles": true,
	"overlay": true,
	"types": false,
	"groups": true,
	"triggers": true,
	"grid": false,
	"cells": false,
}

var _inspector: Label
var _status: Label
var _stage_picker: OptionButton
var _layer_boxes := {}
var _font: Font
var _font_size := 14


func _ready() -> void:
	# A Control defaults to MOUSE_FILTER_STOP, which would swallow every mouse
	# event as GUI input before _unhandled_input ever saw it. The sidebar keeps
	# its own filter and still takes the clicks that land on it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_font = ThemeDB.fallback_font
	trigger_sizes = MapIO.load_trigger_sizes()
	_load_trigger_meta()
	_build_ui()
	_load_stage(0)
	_screenshot_mode()


# Renders one view to a PNG and quits, so a map can be looked at without a
# window to click in -- which is how this viewer was checked in the first place,
# and the closest thing to a visual regression test the project has:
#
#     godot --path . --windowed --resolution 1280x720 src/tools/map_viewer.tscn \
#         -- --shot out.png <stage 0-5> <zoom> <top row> <layer,layer,...>
#
# Everything after the PNG is optional. It needs a real window: --headless has
# no framebuffer to read back.
func _screenshot_mode() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args[0] != "--shot":
		return

	if args.size() >= 3:
		_load_stage(int(args[2]))
	if args.size() >= 4:
		zoom = float(args[3])
		view_offset.x = -SIDEBAR_WIDTH / zoom
	if args.size() >= 5:
		view_offset.y = float(args[4]) * TILE
	if args.size() >= 6:
		for key in layers:
			layers[key] = args[5].contains(key)
			# Keep the sidebar honest: the shot shows the boxes it was taken with.
			if _layer_boxes.has(key):
				_layer_boxes[key].set_pressed_no_signal(layers[key])
	hover_tile = Vector2i(-1, -1)
	queue_redraw()

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(args[1])
	if error != OK:
		push_error("Cannot write %s (error %d)" % [args[1], error])
	get_tree().quit()


# The footprint drawn is the authored one. MapIO shortens the six boss triggers
# by four rows so the camera pan can start early, which is right for the firing
# row and wrong for the box.
func _load_trigger_meta() -> void:
	var constants := MapIO.trigger_constants()
	trigger_names = []
	trigger_names.resize(constants.size())
	for name in constants:
		trigger_names[constants[name]] = name

	trigger_footprints = []
	trigger_footprints.resize(constants.size())
	var f := FileAccess.open(MapIO.MAPS + "trigger-sizes.json", FileAccess.READ)
	if f == null:
		push_error("Cannot open trigger-sizes.json")
		return
	var doc: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	for name in doc:
		if constants.has(name):
			var entry: Dictionary = doc[name]
			trigger_footprints[constants[name]] = Vector2i(
				int(entry["width"]), int(entry["height"]))


func _load_stage(index: int) -> void:
	stage_index = index
	stage = Stage.new()

	# Main owns the tile sheets, and load_tiles is the only thing needed off it.
	# It never touches _ready state, so an instance that is never added to the
	# tree is enough.
	var main := Main.new()
	main.load_tiles(index, stage)
	main.free()

	MapIO.load_stage(index, stage, trigger_sizes)
	if _stage_picker != null:
		# select() does not emit item_selected, so the number keys can drive this
		# without looping back into _load_stage.
		_stage_picker.select(index)
	_fit_width()
	_update_status()
	queue_redraw()


# size is not settled during _ready, so the viewport is the honest measure.
func _view_size() -> Vector2:
	return get_viewport_rect().size


func _fit_width() -> void:
	var view := _view_size()
	zoom = clampf((view.x - SIDEBAR_WIDTH) / (stage.map_width * TILE),
		MIN_ZOOM, MAX_ZOOM)
	view_offset.x = -SIDEBAR_WIDTH / zoom
	# Open at the bottom of the map, where the stage starts.
	view_offset.y = stage.map_height * TILE - view.y / zoom


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom_at(mb.position, 1.1)
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom_at(mb.position, 1.0 / 1.1)
			MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE:
				panning = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if panning:
			view_offset -= mm.relative / zoom
			queue_redraw()
		_update_hover(mm.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_ESCAPE:
				get_tree().quit()
			KEY_F:
				_fit_width()
				queue_redraw()
			KEY_H:
				hard = not hard
				_update_status()
				queue_redraw()
			KEY_UP:
				view_offset.y -= 256.0 / zoom
				queue_redraw()
			KEY_DOWN:
				view_offset.y += 256.0 / zoom
				queue_redraw()
			KEY_PAGEUP:
				view_offset.y -= size.y / zoom
				queue_redraw()
			KEY_PAGEDOWN:
				view_offset.y += size.y / zoom
				queue_redraw()
			_:
				if key >= KEY_1 and key <= KEY_6:
					_load_stage(key - KEY_1)


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var before := _to_map(screen_position)
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	view_offset += before - _to_map(screen_position)
	queue_redraw()


func _to_map(screen_position: Vector2) -> Vector2:
	return screen_position / zoom + view_offset


func _update_hover(screen_position: Vector2) -> void:
	var m := _to_map(screen_position)
	var t := Vector2i(int(floor(m.x / TILE)), int(floor(m.y / TILE)))
	if t.x < 0 or t.y < 0 or t.x >= stage.map_width or t.y >= stage.map_height:
		t = Vector2i(-1, -1)
	if t != hover_tile:
		hover_tile = t
		_update_inspector()
		queue_redraw()


# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	if stage == null:
		return

	var view := _view_size()
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.06, 0.07, 0.09), true)

	var first_x: int = maxi(0, int(view_offset.x / TILE))
	var first_y: int = maxi(0, int(view_offset.y / TILE))
	var last_x: int = mini(stage.map_width - 1,
		int((view_offset.x + view.x / zoom) / TILE))
	var last_y: int = mini(stage.map_height - 1,
		int((view_offset.y + view.y / zoom) / TILE))

	draw_set_transform(-view_offset * zoom, 0.0, Vector2(zoom, zoom))

	if layers["tiles"]:
		_draw_tiles(first_x, first_y, last_x, last_y, false)
	if layers["overlay"]:
		_draw_tiles(first_x, first_y, last_x, last_y, true)
	if layers["types"]:
		_draw_types(first_x, first_y, last_x, last_y)
	if layers["grid"] or layers["cells"]:
		_draw_grid(first_x, first_y, last_x, last_y)
	if layers["groups"]:
		_draw_groups()
	if layers["triggers"]:
		_draw_triggers()
	if hover_tile.x >= 0:
		draw_rect(Rect2(hover_tile.x * TILE, hover_tile.y * TILE, TILE, TILE),
			COLOR_HOVER, false, 2.0 / zoom)

	draw_set_transform_matrix(Transform2D.IDENTITY)
	_draw_labels()


# The tile grid, in the game's two passes: everything below 225 first, then the
# tiles from the shared tiles-6 sheet, which sit on top of the background.
func _draw_tiles(first_x: int, first_y: int, last_x: int, last_y: int,
		overlay: bool) -> void:
	var tiles := stage.tiles
	for y in range(first_y, last_y + 1):
		if y >= stage.map_height - 1:
			# The sentinel row past the bottom of the map has no tiles, only a
			# type: water, so that anything driving off the end drowns. Painted
			# flat so it does not read as a hole.
			if not overlay:
				draw_rect(Rect2(first_x * TILE, y * TILE,
					(last_x - first_x + 1) * TILE, TILE),
					Color(0.10, 0.16, 0.45), true)
			continue
		var row: PackedInt32Array = stage.tile_map[y]
		var Y := y * TILE
		for x in range(first_x, last_x + 1):
			var index := row[x]
			if (index >= 225) != overlay:
				continue
			var X := x * TILE

			# Stage 2 floats its terrain over two water sets in a checkerboard.
			# The game cross-fades them; a still shows both.
			if not overlay and stage_index == 2 and index < 32:
				var water := ((y & 1) << 1) + (x & 1)
				_blit(tiles[water + 4], X, Y, 1.0)
				_blit(tiles[water], X, Y, 0.5)

			if index < tiles.size():
				_blit(tiles[index], X, Y, 1.0)


func _blit(spr: Spr, x: float, y: float, alpha: float) -> void:
	if spr == null:
		return
	draw_texture_rect_region(spr.tex, Rect2(x, y, spr.w, spr.h), spr.region,
		Color(1, 1, 1, alpha))


func _draw_types(first_x: int, first_y: int, last_x: int, last_y: int) -> void:
	for y in range(first_y, last_y + 1):
		var row: PackedInt32Array = stage.types_map[y]
		for x in range(first_x, last_x + 1):
			var t := row[x]
			if t >= 0 and t < TYPE_COLORS.size():
				draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), TYPE_COLORS[t], true)


# The 32 px tile grid, and the 128 px cells the flow field in dirs-N.dat is
# indexed by -- four tiles to a side, which is why a wall a tile thick can still
# leave a cell passable.
func _draw_grid(first_x: int, first_y: int, last_x: int, last_y: int) -> void:
	var top := first_y * TILE
	var bottom := (last_y + 1) * TILE
	var left := first_x * TILE
	var right := (last_x + 1) * TILE

	if layers["grid"] and zoom >= 0.5:
		var thin := Color(1, 1, 1, 0.08)
		for x in range(first_x, last_x + 2):
			draw_line(Vector2(x * TILE, top), Vector2(x * TILE, bottom), thin, 1.0 / zoom)
		for y in range(first_y, last_y + 2):
			draw_line(Vector2(left, y * TILE), Vector2(right, y * TILE), thin, 1.0 / zoom)

	if layers["cells"]:
		var thick := Color(0.4, 0.9, 1.0, 0.25)
		var cx := first_x - (first_x % 4)
		while cx <= last_x + 4:
			draw_line(Vector2(cx * TILE, top), Vector2(cx * TILE, bottom), thick, 1.5 / zoom)
			cx += 4
		var cy := first_y - (first_y % 4)
		while cy <= last_y + 4:
			draw_line(Vector2(left, cy * TILE), Vector2(right, cy * TILE), thick, 1.5 / zoom)
			cy += 4


# A group is the set of cells rewritten when the thing on them is destroyed.
func _draw_groups() -> void:
	for i in stage.groups.size():
		for cell in stage.groups[i]:
			draw_rect(Rect2(cell[0] * TILE, cell[1] * TILE, TILE, TILE),
				COLOR_GROUP, false, 1.5 / zoom)


func _draw_triggers() -> void:
	var rows: Array = stage.trigger_map[1 if hard else 0]
	for row in rows.size():
		for t in rows[row]:
			var index: int = t[0]
			var x: float = t[1]
			var y: float = t[2]
			var footprint := _footprint(index)
			var rect := Rect2(x, y, footprint.x * TILE, footprint.y * TILE)
			draw_rect(rect, _trigger_color(index), false, 1.5 / zoom)

			# The row this trigger actually fires on, drawn only for the one
			# under the cursor so the map stays readable.
			if hover_tile.x >= 0 and rect.has_point(
					Vector2(hover_tile.x * TILE + 1, hover_tile.y * TILE + 1)):
				var fire_y := (row + 1) * TILE
				draw_line(Vector2(0, fire_y), Vector2(stage.map_width * TILE, fire_y),
					COLOR_FIRE_ROW, 2.0 / zoom)


func _footprint(index: int) -> Vector2i:
	var value: Variant = trigger_footprints[index]
	return value if value != null else Vector2i.ONE


func _trigger_color(index: int) -> Color:
	if index == Triggers.PLAYER or index == Triggers.CHINOOK:
		return COLOR_TRIGGER_PLAYER
	if MapIO.EARLY_BOSS_TRIGGERS.has(index):
		return COLOR_TRIGGER_BOSS
	return COLOR_TRIGGER


# Names go on last, in screen space, so they stay legible at any zoom.
func _draw_labels() -> void:
	if not layers["triggers"] or zoom < 0.45:
		return
	var rows: Array = stage.trigger_map[1 if hard else 0]
	var top := view_offset.y
	var bottom := view_offset.y + size.y / zoom
	for row in rows.size():
		for t in rows[row]:
			var y: float = t[2]
			if y < top - TILE * 8 or y > bottom:
				continue
			var at := (Vector2(t[1], y) - view_offset) * zoom + Vector2(3, -4)
			if at.x < SIDEBAR_WIDTH:
				continue
			draw_string(_font, at, trigger_names[t[0]], HORIZONTAL_ALIGNMENT_LEFT,
				-1, _font_size, _trigger_color(t[0]))


# --- Sidebar -----------------------------------------------------------------

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.anchor_bottom = 1.0
	panel.offset_right = SIDEBAR_WIDTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	# Nothing in the sidebar takes focus: the number and arrow keys belong to the
	# map, and a focused button would eat them.
	_stage_picker = OptionButton.new()
	for i in 6:
		_stage_picker.add_item("Stage %d" % (i + 1), i)
	_stage_picker.focus_mode = Control.FOCUS_NONE
	_stage_picker.item_selected.connect(func(i: int) -> void: _load_stage(i))
	box.add_child(_stage_picker)

	var hard_box := CheckBox.new()
	hard_box.text = "Hard triggers"
	hard_box.focus_mode = Control.FOCUS_NONE
	hard_box.toggled.connect(func(pressed: bool) -> void:
		hard = pressed
		_update_status()
		queue_redraw())
	box.add_child(hard_box)

	box.add_child(HSeparator.new())

	for entry in [
		["tiles", "Tiles"],
		["overlay", "Top tiles (>= 225)"],
		["types", "Collision types"],
		["groups", "Destruction groups"],
		["triggers", "Triggers"],
		["grid", "Tile grid"],
		["cells", "Path cells (128 px)"],
	]:
		var key: String = entry[0]
		var check := CheckBox.new()
		check.text = entry[1]
		check.focus_mode = Control.FOCUS_NONE
		check.button_pressed = layers[key]
		check.toggled.connect(func(pressed: bool) -> void:
			layers[key] = pressed
			queue_redraw())
		_layer_boxes[key] = check
		box.add_child(check)

	box.add_child(HSeparator.new())

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_status)

	box.add_child(HSeparator.new())

	_inspector = Label.new()
	_inspector.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_inspector.custom_minimum_size.y = 260
	_inspector.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	box.add_child(_inspector)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.modulate = Color(1, 1, 1, 0.6)
	help.text = ("drag: pan    wheel: zoom    F: fit width\n"
		+ "1-6: stage    H: hard    Esc: quit")
	box.add_child(help)


func _update_status() -> void:
	if _status == null or stage == null:
		return
	var count := 0
	for row in stage.trigger_map[1 if hard else 0]:
		count += row.size()
	_status.text = ("Stage %d\n%d x %d tiles (%d px tall)\n%d groups, %d %s triggers"
		% [stage_index + 1, stage.map_width, stage.map_height,
			int(stage.map_height * TILE), stage.groups.size(), count,
			"hard" if hard else "normal"])


func _update_inspector() -> void:
	if _inspector == null:
		return
	if hover_tile.x < 0:
		_inspector.text = ""
		return

	var x := hover_tile.x
	var y := hover_tile.y
	var lines: Array[String] = []
	lines.append("tile (%d, %d)   px (%d, %d)" % [x, y, x * 32, y * 32])

	if y < stage.map_height - 1:
		lines.append("tile index: %d" % stage.tile_map[y][x])
	else:
		lines.append("tile index: -- (water row)")

	var t: int = stage.types_map[y][x]
	lines.append("type: %s" % (TYPE_NAMES[t] if t < TYPE_NAMES.size() else str(t)))
	lines.append("path cell: (%d, %d)" % [x >> 2, y >> 2])

	# groups_map is a byte array, so "no group" and "group 0" read the same.
	# Only a cell that really is in the group is reported.
	var group_index: int = stage.groups_map[y][x]
	var in_group := false
	if group_index < stage.groups.size():
		for cell in stage.groups[group_index]:
			if cell[0] == x and cell[1] == y:
				in_group = true
				lines.append("group %d -> tile %d, %s"
					% [group_index, cell[2], TYPE_NAMES[cell[3]]])
				break
	if not in_group:
		lines.append("group: --")

	var rows: Array = stage.trigger_map[1 if hard else 0]
	var here: Array[String] = []
	for row in rows.size():
		for trigger in rows[row]:
			var footprint := _footprint(trigger[0])
			var tx: int = trigger[1] >> 5
			var ty: int = trigger[2] >> 5
			if x >= tx and x < tx + footprint.x and y >= ty and y < ty + footprint.y:
				here.append("  %s  %dx%d  fires on row %d"
					% [trigger_names[trigger[0]], footprint.x, footprint.y, row])
	if not here.is_empty():
		lines.append("")
		lines.append("triggers here:")
		lines.append_array(here)

	var fires: Array[String] = []
	for trigger in rows[y]:
		fires.append("  %s at (%d, %d)"
			% [trigger_names[trigger[0]], trigger[1] >> 5, trigger[2] >> 5])
	if not fires.is_empty():
		lines.append("")
		lines.append("row %d fires:" % y)
		lines.append_array(fires)

	_inspector.text = "\n".join(lines)
