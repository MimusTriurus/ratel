# The 3D preview's Escape menu: continue, a new game for one player or two,
# settings, quit, over the stage
# frozen by pausing the tree. The settings are seven tabs: six of
# Level3DSettings -- game (8-bit or modern, a preset of the others: the sound,
# the font, the look, the driving and firing), graphics (the camera and the
# look), interface (what the
# HUD shows, where and how big), sound (original, classic or modern, the volumes, the
# enemies' fire), controls (the keys, how the BTR drives and how it fires) and
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
# the first page back to the stage.
class_name Level3DMenu
extends CanvasLayer

const FONT_SIZE := 24
# Press Start 2P at FONT_SIZE is a letter as wide as it is tall, half as wide
# again as Godot's font: its sizes are scaled by this, so the panels hold it.
const PIXEL_FONT := "res://assets/fonts/PressStart2P-Regular.ttf"
const PIXEL_FONT_SCALE := 2.0 / 3.0
const MODERN_FONT := "res://assets/fonts/BlackOpsOne-Regular.ttf"
# The headings' colour, and a ticked box's.
const ACCENT := Color(1.0, 0.8, 0.3)
# The boxes' size in pixels of the 2048x1152 layout; drawn at ICON_OVERSAMPLE
# times that, so that they stay sharp scaled up to a bigger screen.
const ICON_SIZE := 26
const ICON_OVERSAMPLE := 2
# The Sound tab's sliders, one for each of the modern mode's sounds
# (Level3DAudio.SOUNDS), under a heading for each kind. enemy_hit is left out:
# it is only the original's layer under explode, which the modern mode's
# "blast" replaces. tools/verify_level3d_audio.gd checks that nothing else is.
const SOUND_GROUPS := [
	["BTR weapons", [["gun", "Machine gun"], ["grenade_launch", "Grenade launch"], ["rocket_launch", "Rocket launch"], ["rocket_flight", "Rocket flight"]]],
	["Hits", [["hit_ground", "On the ground"], ["hit_water", "On water"], ["hit_hard", "On concrete and walls"],
			["hit_dull", "On huts and gates"],
			["hit_armor", "On armour: machine gun"], ["hit_armor_blast", "On armour: rocket or mine"]]],
	["Enemy fire", [["enemy_mg", "Soldiers' machine guns"], ["enemy_cannon", "Cannons: bunkers, tanks, boats"]]],
	["Explosions", [["blast_small", "Grenade"], ["blast_missile", "Rocket"], ["blast_water", "In water"],
			["blast", "Enemy destroyed"], ["building", "Building destroyed"], ["breach_gun", "Boss tank breached: machine gun"],
			["breach_blast", "Boss tank breached: rocket or mine"],
			["player_explodes", "BTR destroyed"], ["soldier_death_gun", "Soldier killed: machine gun"],
			["soldier_death_blast", "Soldier killed: rocket or mine"],
			["soldier_death_run_over", "Soldier run over"]]],
	["Engines", [["btr_idle", "BTR idling"], ["btr_drive", "BTR driving"], ["tank_engine", "Tanks"],
			["boat_engine", "Boats"], ["chinook", "Chinook"], ["rescue_rotor", "Rescue helicopter"]]],
	["Interface", [["pickup", "Prisoner picked up"], ["rescue_pickup", "Prisoner aboard the helicopter"],
			["upgrade", "Weapon upgrade"], ["extra_life", "Extra life"], ["warning", "Boss warning"], ["pause", "Pause"]]],
	["Ambience", [["ambient_sea", "Sea"], ["ambient_jungle", "Jungle"]]],
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
}
const MIX_MIN_DB := -40.0
const MIX_MAX_DB := 12.0
const MIX_STEP_DB := 0.5
# Level3DSettings.Reach as the menu lists it, shortest first.
const REACH_ORDER := [Level3DSettings.Reach.CLASSIC, Level3DSettings.Reach.LONG, Level3DSettings.Reach.UNLIMITED]
const ACTION_NAMES := {
	"up": "Forward / up", "down": "Back / down", "left": "Left", "right": "Right",
	"gun": "Machine gun", "rocket": "Rocket",
}

var settings: Level3DSettings
var changed: Callable        # after every change, with the menu still open
var resumed: Callable        # once the menu has closed
# `new_game.call(players)`: the run started again for one player or two (the
# preview's co-op); the preview closes the menu.
var new_game: Callable
# Started by the level editor's Play (--editor): leaving is going back to it,
# which is waiting for this process to end.
var from_editor := false

var _main_page: Control
var _settings_page: Control
var _tabs: TabContainer
var _theme: Theme
# What has a font size of its own: [control, FONT_SIZE + this], scaled with
# the font's (_apply_font).
var _font_sizes: Array = []
var _font_style := -1        # the Level3DFont.Style the menu is drawn in
var _game_mode: OptionButton
var _camera: OptionButton
var _look: OptionButton
var _crt: CheckBox
var _resolution: OptionButton
var _driving: OptionButton
var _firing: OptionButton
var _reach: OptionButton
var _infinite_lives: CheckBox
var _wall_hack: CheckBox
var _bullet_hack: CheckBox
var _gun_rate: OptionButton
var _launcher_rate: OptionButton
var _hud: CheckBox
var _hud_score: CheckBox
var _hud_lives: CheckBox
var _hud_pows: CheckBox
var _hud_weapon: CheckBox
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
var _continue: Button


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


func is_open() -> bool:
	return visible


# With GameMode's pause sound, which its pause key plays both ways.
func open() -> void:
	visible = true
	get_tree().paused = true
	Level3DAudio.play("pause")
	_show_main()


func close() -> void:
	_waiting = ""
	visible = false
	# The stage's song again, if the Mixer tab put a part of another on.
	Level3DAudio.end_music_audition()
	get_tree().paused = false
	Level3DAudio.play("pause")
	if resumed.is_valid():
		resumed.call()


func _show_main() -> void:
	_waiting = ""
	_apply_font()
	_settings_page.visible = false
	_main_page.visible = true
	_continue.grab_focus()


func _show_settings() -> void:
	refresh()
	_main_page.visible = false
	_settings_page.visible = true
	_tabs.get_tab_bar().grab_focus()


# The widgets from `settings`, which the preview's own keys (Tab, V, M) change
# behind the menu's back.
func refresh() -> void:
	_apply_font()
	_game_mode.select(int(settings.preset()))
	_camera.select(settings.camera)
	_look.select(settings.look)
	_crt.set_pressed_no_signal(settings.crt)
	_resolution.select(settings.resolution)
	_driving.select(settings.driving)
	_firing.select(settings.firing)
	_reach.select(REACH_ORDER.find(settings.reach))
	_infinite_lives.set_pressed_no_signal(settings.infinite_lives)
	_wall_hack.set_pressed_no_signal(settings.wall_hack)
	_bullet_hack.set_pressed_no_signal(settings.bullet_hack)
	_gun_rate.select(Level3DSettings.RATES.find(settings.gun_rate))
	_launcher_rate.select(Level3DSettings.RATES.find(settings.launcher_rate))
	_hud.set_pressed_no_signal(settings.hud)
	_hud_score.set_pressed_no_signal(settings.hud_score)
	_hud_lives.set_pressed_no_signal(settings.hud_lives)
	_hud_pows.set_pressed_no_signal(settings.hud_pows)
	_hud_weapon.set_pressed_no_signal(settings.hud_weapon)
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
	for widget in [_hud_score, _hud_lives, _hud_pows, _hud_weapon, _hud_modes, _hud_cheats, _hud_pad_arrow,
			_hud_help, _hud_hints, _banner_stage, _banner_warning, _banner_mission, _hud_corner, _hud_rows, _hud_scale]:
		widget.disabled = not settings.hud
	for action in _key_buttons:
		var button: Button = _key_buttons[action]
		button.text = "..." if action == _waiting else OS.get_keycode_string(settings.key(action))


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
	_font_size(title, 8)
	box.add_child(title)
	_continue = _button(box, "Continue", close)
	_button(box, "New game: 1 player", func(): new_game.call(1))
	_button(box, "New game: 2 players", func(): new_game.call(2))
	_button(box, "Settings", _show_settings)
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
# picked.
func _make_game_tab() -> Control:
	var tab := _tab("Game")
	var grid := _grid(tab)
	_game_mode = _choice(grid, "Mode", ["8-bit", "Modern", "Custom"],
			func(i: int): settings.apply_preset(i as Level3DSettings.Preset))
	_game_mode.set_item_disabled(Level3DSettings.Preset.CUSTOM, true)
	_note(tab, "8-bit: the sounds and music as an NES plays them (classic sound), classic driving, "
			+ "firing and reach, the Press Start 2P pixel font, the pixel look and the CRT monitor.")
	_note(tab, "Modern: the new positional sound and its own music, modern driving (throttle and steering), "
			+ "firing at the cursor with the long reach, the Black Ops One font, the modern look without the CRT.")
	_note(tab, "A mode is a set of the settings on the other tabs. Change one of them there and the mode is "
			+ "custom; the camera, resolution, interface, volumes, keys and cheats do not depend on it.")
	return tab.get_parent().get_parent()


func _make_graphics_tab() -> Control:
	var tab := _tab("Graphics")
	var grid := _grid(tab)
	_camera = _choice(grid, "Camera", ["Top down", "Top down, tilted"],
			func(i: int): settings.camera = i)
	_look = _choice(grid, "Look", ["Modern", "Pixels"],
			func(i: int): settings.look = i)
	_resolution = _choice(grid, "3D resolution", ["Native", "2048×1152 (as the game)", "1920×1080", "1280×720"],
			func(i: int): settings.resolution = i)
	_crt = _check(tab, "CRT monitor", func(on: bool): settings.crt = on)
	return tab.get_parent().get_parent()


func _make_interface_tab() -> Control:
	var tab := _tab("Interface")
	_hud = _check(tab, "Show the HUD", func(on: bool): settings.hud = on)
	tab.add_child(HSeparator.new())
	_heading(tab, "What to show")
	_hud_score = _check(tab, "Score", func(on: bool): settings.hud_score = on)
	_hud_lives = _check(tab, "Lives", func(on: bool): settings.hud_lives = on)
	_hud_pows = _check(tab, "Prisoners aboard", func(on: bool): settings.hud_pows = on)
	_hud_weapon = _check(tab, "Weapon", func(on: bool): settings.hud_weapon = on)
	_hud_modes = _check(tab, "Driving and firing modes", func(on: bool): settings.hud_modes = on)
	_note(tab, "Off: a mode is shown for a couple of seconds when V or M changes it.")
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
	var layout := _grid(tab)
	_hud_corner = _choice(layout, "Position", ["Top", "Bottom"],
			func(i: int): settings.hud_corner = i)
	_hud_rows = _choice(layout, "Rows", ["One", "Two: score on its own"],
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
	_font_size(_mix_status, -6)
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
	# The modes first: they are changed far more often than the keys.
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
	_note(tab, "Second player: the 2D game's second-player keys and pad, by default the arrows, "
			+ "right Alt (machine gun) and right Ctrl (rockets). Rebound in the game: "
			+ "Options → 2p input. Always fires the classic way.")
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

func _prompt(action: String) -> void:
	_waiting = action
	refresh()


func _input(event: InputEvent) -> void:
	if not visible or _waiting == "":
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


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
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
	_font_size(label, -6)
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
	return roundi(size * PIXEL_FONT_SCALE) if _font_style != Level3DFont.Style.MODERN else size


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
	# The Mixer's ▶ and ■ are in neither.
	font.fallbacks = [ThemeDB.fallback_font]
	_theme.default_font = font
	_theme.default_font_size = _scaled(FONT_SIZE)
	for entry in _font_sizes:
		(entry[0] as Control).add_theme_font_size_override("font_size", _scaled(FONT_SIZE + entry[1]))


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
