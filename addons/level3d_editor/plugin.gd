# The level editor's tools in the 3D viewport, for src/tools/level3d_editor.tscn
# (Level3DEditRoot). docs/level-editor-plan.md, stage 3.
#
# A bar in the viewport's menu while anything of the level is selected:
#
#   Select   the editor's own picking and gizmos; entities snap to tiles.
#   Nav      paints the grid with the chosen type, a square brush of 1-9
#            tiles; one stroke is one undo.
#   Entity   a click puts down an entity of the chosen type, on the chosen
#            difficulties. A building finds the group its probe cell is in.
#   Object   a click puts down a piece of scenery of the chosen asset.
#
# Check runs Level3DIO.check over the level as it stands and lists what it
# finds; Flow field rebuilds the level's own dirs-N.dat from the painted grid.
# Saving the scene writes the level file (Level3DEditRoot, pre-save).
#
# Clicks land on the ground plane, y = 0: the level's sand, which is where
# everything the game places stands.
@tool
extends EditorPlugin

enum Mode { SELECT, NAV, ENTITY, OBJECT }
const MODE_NAMES: Array[String] = ["Select", "Nav", "Entity", "Object"]
const DIALOG_LINES := 40

var _root: Level3DEditRoot
var _bar: HBoxContainer
var _mode: OptionButton
var _nav_type: OptionButton
var _brush: SpinBox
var _entity_type: OptionButton
var _normal: CheckBox
var _hard: CheckBox
var _asset: OptionButton
var _dialog: AcceptDialog
var _painting := false
var _stroke := {}           # Vector2i -> the type it had before the stroke


func _enter_tree() -> void:
	_bar = HBoxContainer.new()
	_bar.add_child(VSeparator.new())
	_mode = _options(MODE_NAMES)
	_mode.item_selected.connect(func(_i): _show_mode_options())
	_mode.tooltip_text = "What a click in the viewport does"
	_nav_type = _options(MapIO.TYPE_NAME)
	_nav_type.select(MapIO.TYPE_SOLID)
	_nav_type.tooltip_text = "The type the brush paints"
	_brush = SpinBox.new()
	_brush.min_value = 1
	_brush.max_value = 9
	_brush.step = 2
	_brush.value = 1
	_brush.tooltip_text = "Brush size in tiles"
	var types := MapIO.trigger_constants().keys()
	types.sort()
	_entity_type = _options(types)
	_entity_type.tooltip_text = "The trigger a click puts down"
	_normal = _check("normal")
	_hard = _check("hard")
	_asset = _options([])
	_asset.tooltip_text = "The asset a click puts down"
	for control in [_mode, _nav_type, _brush, _entity_type, _normal, _hard, _asset]:
		_bar.add_child(control)
	_bar.add_child(VSeparator.new())
	_bar.add_child(_button("Check", "Level3DIO.check over the level as it stands", _on_check))
	_bar.add_child(_button("Flow field", "Rebuild the level's dirs-N.dat from the grid", _on_flow_field))
	_bar.hide()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_dialog = AcceptDialog.new()
	_dialog.title = "Level3D"
	EditorInterface.get_base_control().add_child(_dialog)
	EditorInterface.get_selection().selection_changed.connect(_on_selection_changed)
	_show_mode_options()


func _exit_tree() -> void:
	EditorInterface.get_selection().selection_changed.disconnect(_on_selection_changed)
	remove_control_from_container(CONTAINER_SPATIAL_EDITOR_MENU, _bar)
	_bar.queue_free()
	_dialog.queue_free()


static func _options(items: Array) -> OptionButton:
	var button := OptionButton.new()
	for item in items:
		button.add_item(str(item))
	return button


static func _check(text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_pressed = true
	return box


static func _button(text: String, tip: String, pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.flat = true
	button.pressed.connect(pressed)
	return button


func _show_mode_options() -> void:
	var mode := _mode.selected
	_nav_type.visible = mode == Mode.NAV
	_brush.visible = mode == Mode.NAV
	_entity_type.visible = mode == Mode.ENTITY
	_normal.visible = mode == Mode.ENTITY
	_hard.visible = mode == Mode.ENTITY
	_asset.visible = mode == Mode.OBJECT


# --- What is being edited ---------------------------------------------------------


func _handles(object: Object) -> bool:
	return _root_of(object) != null


func _edit(object: Object) -> void:
	_root = _root_of(object)
	if _root and _asset.item_count == 0:
		var names: Array = _root.catalog.get("assets", {}).keys()
		names.sort()
		for name in names:
			_asset.add_item(name)


func _make_visible(visible: bool) -> void:
	_bar.visible = visible
	if not visible:
		_painting = false


static func _root_of(object: Object) -> Level3DEditRoot:
	var node := object as Node
	while node:
		if node is Level3DEditRoot:
			return node
		node = node.get_parent()
	return null


# The selected entities' firing lines are drawn bright.
func _on_selection_changed() -> void:
	var picked: Array = []
	var root: Level3DEditRoot = null
	for node in EditorInterface.get_selection().get_selected_nodes():
		root = root if root else _root_of(node)
		if node is Level3DEditEntity:
			picked.append(node)
	if root:
		root.select(picked)


# --- The viewport ---------------------------------------------------------------


func _forward_3d_gui_input(camera: Camera3D, event: InputEvent) -> int:
	if _root == null or _root.doc.is_empty() or _mode.selected == Mode.SELECT:
		return AFTER_GUI_INPUT_PASS
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			var hit: Variant = _ground(camera, button.position)
			if hit == null:
				return AFTER_GUI_INPUT_PASS
			match _mode.selected:
				Mode.NAV:
					_painting = true
					_stroke.clear()
					_paint(hit)
				Mode.ENTITY:
					_place_entity(hit)
				Mode.OBJECT:
					_place_object(hit)
			return AFTER_GUI_INPUT_STOP
		if _painting:
			_painting = false
			_commit_stroke()
			return AFTER_GUI_INPUT_STOP
	var motion := event as InputEventMouseMotion
	if motion and _painting:
		var hit: Variant = _ground(camera, motion.position)
		if hit != null:
			_paint(hit)
		return AFTER_GUI_INPUT_STOP
	return AFTER_GUI_INPUT_PASS


static func _ground(camera: Camera3D, at: Vector2) -> Variant:
	return Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(at),
			camera.project_ray_normal(at))


func _paint(hit: Vector3) -> void:
	var centre := _root.tile_at(hit.x, hit.z)
	if centre.x < 0:
		return
	var reach := int(_brush.value) / 2
	var type := _nav_type.selected
	var cells: Array = []
	var types: Array = []
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var cell := centre + Vector2i(dx, dy)
			if cell.y < 0 or cell.y >= _root.nav.size() \
					or cell.x < 0 or cell.x >= (_root.nav[0] as PackedByteArray).size():
				continue
			if not _stroke.has(cell):
				_stroke[cell] = _root.cell_type(cell)
			cells.append(cell)
			types.append(type)
	_root.set_cells(cells, types)


func _commit_stroke() -> void:
	var cells: Array = []
	var before: Array = []
	var after: Array = []
	for cell in _stroke:
		if _stroke[cell] == _root.cell_type(cell):
			continue
		cells.append(cell)
		before.append(_stroke[cell])
		after.append(_root.cell_type(cell))
	_stroke.clear()
	if cells.is_empty():
		return
	var undo := get_undo_redo()
	undo.create_action("Paint nav: %d cells %s" % [cells.size(), MapIO.TYPE_NAME[after[0]]])
	undo.add_do_method(_root, "set_cells", cells, after)
	undo.add_undo_method(_root, "set_cells", cells, before)
	undo.commit_action(false)


func _place_entity(hit: Vector3) -> void:
	var type := _entity_type.get_item_text(_entity_type.selected)
	var node := Level3DEditEntity.new()
	node.root = _root
	node.type = type
	node.normal = _normal.button_pressed
	node.hard = _hard.button_pressed
	node.name = type.to_lower()
	node.position = hit
	_add(node, _root.entities, "Add %s" % type)
	var index: int = MapIO.trigger_constants()[type]
	if MapIO.GROUP_PROBES.has(index):
		node.group = _root.group_at(node.tile() + MapIO.GROUP_PROBES[index])


func _place_object(hit: Vector3) -> void:
	if _asset.item_count == 0:
		return
	var asset := _asset.get_item_text(_asset.selected)
	var node := Level3DEditObject.new()
	node.root = _root
	node.asset = asset
	node.name = asset
	node.position = hit
	_add(node, _root.objects, "Add %s" % asset)


# Adds a node under an Entities or Objects container as one undoable step and
# selects it. Its id is settled when the level is saved.
func _add(node: Node3D, container: Node, action: String) -> void:
	var scene_root := EditorInterface.get_edited_scene_root()
	var undo := get_undo_redo()
	undo.create_action(action)
	undo.add_do_method(container, "add_child", node, true)
	undo.add_do_method(node, "set_owner", scene_root)
	undo.add_do_reference(node)
	undo.add_undo_method(container, "remove_child", node)
	undo.commit_action()
	var selection := EditorInterface.get_selection()
	selection.clear()
	selection.add_node(node)


# --- The buttons ----------------------------------------------------------------


func _on_check() -> void:
	if _root == null:
		return
	var problems := _root.check()
	for problem in problems:
		print("Level3D check: ", problem)
	var lines := Array(problems).slice(0, DIALOG_LINES)
	if problems.size() > DIALOG_LINES:
		lines.append("... and %d more, in the output" % (problems.size() - DIALOG_LINES))
	_say("No problems." if problems.is_empty() else "\n".join(lines))


func _on_flow_field() -> void:
	if _root == null:
		return
	var started := Time.get_ticks_msec()
	var error := _root.build_flow_field()
	_say("Wrote %s in %.1f s." % [Level3DIO.flow_field_path(_root.stage),
			(Time.get_ticks_msec() - started) / 1000.0]
			if error == OK else "Could not write the flow field (error %d)." % error)


func _say(text: String) -> void:
	_dialog.dialog_text = text
	_dialog.popup_centered()
