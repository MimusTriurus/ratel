# The 3D preview's Escape menu: continue, settings, the main menu, quit, over
# the stage frozen by pausing the tree. The settings are seven tabs: six of
# Level3DSettings -- game (8-bit or modern, a preset of the others: the sound,
# the font, the look, the driving and firing), graphics (the camera and the
# look), interface (what the
# HUD shows, where and how big), sound (original, classic or modern, the volumes, the
# enemies' fire), controls (the keys, the gamepad, how the BTR drives and fires) and
# cheats -- and the mixer, the game's own gain for every sound and every part
# of the music in each mode, which is Level3DAudio's mix and is saved into the
# project rather than the player's settings. Every settings change is handed
# back through `changed` at once, the menu staying open, so a switch shows
# what it does behind it.
#
# The game's own in-game menu (GameMode._open_menu) is drawn with the game's
# font through Main; this one is Godot's controls, as the preview's HUD is a
# Label: the preview has no Main to draw through. Its font follows the HUD's
# (Level3DSettings.font, _apply_font), from the .ttf files the HUD's sheets
# were baked from: Press Start 2P sharp or smoothed, or Black Ops One.
#
# Escape goes back a step: out of a key prompt, out of the settings, and from
# the first page back to the stage. A pad (Level3DPad) goes about it as the
# keys do: the d-pad or the left stick move the focus, A picks, B and Start
# are Escape, L1 and R1 turn the settings' tabs, and the right stick scrolls
# the tab (SCROLL_SPEED). The left stick is a move a tip, not Godot's every
# motion past its dead zone; the d-pad or the stick held moves again and
# again (Level3DPad.Repeat), as a held key does.
#
# The control the keys and the pads have is marked by its own frame, in
# ACCENT, as console menus mark it (_frame_styles) -- there is no pointer. No
# mouse: the preview is played without it, and the menu lets none of its
# events through to the controls (_input).
#
# It clicks as the title does (Level3DAudio's menu_move, menu_pick): a move
# as the focus goes to another control, a pick as a button is pressed, a box ticked, a list's entry picked or
# a tab changed (_hook). The sliders are left quiet -- the Sound and Mixer
# tabs' play what they set -- and so is the focus a page takes as it opens
# or a pick hands on (_hushed).
class_name Level3DMenu
extends CanvasLayer

# The type scale's SMALL (Level3DFont), the title BODY.
const FONT_SIZE := int(Level3DFont.SMALL)
const TITLE_SIZE := int(Level3DFont.BODY)
# Press Start 2P at FONT_SIZE is a letter as wide as it is tall, half as wide
# again as Godot's font: its sizes are scaled by this, so the panels hold it,
# and then to a whole number of its 8 px grid (PIXEL_GRID), since at 12 px the
# notes' letters came out a pixel wide and two by turns.
const PIXEL_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const PIXEL_FONT_SCALE := 2.0 / 3.0
const PIXEL_GRID := 8
const MODERN_FONT := "res://assets/fonts/BlackOpsOne-Regular.ttf"
# The notes were FONT_SIZE - 6: in Black Ops One, a stencil face, its cuts
# came out a pixel or two and read as letters cut off, so it had a floor of
# 22; and in Press Start 2P they came out FONT_SIZE's own 16 all the same.
# They are the words' size now, set apart by their grey.# The headings' colour, and a ticked box's.
const ACCENT := Color(1.0, 0.8, 0.3)
# The boxes' size in pixels of the 2048x1152 layout; drawn at ICON_OVERSAMPLE
# times that, so that they stay sharp scaled up to a bigger screen.
const ICON_SIZE := 26
const ICON_OVERSAMPLE := 2
# The right stick's scroll of a settings tab at full tilt, pixels a second.
const SCROLL_SPEED := 1400.0
# The Sound tab's sliders, one for each of the modern mode's sounds
# (Level3DAudio.SOUNDS), under a heading for each kind. enemy_hit is left out:
# it is only the original's layer under explode, which the modern mode's
# "blast" replaces. tools/verify_level3d_audio.gd checks that nothing else is.
const SOUND_GROUPS := [
	["BTR weapons", [["gun", "Machine gun"], ["grenade_launch", "Grenade launch"], ["rocket_launch", "Rocket launch"], ["rocket_flight", "Rocket flight"]]],
	["Hits", [["hit_ground", "On the ground"], ["hit_water", "On water"], ["hit_hard", "On concrete and walls"],
			["hit_dull", "On huts and gates"],
			["hit_armor", "On armour: machine gun"], ["hit_armor_blast", "On armour: rocket or mine"]]],
	["Enemy fire", [["enemy_mg", "Soldiers' machine guns"], ["enemy_cannon", "Cannons: bunkers, boats"],
			["tank_cannon", "Tank guns"]]],
	["Explosions", [["blast_small", "Grenade"], ["blast_missile", "Rocket"], ["blast_water", "In water"],
			["blast", "Enemy destroyed"], ["building", "Building destroyed"], ["breach_gun", "Boss tank breached: machine gun"],
			["breach_blast", "Boss tank breached: rocket or mine"],
			["player_explodes", "BTR destroyed"], ["soldier_death_gun", "Soldier killed: machine gun"],
			["soldier_death_blast", "Soldier killed: rocket or mine"],
			["soldier_death_run_over", "Soldier run over"]]],
	["Engines", [["btr_idle", "BTR engine"], ["btr_drive", "BTR driving"], ["tank_engine", "Tanks"],
			["boat_engine", "Boats"], ["chinook", "Chinook"], ["rescue_rotor", "Rescue helicopter"]]],
	["Title", [["jeep_start", "Jeeps: engine start"], ["jeep_idle", "Jeeps: engine running"]]],
	["Interface", [["pickup", "Prisoner picked up"], ["rescue_pickup", "Prisoner aboard the helicopter"],
			["upgrade", "Weapon upgrade"], ["extra_life", "Extra life"], ["warning", "Boss warning"], ["pause", "Pause"],
			["menu_move", "Menu: onto an entry"], ["menu_pick", "Menu: entry picked"]]],
	["Ambience", [["ambient_sea", "Sea"], ["ambient_jungle", "Jungle"], ["ambient_rain", "Rain"]]],
]
# The Mixer tab: the game's own gains (Level3DAudio's mix), in dB, for the
# mode picked on it. SOUND_GROUPS' sounds, with enemy_hit after the blast it
# is played under in classic, and the music's parts.
const MIX_EXTRA := {"blast": ["enemy_hit", "Hit under the blast (enemy_hit)"]}
const MUSIC_NAMES := {
	"start.ogg": "Before the landing", "stage0_intro.ogg": "Stage: intro",
	"stage0_repeat.ogg": "Stage: loop", "boss_intro.ogg": "Boss: intro",
	"boss_repeat.ogg": "Boss: loop",
	"boss_lead.ogg": "Boss: lead", "boss_tank_1.ogg": "Boss: tank 1 (guitars)",
	"boss_tank_2.ogg": "Boss: tank 2 (double kick)", "boss_tank_3.ogg": "Boss: tank 3 (strings)",
	"boss_tank_4.ogg": "Boss: tank 4 (arpeggiator)", "boss_full.ogg": "Boss: whole loop (linear)",
	"boss_victory.ogg": "Boss: victory", "boss_breach.ogg": "Boss: breach accent",
	"title.ogg": "Title screen",
}
const MIX_MIN_DB := -40.0
const MIX_MAX_DB := 12.0
const MIX_STEP_DB := 0.5
# Level3DSettings.Reach as the menu lists it, shortest first.
const REACH_ORDER := [Level3DSettings.Reach.CLASSIC, Level3DSettings.Reach.LONG, Level3DSettings.Reach.UNLIMITED]
const ACTION_NAMES := {
	"up": "Forward / up", "down": "Back / down", "left": "Left", "right": "Right",
	"gun": "Machine gun", "rocket": "Rocket", "nitro": "Nitro", "mines": "Mines", "airstrike": "Airstrike",
}
const PAD_NAME_CHOICES := ["Auto", "PlayStation", "Xbox"]
const PAD_ASSIST_CHOICES := ["Off", "Light", "Normal", "Strong"]

var settings: Level3DSettings
var changed: Callable        # after every change, with the menu still open
var resumed: Callable        # once the menu has closed
# Started by the level editor's Play (--editor): leaving is going back to it,
# which is waiting for this process to end.
var from_editor := false
# `main_menu.call()`: the title screen (Level3DTitle), the run given up. None
# from the level editor, which has no title.
var main_menu: Callable
var _paused_before := false   # the tree's pause when open() was called
# Where the settings' Back goes when they were opened over the title
# (open_settings) rather than from the first page.
var _back: Callable

var _main_page: Control
var _settings_page: Control
var _tabs: TabContainer
var _theme: Theme
# What has a font size of its own: [control, FONT_SIZE + this], scaled with
# the font's (_apply_font).
var _font_sizes: Array = []
var _font_style := -1        # the Level3DFont.Style the menu is drawn in
var _game_mode: OptionButton
var _difficulty: OptionButton
var _camera: OptionButton
var _camera_window: CheckBox
var _look: OptionButton
var _light: OptionButton
var _crt: CheckBox
var _crt_curve: OptionButton
var _outline_stage: OptionButton
var _outline_vehicles: OptionButton
var _outline_people: OptionButton
var _resolution: OptionButton
var _antialias: OptionButton
var _driving: OptionButton
var _firing: OptionButton
var _reach: OptionButton
var _infinite_lives: CheckBox
var _smooth_turns: CheckBox
var _smooth_reverse: CheckBox
var _wall_hack: CheckBox
var _bullet_hack: CheckBox
var _gun_rate: OptionButton
var _launcher_rate: OptionButton
var _hud: CheckBox
var _hud_score: CheckBox
var _hud_lives: CheckBox
var _hud_pows: CheckBox
var _hud_modes: CheckBox
var _hud_pad_arrow: CheckBox
var _hud_help: CheckBox
var _hud_hints: CheckBox
var _hud_cheats: CheckBox
var _hud_crosshair: CheckBox
var _banner_stage: CheckBox
var _banner_warning: CheckBox
var _banner_mission: CheckBox
var _hud_corner: OptionButton
var _hud_rows: OptionButton
var _font: OptionButton
var _hud_scale: OptionButton
var _sound_mode: OptionButton
# The Sound tab's and the Mixer tab's choice of mode, in the order they list
# it, and what each is called.
const SOUND_MODES := [Level3DSettings.SoundMode.ORIGINAL, Level3DSettings.SoundMode.CLASSIC,
		Level3DSettings.SoundMode.MODERN]
const SOUND_MODE_NAMES := ["Original", "Classic (8-bit)", "Modern"]
var _boss_music: OptionButton
var _master_volume: HSlider
var _music_volume: HSlider
var _effects_volume: HSlider
var _enemy_fire: CheckBox
var _enemy_fire_volume: HSlider
var _gain_sliders := {}      # sound -> HSlider
var _gains_reset: Button
var _mixer_mode: OptionButton
var _mix_sliders := {}       # sound -> HSlider
var _music_sliders := {}     # music file -> HSlider
var _mix_status: Label
var _mix_save: Button
var _key_buttons := {}       # action -> Button
var _waiting := ""           # the action a key prompt is open for
var _pad: CheckBox
var _pad_single: OptionButton
var _pad_names: OptionButton
var _pad_assist: OptionButton
var _pad_vibration: CheckBox
var _pad_status: Label
var _pad_buttons := {}       # Level3DSettings.PAD_ACTIONS' action -> Button
var _waiting_pad := ""       # the action a pad prompt is open for
var _continue: Button
var _hushed := -1            # the frame a pick or a page took the focus in
var _scroll_rest := 0.0      # the right stick's scroll short of a whole pixel
var _repeat := Level3DPad.Repeat.new()


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var theme := Theme.new()
	_theme = theme
	theme.default_font_size = FONT_SIZE
	for state in ["unchecked", "unchecked_disabled"]:
		theme.set_icon(state, "CheckBox", _box_icon(false))
	for state in ["checked", "checked_disabled"]:
		theme.set_icon(state, "CheckBox", _box_icon(true))
	theme.set_constant("h_separation", "CheckBox", 10)
	_frame_styles(theme)
	var root := Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	_main_page = _make_main_page()
	centre.add_child(_main_page)
	_settings_page = _make_settings_page()
	centre.add_child(_settings_page)
	get_viewport().gui_focus_changed.connect(_focus_changed)
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool):
		if visible:
			refresh())
	for node in find_children("*", "Control", true, false):
		_hook(node)
	# And whatever a tab builds later.
	get_tree().node_added.connect(func(node: Node):
		if is_ancestor_of(node):
			_hook(node))


# A control's pick, clicked (menu_pick).
func _hook(node: Node) -> void:
	if node.has_meta("clicks"):
		return
	node.set_meta("clicks", true)
	if node is BaseButton:
		(node as BaseButton).pressed.connect(_click)
	if node is OptionButton:
		(node as OptionButton).item_selected.connect(func(_index: int): _click())
	elif node is TabContainer:
		(node as TabContainer).tab_changed.connect(func(_tab: int): _click())


# Not asked whether the menu is up: a button's own handler, connected before
# this, may have closed it (Back, Resume).
func _click() -> void:
	Level3DAudio.play("menu_pick")
	_hush()


# The focus taken from now to the end of the frame is no move.
func _hush() -> void:
	_hushed = Engine.get_process_frames()


func is_open() -> bool:
	return visible


# The list dropped from the menu, or null.
func _open_list() -> PopupMenu:
	for window in get_viewport().get_embedded_subwindows():
		if window is PopupMenu and window.visible:
			return window
	return null


func _process(delta: float) -> void:
	if not visible:
		return
	_scroll_by_stick(delta)
	var again := _repeat.tick(Level3DPad.held_dir(Level3DPad.connected()), delta)
	if again != Vector2i.ZERO and _waiting_pad == "" and _open_list() == null:
		_move(again)
	if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


# A move of the focus, as the arrows make it: the ui action, pressed and let
# go, which the controls take as they take the keys.
func _move(dir: Vector2i) -> void:
	var action := "ui_up" if dir.y < 0 else "ui_down" if dir.y > 0 \
			else "ui_left" if dir.x < 0 else "ui_right"
	for down in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = down
		Input.parse_input_event(event)


# The settings' tab scrolled by any pad's right stick, the focus left where
# it is; not over a dropped list, which has the pad.
func _scroll_by_stick(delta: float) -> void:
	var scroll := _tabs.get_current_tab_control() as ScrollContainer
	if not _settings_page.visible or scroll == null or _open_list() != null:
		_scroll_rest = 0.0
		return
	var tilt := Level3DPad.right(Level3DPad.connected()).y
	if tilt == 0.0:
		_scroll_rest = 0.0
		return
	_scroll_rest += signf(tilt) * pow(absf(tilt), 1.5) * SCROLL_SPEED * delta
	var whole := int(_scroll_rest)
	_scroll_rest -= whole
	scroll.scroll_vertical += whole


# The focus moved: a move's click.
func _focus_changed(control: Control) -> void:
	if visible and is_ancestor_of(control):
		if Engine.get_process_frames() != _hushed:
			Level3DAudio.play("menu_move")


# With GameMode's pause sound, which its pause key plays both ways. Over the
# shop the tree is paused already, and close() leaves it so (_paused_before).
func open() -> void:
	visible = true
	_paused_before = get_tree().paused
	get_tree().paused = true
	Level3DAudio.play("pause")
	_show_main()


# The settings page alone, over the title screen, whose tree is already
# paused: Back and Escape hide it and call `back`.
func open_settings(back: Callable) -> void:
	_back = back
	visible = true
	_show_settings()


# Out of sight with the tree left paused, for the title screen.
func leave() -> void:
	_waiting = ""
	_waiting_pad = ""
	visible = false
	Level3DAudio.end_music_audition()


func close() -> void:
	_waiting = ""
	_waiting_pad = ""
	visible = false
	# The stage's song again, if the Mixer tab put a part of another on.
	Level3DAudio.end_music_audition()
	get_tree().paused = _paused_before
	_paused_before = false
	Level3DAudio.play("pause")
	if resumed.is_valid():
		resumed.call()


func _show_main() -> void:
	_waiting = ""
	_waiting_pad = ""
	_hush()
	_apply_font()
	if _back.is_valid():
		var back := _back
		_back = Callable()
		leave()
		back.call()
		return
	_settings_page.visible = false
	_main_page.visible = true
	_continue.grab_focus()


func _show_settings() -> void:
	_hush()
	refresh()
	_main_page.visible = false
	_settings_page.visible = true
	_tabs.get_tab_bar().grab_focus()


# The widgets from `settings`, which the preview's own keys (Tab, V, M) change
# behind the menu's back.
func refresh() -> void:
	_apply_font()
	_game_mode.select(int(settings.preset()))
	_difficulty.select(1 if settings.hard else 0)
	_camera.select(settings.camera)
	_camera_window.set_pressed_no_signal(settings.camera_window)
	_look.select(settings.look)
	_light.select(settings.light)
	_crt.set_pressed_no_signal(settings.crt)
	_crt_curve.select(Level3DSettings.CRT_CURVES.find(settings.crt_curve))
	_crt_curve.disabled = not settings.crt   # greyed out, as the HUD's are
	_outline_stage.select(Level3DSettings.OUTLINES.find(settings.outline_stage))
	_outline_vehicles.select(Level3DSettings.OUTLINES.find(settings.outline_vehicles))
	_outline_people.select(Level3DSettings.OUTLINES.find(settings.outline_people))
	_resolution.select(settings.resolution)
	_antialias.select(settings.antialias)
	_driving.select(settings.driving)
	_firing.select(settings.firing)
	_reach.select(REACH_ORDER.find(settings.reach))
	_smooth_turns.set_pressed_no_signal(settings.smooth_turns)
	_smooth_reverse.set_pressed_no_signal(settings.smooth_reverse)
	_smooth_reverse.disabled = not settings.smooth_turns   # greyed out, as the CRT's curve is
	_infinite_lives.set_pressed_no_signal(settings.infinite_lives)
	_wall_hack.set_pressed_no_signal(settings.wall_hack)
	_bullet_hack.set_pressed_no_signal(settings.bullet_hack)
	_gun_rate.select(Level3DSettings.RATES.find(settings.gun_rate))
	_launcher_rate.select(Level3DSettings.RATES.find(settings.launcher_rate))
	_hud.set_pressed_no_signal(settings.hud)
	_hud_score.set_pressed_no_signal(settings.hud_score)
	_hud_lives.set_pressed_no_signal(settings.hud_lives)
	_hud_pows.set_pressed_no_signal(settings.hud_pows)
	_hud_modes.set_pressed_no_signal(settings.hud_modes)
	_hud_pad_arrow.set_pressed_no_signal(settings.hud_pad_arrow)
	_hud_help.set_pressed_no_signal(settings.hud_help)
	_hud_hints.set_pressed_no_signal(settings.hud_hints)
	_hud_cheats.set_pressed_no_signal(settings.hud_cheats)
	_hud_crosshair.set_pressed_no_signal(settings.hud_crosshair)
	_banner_stage.set_pressed_no_signal(settings.banner_stage)
	_banner_warning.set_pressed_no_signal(settings.banner_warning)
	_banner_mission.set_pressed_no_signal(settings.banner_mission)
	_hud_corner.select(settings.hud_corner)
	_hud_rows.select(1 if settings.hud_two_rows else 0)
	_font.select(settings.font)
	_hud_scale.select(Level3DSettings.HUD_SCALES.find(settings.hud_scale))
	_sound_mode.select(SOUND_MODES.find(settings.sound_mode))
	_master_volume.set_value_no_signal(settings.master_volume * 100.0)
	_music_volume.set_value_no_signal(settings.music_volume * 100.0)
	_effects_volume.set_value_no_signal(settings.effects_volume * 100.0)
	_enemy_fire.set_pressed_no_signal(settings.enemy_fire)
	_enemy_fire_volume.set_value_no_signal(settings.enemy_fire_volume * 100.0)
	# The original has no enemies' fire to switch, and no gains but the game's;
	# classic is played as modern is. The boss's music follows the fight in
	# modern alone: classic's is linear.
	var own := settings.sound_mode != Level3DSettings.SoundMode.ORIGINAL
	_boss_music.select(settings.boss_music)
	_boss_music.disabled = settings.sound_mode != Level3DSettings.SoundMode.MODERN
	_enemy_fire.disabled = not own
	_enemy_fire_volume.editable = own and settings.enemy_fire
	for sound in _gain_sliders:
		var slider: HSlider = _gain_sliders[sound]
		slider.set_value_no_signal(float(settings.sound_gains.get(sound, 1.0)) * 100.0)
		slider.editable = own
		_show_percent(slider)
	_gains_reset.disabled = not own
	for slider in [_master_volume, _music_volume, _effects_volume, _enemy_fire_volume]:
		_show_percent(slider)
	_mixer_mode.select(SOUND_MODES.find(settings.sound_mode))
	_refresh_mixer()
	# Greyed out, not hidden, with the HUD off: what it would show stays set.
	for widget in [_hud_score, _hud_lives, _hud_pows, _hud_modes, _hud_cheats, _hud_pad_arrow,
			_hud_help, _hud_hints, _banner_stage, _banner_warning, _banner_mission, _hud_corner, _hud_rows, _hud_scale]:
		widget.disabled = not settings.hud
	for action in _key_buttons:
		var button: Button = _key_buttons[action]
		button.text = "..." if action == _waiting else _key_text(settings.key(action))
	_pad.set_pressed_no_signal(settings.pad)
	_pad_single.select(settings.pad_single)
	_pad_names.select(settings.pad_names)
	_pad_assist.select(settings.pad_assist)
	_pad_vibration.set_pressed_no_signal(settings.pad_vibration)
	for widget in [_pad_single, _pad_names, _pad_assist, _pad_vibration]:
		widget.disabled = not settings.pad
	for action in _pad_buttons:
		var button: Button = _pad_buttons[action]
		var binding := settings.pad_button(action)
		button.text = "..." if action == _waiting_pad \
				else "—" if binding < 0 else Level3DPad.name_of(binding)
		button.disabled = not settings.pad
	var pads := Level3DPad.connected()
	_pad_status.text = "No gamepad connected." if pads.is_empty() else "Connected: " \
			+ ", ".join(pads.map(func(d: int): return Input.get_joy_name(d))) + "."


func _changed() -> void:
	refresh()
	if changed.is_valid():
		changed.call()


# ----------------------------------------------------------------------------
# Pages

func _make_main_page() -> Control:
	var panel := PanelContainer.new()
	var box := _padded_box(panel, 16)
	box.custom_minimum_size = Vector2(360, 0)
	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_font_size(title, TITLE_SIZE - FONT_SIZE)
	box.add_child(title)
	_continue = _button(box, "Continue", close)
	_button(box, "Settings", _show_settings)
	if not from_editor:
		_button(box, "Main menu", func(): main_menu.call())
	_button(box, "Back to the editor" if from_editor else "Quit", func(): get_tree().quit())
	return panel


func _make_settings_page() -> Control:
	var panel := PanelContainer.new()
	var box := _padded_box(panel, 12)
	box.custom_minimum_size = Vector2(760, 820)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Every tab's name in view, in either font, rather than a narrow tab's page
	# hiding some behind arrows.
	_tabs.clip_tabs = false
	box.add_child(_tabs)
	_tabs.add_child(_make_game_tab())
	_tabs.add_child(_make_graphics_tab())
	_tabs.add_child(_make_interface_tab())
	_tabs.add_child(_make_sound_tab())
	_tabs.add_child(_make_mixer_tab())
	_tabs.add_child(_make_controls_tab())
	_tabs.add_child(_make_cheats_tab())
	_button(box, "Back", _show_main)
	return panel


# The mode: a preset of the settings on the other tabs (Level3DSettings.PRESETS),
# and "own settings" once one of them has been changed from it, which cannot be
# picked. And the difficulty, which is no part of a preset. Both were on the
# title's menu as well (Level3DTitle), and are only here now.
func _make_game_tab() -> Control:
	var tab := _tab("Game")
	var grid := _grid(tab)
	_game_mode = _choice(grid, "Style", ["8-bit", "Modern", "Custom"],
			func(i: int): settings.apply_preset(i as Level3DSettings.Preset))
	_game_mode.set_item_disabled(Level3DSettings.Preset.CUSTOM, true)
	_difficulty = _choice(grid, "Difficulty", ["Normal", "Hard"], func(i: int): settings.hard = i == 1)
	_note(tab, "8-bit: the sounds and music as an NES plays them (classic sound), classic driving, "
			+ "firing and reach, the Press Start 2P pixel font, the pixel look and the CRT monitor.")
	_note(tab, "Modern: the new positional sound and its own music, modern driving (throttle and steering), "
			+ "firing at the cursor with the long reach, the Black Ops One font, the modern look without the CRT.")
	_note(tab, "A style is a set of the settings on the other tabs. Change one of them there and the style is "
			+ "custom; the camera, resolution, interface, volumes, keys and cheats do not depend on it. "
			+ "Launched with --style 8bit or --style modern, the game starts in that style.")
	_note(tab, "Hard: the stage's harder enemies from the first round, as the game has them from the second "
			+ "round on either way. Changed during a game, it counts from the next round.")
	return tab.get_parent().get_parent()


func _make_graphics_tab() -> Control:
	var tab := _tab("Graphics")
	var grid := _grid(tab)
	_camera = _choice(grid, "Camera", ["Top down", "Top down, tilted"],
			func(i: int): settings.camera = i)
	_look = _choice(grid, "Look", ["Modern", "Pixels"],
			func(i: int): settings.look = i)
	_light = _choice(grid, "Light", Level3DLighting.LABELS,
			func(i: int): settings.light = i)
	_resolution = _choice(grid, "3D resolution", ["Native", "2048×1152 (as the game)", "1920×1080", "1280×720"],
			func(i: int): settings.resolution = i)
	_antialias = _choice(grid, "Anti-aliasing", ["Off", "MSAA 2x", "MSAA 4x", "MSAA 8x"],
			func(i: int): settings.antialias = i)
	var widths := Level3DSettings.OUTLINES.map(func(px: float): return "%s px" % str(px).trim_suffix(".0"))
	_outline_stage = _choice(grid, "Outline: stage, enemies", widths,
			func(i: int): settings.outline_stage = Level3DSettings.OUTLINES[i])
	_outline_vehicles = _choice(grid, "Outline: your vehicles", widths,
			func(i: int): settings.outline_vehicles = Level3DSettings.OUTLINES[i])
	_outline_people = _choice(grid, "Outline: people", widths,
			func(i: int): settings.outline_people = Level3DSettings.OUTLINES[i])
	_camera_window = _check(tab, "Camera window", func(on: bool): settings.camera_window = on)
	_note(tab, "As in the game: the camera stays still while the jeep drives about in the frame, "
			+ "and moves when it nears an edge. Off: the jeep is always in the middle.")
	_crt = _check(tab, "CRT monitor", func(on: bool): settings.crt = on)
	_crt_curve = _choice(_grid(tab), "Screen curvature", ["Flat", "Slight", "Normal", "Strong", "Very strong"],
			func(i: int): settings.crt_curve = Level3DSettings.CRT_CURVES[i])
	_note(tab, "Outlines are in pixels of a 1080-line screen. People: soldiers, prisoners and the helicopter's crewman.")
	return tab.get_parent().get_parent()


func _make_interface_tab() -> Control:
	var tab := _tab("Interface")
	_hud = _check(tab, "Show the HUD", func(on: bool): settings.hud = on)
	tab.add_child(HSeparator.new())
	_heading(tab, "What to show")
	_hud_score = _check(tab, "Money", func(on: bool): settings.hud_score = on)
	_hud_lives = _check(tab, "Lives", func(on: bool): settings.hud_lives = on)
	_hud_pows = _check(tab, "Prisoners aboard", func(on: bool): settings.hud_pows = on)
	_hud_modes = _check(tab, "Driving and firing modes", func(on: bool): settings.hud_modes = on)
	_note(tab, "Off: a mode is shown for a couple of seconds when V or M changes it.")
	# Classic is all there is while the modern ones are hidden.
	if not Level3DSettings.MODERN_CONTROLS:
		_hud_modes.visible = false
		tab.get_child(tab.get_child_count() - 1).visible = false
	_hud_cheats = _check(tab, "Active cheats", func(on: bool): settings.hud_cheats = on)
	_hud_pad_arrow = _check(tab, "Arrow to the helicopter", func(on: bool): settings.hud_pad_arrow = on)
	_note(tab, "While prisoners are aboard and the helicopter that will take them is off the screen.")
	_hud_help = _check(tab, "HELP and HERE calls", func(on: bool): settings.hud_help = on)
	_note(tab, "HELP over the first building with prisoners and over prisoners left waiting too long; "
			+ "HERE over the helicopter's crewman while there is anyone to drop off.")
	_hud_hints = _check(tab, "Control hints", func(on: bool): settings.hud_hints = on)
	_note(tab, "The keys over the jeep when they are first needed: drive, fire, a rocket at a hut.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Banners")
	_banner_stage = _check(tab, "Stage number at the landing", func(on: bool): settings.banner_stage = on)
	_banner_warning = _check(tab, "Boss warning", func(on: bool): settings.banner_warning = on)
	_banner_mission = _check(tab, "Mission complete and prisoners rescued",
			func(on: bool): settings.banner_mission = on)
	tab.add_child(HSeparator.new())
	_hud_crosshair = _check(tab, "Crosshair in place of the cursor", func(on: bool): settings.hud_crosshair = on)
	_note(tab, "In the modern and combined firing modes, which aim with the mouse. Works without the HUD too.")
	tab.add_child(HSeparator.new())
	# The modern firing's, hidden with it (Level3DSettings.MODERN_CONTROLS).
	if not Level3DSettings.MODERN_CONTROLS:
		var count := tab.get_child_count()
		for i in range(count - 3, count):
			(tab.get_child(i) as Control).visible = false
	var layout := _grid(tab)
	_hud_corner = _choice(layout, "Position", ["Top", "Bottom"],
			func(i: int): settings.hud_corner = i)
	_hud_rows = _choice(layout, "Rows", ["One", "Two: money on its own"],
			func(i: int): settings.hud_two_rows = i == 1)
	_font = _choice(layout, "Font", ["Classic: Press Start 2P", "Classic smoothed", "Modern: Black Ops One"],
			func(i: int): settings.font = i)
	_hud_scale = _choice(layout, "Size",
			Level3DSettings.HUD_SCALES.map(func(s: float): return "%d%%" % roundi(s * 100.0)),
			func(i: int): settings.hud_scale = Level3DSettings.HUD_SCALES[i])
	return tab.get_parent().get_parent()


func _make_sound_tab() -> Control:
	var tab := _tab("Sound")
	var modes := _grid(tab)
	_sound_mode = _choice(modes, "Sound", SOUND_MODE_NAMES,
			func(i: int):
				settings.sound_mode = SOUND_MODES[i]
				_preview("pickup"))
	_note(tab, "Original: the original game's sounds, played as it plays them. "
			+ "Classic: the modern mode's sounds and music as an NES with the VRC6 chip plays them, by the same rules. "
			+ "Modern: positional sound, engines, ambience, enemy fire and music of its own.")
	var boss := _grid(tab)
	_boss_music = _choice(boss, "Boss music", ["Adaptive", "Linear"],
			func(i: int): settings.boss_music = i)
	_note(tab, "Adaptive: every tank on the field adds its part to the music, and takes it away when hit. "
			+ "Linear: the same parts as one track. Either way, a fanfare after the victory. Modern mode only.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Volume")
	var volumes := _grid(tab)
	_master_volume = _slider(volumes, "Master", func(v: float): settings.master_volume = v)
	_music_volume = _slider(volumes, "Music", func(v: float): settings.music_volume = v)
	_effects_volume = _slider(volumes, "Effects",
			func(v: float):
				settings.effects_volume = v
				_preview("pickup"))
	tab.add_child(HSeparator.new())
	_heading(tab, "Enemy fire")
	_enemy_fire = _check(tab, "Enemy fire is heard",
			func(on: bool):
				settings.enemy_fire = on
				_preview("enemy_mg"))
	var enemy := _grid(tab)
	_enemy_fire_volume = _slider(enemy, "Volume",
			func(v: float):
				settings.enemy_fire_volume = v
				_preview("enemy_mg"))
	_note(tab, "In the original the enemies fired in silence. Not in the original mode.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Each sound of the modern mode")
	_note(tab, "100% is the level the sound was mixed at; up to 200% is louder. "
			+ "A sound with no file of its own plays the original's, and the slider acts on that too.")
	for group in SOUND_GROUPS:
		var title := Label.new()
		title.text = group[0]
		tab.add_child(title)
		var grid := _grid(tab)
		for pair in group[1]:
			var sound: String = pair[0]
			_gain_sliders[sound] = _slider(grid, "    " + pair[1], _gain_moved(sound),
					Level3DAudio.MAX_GAIN * 100.0)
	_gains_reset = Button.new()
	_gains_reset.text = "All to 100%"
	_gains_reset.size_flags_horizontal = Control.SIZE_SHRINK_END
	_gains_reset.pressed.connect(func():
		settings.sound_gains = {}
		_changed())
	tab.add_child(_gains_reset)
	return tab.get_parent().get_parent()


# A sound's slider: its gain into the settings, and the sound itself to hear
# it by -- not a loop, which is heard as it is, where it plays.
func _gain_moved(sound: String) -> Callable:
	return func(v: float):
		settings.sound_gains[sound] = v
		if not Level3DAudio.SOUNDS[sound].get("loop", false):
			_preview(sound)


# The game's mix, not the player's: every sound's and every music part's gain
# in dB, for the mode picked here (the same setting as the Sound tab's), heard
# as it is moved and written to Level3DAudio.MIX_PATH by Save. The player's
# own sliders on the Sound tab still act over it.
func _make_mixer_tab() -> Control:
	var tab := _tab("Mixer")
	var modes := _grid(tab)
	_mixer_mode = _choice(modes, "Mode", SOUND_MODE_NAMES,
			func(i: int): settings.sound_mode = SOUND_MODES[i])
	_note(tab, "The game's level of every sound and of the music, in dB, for each mode separately. "
			+ "▶ plays it; a sound plays again when its slider is let go. "
			+ "Music loops until ■ or \"Stage music\" is pressed. "
			+ "\"Save\" writes it all to assets/sfx3d/mix.json. "
			+ "The Sound tab's sliders, the player's own settings, act on top of it.")
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	tab.add_child(actions)
	_mix_save = _button(actions, "Save", func():
		var err := Level3DAudio.save_mix()
		_refresh_mixer()
		if err != OK:
			_mix_status.text = "Not saved (%s): an exported build's project files are read-only." % error_string(err)
		else:
			_mix_status.text = "Saved to %s" % Level3DAudio.MIX_PATH)
	_button(actions, "Revert to saved", func():
		Level3DAudio.reload_mix()
		_refresh_mixer())
	_button(actions, "Stage music", func():
		Level3DAudio.end_music_audition()
		_refresh_music_buttons())
	_mix_status = Label.new()
	_mix_status.add_theme_color_override("font_color", ACCENT)
	tab.add_child(_mix_status)
	tab.add_child(HSeparator.new())
	_heading(tab, "Music")
	var music := _mix_grid(tab)
	music.set_meta("music", true)
	for file in Level3DAudio.music_files():
		_music_sliders[file] = _mix_row(music, "    " + MUSIC_NAMES.get(file, file),
				func(): _toggle_music(file),
				func(db: float): Level3DAudio.set_music_db(file, db, _mixer_audio_mode()))
		# Let go of the slider, the part is heard again rather than stopped.
		var slider: HSlider = _music_sliders[file]
		slider.drag_ended.connect(func(value_changed: bool):
			if value_changed and Level3DAudio.auditioned_music() != file:
				Level3DAudio.audition_music(file)
				_refresh_music_buttons())
	for group in SOUND_GROUPS:
		tab.add_child(HSeparator.new())
		_heading(tab, group[0])
		var grid := _mix_grid(tab)
		var rows: Array = []
		for pair in group[1]:
			rows.append(pair)
			if MIX_EXTRA.has(pair[0]):
				rows.append(MIX_EXTRA[pair[0]])
		for pair in rows:
			var sound: String = pair[0]
			_mix_sliders[sound] = _mix_row(grid, "    " + pair[1],
					func(): Level3DAudio.audition(sound),
					func(db: float): Level3DAudio.set_mix_db(sound, db, _mixer_audio_mode()))
	return tab.get_parent().get_parent()


# The Mixer tab's mode as Level3DAudio has it: the setting's, which the
# preview hands on to Level3DAudio only after the menu's refresh.
func _mixer_audio_mode() -> int:
	return settings.sound_mode


# A music part's ▶: on, it plays the part alone, looped, and turns to ■;
# again, it gives the stage's song back from where it was.
func _toggle_music(file: String) -> void:
	if Level3DAudio.auditioned_music() == file:
		Level3DAudio.end_music_audition()
	else:
		Level3DAudio.audition_music(file)
	_refresh_music_buttons()


func _refresh_music_buttons() -> void:
	var on := Level3DAudio.auditioned_music()
	for file in _music_sliders:
		(_music_sliders[file].get_meta("play") as Button).text = "■" if file == on else "▶"


func _refresh_mixer() -> void:
	var m := _mixer_audio_mode()
	for sound in _mix_sliders:
		_show_db(_mix_sliders[sound], Level3DAudio.mix_db(sound, m), Level3DAudio.saved_mix_db(sound, m))
	# A music part's row only in the mode that plays it: the boss's clips in
	# modern, its loop in classic (Level3DAudio.ADAPTIVE).
	var played := Level3DAudio.mode_music_files(m)
	for file in _music_sliders:
		_show_db(_music_sliders[file], Level3DAudio.music_db(file, m), Level3DAudio.saved_music_db(file, m))
		for control in _music_sliders[file].get_meta("row"):
			(control as Control).visible = played.has(file)
	_mix_update_status()
	_refresh_music_buttons()


func _mix_update_status() -> void:
	var changed_now := Level3DAudio.is_mix_changed()
	_mix_save.disabled = not changed_now
	if changed_now:
		_mix_status.text = "Unsaved changes"
	elif _mix_status.text == "Unsaved changes":
		_mix_status.text = ""


func _mix_grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	return grid


# A row of the Mixer tab: the name, a button to hear it, the gain in dB, and
# the gain in figures, in ACCENT while it differs from the file's.
func _mix_row(grid: GridContainer, text: String, audition: Callable, moved: Callable) -> HSlider:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var play := Button.new()
	play.text = "▶"
	play.custom_minimum_size = Vector2(44, 0)
	play.pressed.connect(audition)
	grid.add_child(play)
	var slider := HSlider.new()
	slider.min_value = MIX_MIN_DB
	slider.max_value = MIX_MAX_DB
	slider.step = MIX_STEP_DB
	slider.custom_minimum_size = Vector2(220, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size = Vector2(110, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value)
	slider.set_meta("db", value)
	slider.set_meta("play", play)
	slider.set_meta("row", [label, play, slider, value])
	slider.value_changed.connect(func(db: float):
		moved.call(db)
		_show_db(slider, db, float(slider.get_meta("saved", db)))
		_mix_update_status())
	# A sound is heard again when the slider is let go; a music part's own
	# row sees to it (_make_mixer_tab), since its ▶ is a switch.
	if not grid.has_meta("music"):
		slider.drag_ended.connect(func(value_changed: bool):
			if value_changed:
				audition.call())
	return slider


func _show_db(slider: HSlider, db: float, saved: float) -> void:
	slider.set_meta("saved", saved)
	slider.set_value_no_signal(db)
	var label: Label = slider.get_meta("db")
	label.text = "%+.1f dB" % db
	if is_equal_approx(db, saved):
		label.remove_theme_color_override("font_color")
	else:
		label.add_theme_color_override("font_color", ACCENT)


func _make_controls_tab() -> Control:
	var tab := _tab("Controls")
	# The modes first: they are changed far more often than the keys. Hidden
	# while the modern ones are (Level3DSettings.MODERN_CONTROLS): classic
	# is all there is to pick.
	var first_key := tab.get_child_count()
	var modes := _grid(tab)
	_driving = _choice(modes, "Driving", ["Classic", "Modern"],
			func(i: int): settings.driving = i)
	_note(tab, "Classic: the jeep drives the way the direction is pressed, as in the game. "
			+ "Modern: throttle and steering, like a real car.")
	var firing := _grid(tab)
	_firing = _choice(firing, "Firing", ["Classic", "Modern", "Combined"],
			func(i: int): settings.firing = i)
	_note(tab, "Classic: the machine gun forward, rockets the way the jeep faces. "
			+ "Modern: everything at the cursor. Combined: the machine gun always up the screen, rockets at the cursor.")
	var reach := _grid(tab)
	_reach = _choice(reach, "Reach", ["Classic", "Long", "Unlimited"],
			func(i: int): settings.reach = REACH_ORDER[i])
	_note(tab, "In any driving and firing mode. Classic: as in the game, about 5 m. "
			+ "Long: machine gun 12 m, rockets 16 m. "
			+ "Unlimited: they fly until they hit something. "
			+ "Rounds and rockets aimed with the cursor stop at it, but no further than the reach.")
	tab.add_child(HSeparator.new())
	if not Level3DSettings.MODERN_CONTROLS:
		for i in range(first_key, tab.get_child_count()):
			(tab.get_child(i) as Control).visible = false
	_smooth_turns = _check(tab, "Smooth turns", func(on: bool): settings.smooth_turns = on)
	_note(tab, "The jeep swings round into the direction pressed on a tight arc, and its tyres "
			+ "leave curves. Off: it goes the new way at once and turns after, as in the game.")
	_smooth_reverse = _check(tab, "Back up on reverse", func(on: bool): settings.smooth_reverse = on)
	_note(tab, "With smooth turns: the direction straight behind the jeep backs it up at once, as in the game, "
			+ "and held on, it swings round. Off: it turns round on a tight loop.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Keys")
	var keys := _grid(tab)
	for action in Level3DSettings.ACTIONS:
		var label := Label.new()
		label.text = ACTION_NAMES[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		keys.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 0)
		button.pressed.connect(func(): _prompt(action))
		keys.add_child(button)
		_key_buttons[action] = button
	var defaults := Button.new()
	defaults.text = "Default keys"
	defaults.size_flags_horizontal = Control.SIZE_SHRINK_END
	defaults.pressed.connect(func():
		_waiting = ""
		settings.reset_keys()
		_changed())
	tab.add_child(defaults)
	_note(tab, "Second player: the 2D game's second-player keys, by default the arrows, "
			+ "right Alt (machine gun) and right Ctrl (rockets). Rebound in the game: "
			+ "Options → 2p input. His devices are fixed: right Shift nitro, Enter mines, "
			+ "Delete airstrike.")
	tab.add_child(HSeparator.new())
	_heading(tab, "Gamepad")
	_pad = _check(tab, "Use a gamepad", func(on: bool): settings.pad = on)
	_pad_status = Label.new()
	_pad_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_pad_status.custom_minimum_size = Vector2(640, 0)
	tab.add_child(_pad_status)
	var pad := _grid(tab)
	_pad_single = _choice(pad, "One pad, two players", ["Player 1", "Player 2"],
			func(i: int): settings.pad_single = i)
	_pad_names = _choice(pad, "Button names", PAD_NAME_CHOICES,
			func(i: int): settings.pad_names = i)
	_pad_assist = _choice(pad, "Aim assist", PAD_ASSIST_CHOICES,
			func(i: int): settings.pad_assist = i)
	# The right stick's aim is the modern firing's, hidden with it.
	if not Level3DSettings.MODERN_CONTROLS:
		_pad_assist.visible = false
		pad.get_child(pad.get_child_count() - 2).visible = false
	for action in Level3DSettings.PAD_ACTIONS:
		var label := Label.new()
		label.text = ACTION_NAMES[action]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pad.add_child(label)
		var button := Button.new()
		button.custom_minimum_size = Vector2(220, 0)
		button.pressed.connect(func(): _prompt_pad(action))
		pad.add_child(button)
		_pad_buttons[action] = button
	_pad_vibration = _check(tab, "Vibration", func(on: bool): settings.pad_vibration = on)
	var pad_defaults := Button.new()
	pad_defaults.text = "Default buttons"
	pad_defaults.size_flags_horizontal = Control.SIZE_SHRINK_END
	pad_defaults.pressed.connect(func():
		_waiting_pad = ""
		settings.reset_pad()
		_changed())
	tab.add_child(pad_defaults)
	var sticks := "Left stick or d-pad: drive. " if not Level3DSettings.MODERN_CONTROLS \
			else "Classic driving: left stick or d-pad. Modern driving: R2 throttle, L2 brake " \
			+ "and reverse, left stick steers. Right stick: aim, with modern or combined firing; " \
			+ "the further it is tilted, the further the reticle, up to the reach. " \
			+ "Aim assist pulls the reticle on to an enemy near where the stick points, " \
			+ "and with the stick let go keeps it on him while the machine gun fires. "
	_note(tab, sticks
			+ "Start: this menu. Back: skip the landing. "
			+ "With one player every gamepad is his; with two, the first two are a player's each, "
			+ "and a single one is the player's picked above, the other keeping the keyboard. "
			+ "Button names: under Steam Input a DualSense may call itself an Xbox pad.")
	return tab.get_parent().get_parent()


func _make_cheats_tab() -> Control:
	var tab := _tab("Cheats")
	_infinite_lives = _check(tab, "Infinite lives", func(on: bool): settings.infinite_lives = on)
	_wall_hack = _check(tab, "Wall hack: drive through walls", func(on: bool): settings.wall_hack = on)
	_bullet_hack = _check(tab, "Bullet hack: immune to shots",
			func(on: bool): settings.bullet_hack = on)
	_note(tab, "Ramming a gun or a tank still kills.")
	tab.add_child(HSeparator.new())
	var rates := _grid(tab)
	var names := Level3DSettings.RATES.map(func(r: float): return "×1 (as the game)" if r == 1.0 else "×%s" % String.num(r))
	_gun_rate = _choice(rates, "Machine gun rate", names,
			func(i: int): settings.gun_rate = Level3DSettings.RATES[i])
	_launcher_rate = _choice(rates, "Launcher rate", names,
			func(i: int): settings.launcher_rate = Level3DSettings.RATES[i])
	return tab.get_parent().get_parent()


# ----------------------------------------------------------------------------
# Key prompts

# A key as its button writes it: a dash for none, a device whose default
# the player had already given another action (Level3DSettings._unshare).
static func _key_text(key: Key) -> String:
	return "—" if key == KEY_NONE else OS.get_keycode_string(key)


func _prompt(action: String) -> void:
	_waiting_pad = ""
	_waiting = action
	refresh()


func _prompt_pad(action: String) -> void:
	_waiting = ""
	_waiting_pad = action
	refresh()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	# No mouse: its clicks, wheel and hover kept from the controls.
	if event is InputEventMouse:
		get_viewport().set_input_as_handled()
		return
	if _waiting_pad != "":
		_pad_prompt_input(event)
		return
	# The left stick: one move a tip (Level3DPad.nav), not one each motion.
	var motion := event as InputEventJoypadMotion
	if motion != null and motion.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		get_viewport().set_input_as_handled()
		var move := Level3DPad.nav(event)
		if move != Vector2i.ZERO:
			_move(move)
		return
	if _waiting == "":
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	var button: Button = _key_buttons[_waiting]
	if key.keycode != KEY_ESCAPE:
		var code := key.keycode if key.keycode != KEY_NONE else key.physical_keycode
		settings.bind(_waiting, code)
	_waiting = ""
	_changed()
	button.grab_focus()


# A pad prompt's: a button pressed or a trigger pulled is bound; Start or
# Escape lets it be. The d-pad and the sticks are not bound -- they drive and
# aim -- and nothing else gets past while it waits, the focus included.
func _pad_prompt_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	var binding := Level3DPad.binding_of(event)
	var cancel := key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE \
			or binding == JOY_BUTTON_START
	if key == null and not event is InputEventJoypadButton and not event is InputEventJoypadMotion:
		return
	get_viewport().set_input_as_handled()
	if not cancel and (binding < 0 or Level3DPad.DPAD_NAMES.has(binding)):
		return
	var button: Button = _pad_buttons[_waiting_pad]
	if not cancel:
		settings.bind_pad(_waiting_pad, binding)
	_waiting_pad = ""
	_changed()
	button.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# L1 and R1 turn the settings' tabs, the focus on the tabs' bar.
	if _settings_page.visible and (Level3DPad.pressed(event, JOY_BUTTON_LEFT_SHOULDER)
			or Level3DPad.pressed(event, JOY_BUTTON_RIGHT_SHOULDER)):
		get_viewport().set_input_as_handled()
		var step := 1 if Level3DPad.pressed(event, JOY_BUTTON_RIGHT_SHOULDER) else -1
		_tabs.current_tab = wrapi(_tabs.current_tab + step, 0, _tabs.get_tab_count())
		_tabs.get_tab_bar().grab_focus()
		return
	var key := event as InputEventKey
	var escape := key != null and key.pressed and not key.echo and key.keycode == KEY_ESCAPE \
			or Level3DPad.pressed(event, JOY_BUTTON_B) or Level3DPad.pressed(event, JOY_BUTTON_START)
	if not escape:
		return
	get_viewport().set_input_as_handled()
	if _settings_page.visible:
		_show_main()
	else:
		close()


# ----------------------------------------------------------------------------
# Widgets

func _padded_box(panel: PanelContainer, gap: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	margin.add_child(box)
	return box


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button


# A tab's page: a scrolling column under the tab's name. Returns the column;
# the tab itself is its grandparent.
func _tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# The focus in view as the keys or a pad take it down a long tab.
	scroll.follow_focus = true
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	return column


func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	parent.add_child(grid)
	return grid


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", ACCENT)
	parent.add_child(label)


func _note(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(640, 0)
	label.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	parent.add_child(label)


func _choice(grid: GridContainer, text: String, items: Array, picked: Callable) -> OptionButton:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(340, 0)
	for item in items:
		option.add_item(item)
	option.item_selected.connect(func(i: int):
		picked.call(i)
		_changed())
	grid.add_child(option)
	return option


# `control`'s font FONT_SIZE + `delta`, in either font.
func _font_size(control: Control, delta: int) -> void:
	_font_sizes.append([control, delta])
	control.add_theme_font_size_override("font_size", _scaled(FONT_SIZE + delta))


func _scaled(size: int) -> int:
	if _font_style == Level3DFont.Style.MODERN:
		return size
	return maxi(roundi(size * PIXEL_FONT_SCALE / PIXEL_GRID), 1) * PIXEL_GRID


# The menu in settings.font's face, when it has changed: Press Start 2P sharp
# or smoothed, or Black Ops One.
func _apply_font() -> void:
	if settings.font == _font_style:
		return
	_font_style = settings.font
	var modern := _font_style == Level3DFont.Style.MODERN
	var font := (load(MODERN_FONT if modern else PIXEL_FONT) as FontFile).duplicate() as FontFile
	if _font_style == Level3DFont.Style.CLASSIC:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.hinting = TextServer.HINTING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	if not modern:
		# Its "fi" ligature is a glyph of its own, which reads as a smudge.
		font.opentype_feature_overrides = {TextServerManager.get_primary_interface().name_to_tag("liga"): 0}
	# The Mixer's ▶ and ■ are in neither.
	font.fallbacks = [ThemeDB.fallback_font]
	_theme.default_font = font
	_theme.default_font_size = _scaled(FONT_SIZE)
	for entry in _font_sizes:
		(entry[0] as Control).add_theme_font_size_override("font_size", _scaled(FONT_SIZE + entry[1]))
	_fit_width.call_deferred()


# The settings as wide as their widest tab, and a little more, whichever tab
# is up: a TabContainer is as wide as the tab it shows, and the panel grew and
# shrank from tab to tab. Again for each font, whose widths differ, once the
# new sizes have been laid out.
const WIDTH_SLACK := 40

func _fit_width() -> void:
	var widest := _tabs.get_tab_bar().get_combined_minimum_size().x
	for i in _tabs.get_tab_count():
		widest = maxf(widest, _tabs.get_tab_control(i).get_combined_minimum_size().x)
	_tabs.custom_minimum_size.x = widest + WIDTH_SLACK


# A volume, 0 to `top` % on the slider and 0 to top / 100 to `moved`, with
# the percentage beside it. A row of the grid: the label, then the two.
func _slider(grid: GridContainer, text: String, moved: Callable, top := 100.0) -> HSlider:
	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = top
	slider.step = 5.0
	slider.custom_minimum_size = Vector2(260, 0)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var value := Label.new()
	value.name = "Percent"
	value.custom_minimum_size = Vector2(68, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	slider.set_meta("percent", value)
	slider.value_changed.connect(func(v: float):
		moved.call(v / 100.0)
		_changed())
	grid.add_child(row)
	return slider


# A sound to hear a change by, once the change is on the buses: the menu's
# callbacks run before _changed hands it to the preview.
func _preview(sound: String) -> void:
	(func(): Level3DAudio.play(sound)).call_deferred()


func _show_percent(slider: HSlider) -> void:
	(slider.get_meta("percent") as Label).text = "%d%%" % roundi(slider.value)


func _check(parent: Control, text: String, toggled: Callable) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.toggled.connect(func(on: bool):
		toggled.call(on)
		_changed())
	parent.add_child(check)
	return check


# Frames, which the default theme has not: its panels and buttons are near
# black, and over the title screen's black there was nothing to see where a
# panel or a button ended. The panels have a light frame, the buttons, lists
# and tabs a grey one, white under the mouse and ACCENT on the one the keys
# are on; square, as the rest of the game's art is.
const FRAME := Color(0.85, 0.85, 0.85)
const FRAME_DIM := Color(0.5, 0.5, 0.5)
const FRAME_OFF := Color(0.28, 0.28, 0.28)


func _frame_styles(theme: Theme) -> void:
	theme.set_stylebox("panel", "PanelContainer", _box(Color(0.08, 0.08, 0.08, 0.97), FRAME, 3, 0))
	theme.set_stylebox("panel", "TabContainer", _box(Color(0.11, 0.11, 0.11), FRAME_DIM, 2, 0))
	theme.set_stylebox("panel", "PopupMenu", _box(Color(0.1, 0.1, 0.1), FRAME, 2, 6))
	theme.set_stylebox("hover", "PopupMenu", _box(Color(0.25, 0.25, 0.25), Color.TRANSPARENT, 0, 0))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, _box(Color(0.14, 0.14, 0.14), FRAME_DIM, 2, 8))
		theme.set_stylebox("hover", type, _box(Color(0.22, 0.22, 0.22), Color.WHITE, 2, 8))
		theme.set_stylebox("pressed", type, _box(Color(0.3, 0.26, 0.15), ACCENT, 2, 8))
		theme.set_stylebox("hover_pressed", type, _box(Color(0.3, 0.26, 0.15), ACCENT, 2, 8))
		theme.set_stylebox("disabled", type, _box(Color(0.1, 0.1, 0.1), FRAME_OFF, 2, 8))
		theme.set_stylebox("focus", type, _box(Color.TRANSPARENT, ACCENT, 3, 8))
	# A check box is a Button too, and stays a box and a label, with only the
	# keys' frame round it.
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		theme.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	# Out round it, not over it: the box's style is empty, so the frame drawn
	# on the check box's edges ran through its box.
	var check_focus := _box(Color.TRANSPARENT, ACCENT, 2, 2)
	check_focus.set_expand_margin_all(3)
	check_focus.expand_margin_left = 8
	check_focus.expand_margin_right = 8
	theme.set_stylebox("focus", "CheckBox", check_focus)
	theme.set_stylebox("tab_unselected", "TabContainer", _box(Color(0.1, 0.1, 0.1), FRAME_OFF, 2, 10, true))
	theme.set_stylebox("tab_hovered", "TabContainer", _box(Color(0.2, 0.2, 0.2), FRAME_DIM, 2, 10, true))
	theme.set_stylebox("tab_selected", "TabContainer", _box(Color(0.11, 0.11, 0.11), FRAME, 2, 10, true))
	theme.set_stylebox("tab_focus", "TabContainer", _box(Color.TRANSPARENT, ACCENT, 3, 10, true))
	theme.set_stylebox("tab_disabled", "TabContainer", _box(Color(0.1, 0.1, 0.1), FRAME_OFF, 2, 10, true))


# A square box: `fill`, a `frame` `width` px wide, `pad` px inside it; a
# tab's with no frame along its bottom, which is the page's.
static func _box(fill: Color, frame: Color, width: int, pad: int, tab := false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = frame
	box.set_border_width_all(width)
	if tab:
		box.border_width_bottom = 0
	box.content_margin_left = pad + width
	box.content_margin_right = pad + width
	box.content_margin_top = pad / 2 + width
	box.content_margin_bottom = pad / 2 + width
	return box


# A check box's icon, drawn rather than the default theme's, which is black on
# the panel's near black when it is not ticked: a light frame either way,
# filled with ACCENT and ticked in the panel's dark when it is.
func _box_icon(ticked: bool) -> ImageTexture:
	var side := ICON_SIZE * ICON_OVERSAMPLE
	var image := Image.create(side, side, false, Image.FORMAT_RGBA8)
	var frame := Color(0.85, 0.85, 0.85)
	var dark := Color(0.12, 0.1, 0.08)
	var line := 2.0 * ICON_OVERSAMPLE        # the frame's and the tick's width
	var inset := 1.5 * ICON_OVERSAMPLE
	var tick: Array[Vector2] = [Vector2(0.24, 0.52), Vector2(0.43, 0.7), Vector2(0.77, 0.3)]
	for y in side:
		for x in side:
			var p := Vector2(x + 0.5, y + 0.5)
			# How far inside the frame's outer edge, and so what covers it.
			var edge := minf(minf(p.x, p.y), minf(side - p.x, side - p.y)) - inset
			var outside := clampf(0.5 - edge, 0.0, 1.0)
			var on_frame := clampf(line - edge + 0.5, 0.0, 1.0) * (1.0 - outside)
			var colour := Color(0, 0, 0, 0)
			if ticked:
				colour = ACCENT
				colour.a = 1.0 - outside
				var d := minf(_to_segment(p, tick[0] * side, tick[1] * side),
						_to_segment(p, tick[1] * side, tick[2] * side))
				colour = colour.lerp(dark, clampf(line * 0.75 - d + 0.5, 0.0, 1.0) * colour.a)
			else:
				colour = Color(frame, on_frame)
			image.set_pixel(x, y, colour)
	var texture := ImageTexture.create_from_image(image)
	texture.set_size_override(Vector2i(ICON_SIZE, ICON_SIZE))
	return texture


static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
