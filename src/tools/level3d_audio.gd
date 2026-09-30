# The 3D preview's sound and music: what is heard, where it is heard from, and
# on which bus. Nothing here is the game's -- Main's Sfx, Song and their 125 ms
# throttle stay with the 2D game.
#
# Two modes, the menu's Sound tab (Level3DSettings.sound_mode), and a folder
# for each, holding the same set of files under the same names:
#
#   CLASSIC  assets/sfx3d/classic/, the original's effects as the game plays
#            them: flat, at the game's gains (explode at 0.65, enemy_hit at
#            0.6 under it), not looped, not pitched, inside Main's 125 ms
#            throttle. Each file is a copy of its "original" in
#            assets/soundeffects/, and what the original had no sound for --
#            engines, the enemies' guns, rounds landing, the sea -- is half a
#            second of silence. It is the base, and does not change;
#            tools/sfx3d_classic.gd made it.
#   MODERN   assets/sfx3d/modern/, positional, looped where "loop" says,
#            pitched, with the menu's per-sound gains. It started as a copy of
#            classic; a new sound goes in by replacing its file.
#
# A sound is <name>_0.ogg, and <name>_1.ogg ... for variants, one picked at
# random each play (a loop takes _0 alone). Both folders are imported and
# shipped as any other asset. A file missing is silence, which
# tools/verify_level3d_audio.gd reports. Every entry point below is a no-op
# when there is nothing to play, and when there is no Level3DAudio in the tree.
#
# The music is split the same way, chained in both as Song chains it: an
# intro, then a loop (MUSIC). assets/music3d/classic/ holds copies of the
# original's songs from assets/music/, under their own names, and does not
# change; assets/music3d/modern/ started as a copy of it, and a new song goes
# in by replacing its file. A change of mode swaps the part playing for the
# other folder's, from where it was.
#
# The gains, of the effects and of the music, are not in SOUNDS but in the
# mix (MIX_PATH), which the menu's Mixer tab sets by ear; the comments below
# say where some of them came from.
#
#   name -> {
#     bus        a sub-bus of Sfx, BUSES
#     original   the file in assets/soundeffects/ that classic's is a copy of,
#                or absent where classic's is silence. For the tools only
#     with       another sound played with this one, as
#                play_hit_explode_sound plays enemy_hit under explode; ""
#                for none
#     always     not throttled in CLASSIC, as play_sound_always is not
#     pitch      random pitch in MODERN, a fraction (0.05 = +-5 %)
#     loop       looped in MODERN, for attach_loop and stream; no variants, no
#                pitch. CLASSIC plays the file once, as the original replays
#                its helicopters when they run out, and the modules do too
#     voices     how many can sound at once; the oldest is cut off after that
#     gap        seconds: a second play inside it is dropped (CLASSIC takes
#                the longer of it and Main's 125 ms)
#     flat       not positional: the HUD's and the player's own
#     mixed      a loop whose volume its owner sets (the BTR's engine), which
#                the frame's gain is left to (_process)
#     classic, modern
#                any of the above for that mode alone, over the rest: say,
#                "modern": {"with": ""} for a new blast that has the hit in it
#   }
class_name Level3DAudio
extends Node3D

enum Mode { CLASSIC, MODERN }

const DIRS := {Mode.CLASSIC: "res://assets/sfx3d/classic/", Mode.MODERN: "res://assets/sfx3d/modern/"}
const MODE_KEYS := {Mode.CLASSIC: "classic", Mode.MODERN: "modern"}
const ORIGINAL := "res://assets/soundeffects/"
const MUSIC_DIRS := {Mode.CLASSIC: "res://assets/music3d/classic/", Mode.MODERN: "res://assets/music3d/modern/"}
# Where classic's songs are copies from: the 2D game's, Main.MUSIC.
const ORIGINAL_MUSIC := "res://assets/music/"
# name_0.ogg, name_1.ogg ... : looked for until the first one missing.
const MAX_VARIANTS := 16
# Main.MINIMUM_SOUND_TIME.
const CLASSIC_GAP := 0.125

# Under Sfx, which AudioSettings installs; EnemyFire under Weapons, so that
# the enemies' guns can be turned down or off on their own.
const BUSES := {&"Weapons": &"Sfx", &"EnemyFire": &"Weapons", &"Explosions": &"Sfx",
		&"Engines": &"Sfx", &"Ambient": &"Sfx", &"Interface": &"Sfx"}
const ENEMY_FIRE_BUS := &"EnemyFire"

# The frame is 30 m across at zoom 1 (the level's 2048 px at Level3DMap.PX).
# The listener hangs LISTENER_HEIGHT over its centre (listen), which is what
# the panning is taken from. The loudness is not the distance's: Godot's own
# falloff, inverse to the distance from the listener, had a blast at the
# frame's edge 8 dB under one in the middle, and its low-pass took the top
# off it as well, so that anything near the edge sounded muffled. Instead a
# sound is at its full gain anywhere in the frame and dies away over
# OFFSCREEN_FADE metres outside it (frame_gain), and nothing is filtered.
const LISTENER_HEIGHT := 8.0
const PANNING := 0.6
const OFFSCREEN_FADE := 15.0

const SOUNDS := {
	# The player's weapons. The modern gun's gain brings its loudest 50 ms
	# (RMS) down to machine_gun's; the grenade launcher's only half as far,
	# since throw is 10 dB under the gun, and at its level the new one was
	# lost under it.
	"gun": {"bus": &"Weapons", "pitch": 0.05, "voices": 6, "gap": 0.03,
			"original": "machine_gun.ogg", "always": true, "flat": true},
	"grenade_launch": {"bus": &"Weapons", "pitch": 0.05, "original": "throw.ogg", "flat": true},
	# The modern launch and flight were one recording, cut in two; both come
	# down by as much as brings the launch to missile's loudness, which keeps
	# the flight where the recording had it, 17 dB under.
	"rocket_launch": {"bus": &"Weapons", "pitch": 0.05, "original": "missile.ogg", "flat": true},
	# The rocket's motor, on the rocket from its launch to its blast
	# (Level3DRocket), pitched up as it speeds up. The original's missile
	# was one sound at the launch, which rocket_launch is.
	"rocket_flight": {"bus": &"Weapons", "loop": true},
	# Where rounds land, the player's and the enemies'. The original had none.
	"hit_ground": {"bus": &"Weapons", "pitch": 0.1, "voices": 4, "gap": 0.04},
	"hit_water": {"bus": &"Weapons", "pitch": 0.1, "voices": 4, "gap": 0.04},
	"hit_hard": {"bus": &"Weapons", "pitch": 0.1, "voices": 4, "gap": 0.04},
	# Enemy.bullet_attack's bullet_hit_sound: armour that took the round.
	"hit_armor": {"bus": &"Weapons", "pitch": 0.08, "voices": 4, "gap": 0.04,
			"original": "bullet_hit.ogg", "always": true},
	# The enemies' guns, which the original fired in silence: a machine gun
	# for the soldiers, a cannon for the bunkers, tanks and boats, on
	# EnemyFire, to sit well under the BTR's gun.
	"enemy_mg": {"bus": &"EnemyFire", "pitch": 0.06, "voices": 4, "gap": 0.05},
	"enemy_cannon": {"bus": &"EnemyFire", "pitch": 0.05, "voices": 4, "gap": 0.05},
	# Blasts. A grenade's and the mortar's are explode_sound2, a missile's
	# explode_sound3; both at 0.65. The modern ones' gains bring their loudest
	# 50 ms (RMS) to the originals', which keeps the missile's under the
	# bomb's, as explode3 is under explode2.
	"blast_small": {"bus": &"Explosions", "pitch": 0.08, "voices": 4,
			"original": "explode2.ogg"},
	"blast_missile": {"bus": &"Explosions", "pitch": 0.08, "voices": 4,
			"original": "explode3.ogg"},
	# The splash a rocket or a bomb raises on the water, over the weapon's own
	# blast (Level3DRocket._explode); modern only, so classic's copy of
	# explode2 is never heard. About 8 dB under the bomb's blast, which it is
	# heard over rather than in place of.
	"blast_water": {"bus": &"Explosions", "pitch": 0.08, "voices": 3,
			"original": "explode2.ogg"},
	# Anything destroyed: play_hit_explode_sound, enemy_hit under explode.
	"blast": {"bus": &"Explosions", "pitch": 0.06, "voices": 4,
			"original": "explode.ogg", "with": "enemy_hit"},
	"enemy_hit": {"bus": &"Explosions", "voices": 4, "original": "enemy_hit.ogg"},
	"building": {"bus": &"Explosions", "pitch": 0.05, "voices": 2, "original": "hut.ogg"},
	# A boss tank's first round of damage, which the preview shows as a breach.
	"breach": {"bus": &"Explosions", "pitch": 0.05, "voices": 2,
			"original": "bullet_hit.ogg", "always": true},
	"player_explodes": {"bus": &"Explosions", "original": "player_explodes.ogg", "flat": true},
	"soldier_death": {"bus": &"Explosions", "pitch": 0.1, "voices": 3, "gap": 0.125,
			"original": "soldier_killed.ogg"},
	# Engines. The original's jeep and tanks had none.
	"btr_idle": {"bus": &"Engines", "loop": true, "mixed": true},
	"btr_drive": {"bus": &"Engines", "loop": true, "mixed": true},
	"tank_engine": {"bus": &"Engines", "loop": true},
	"boat_engine": {"bus": &"Engines", "loop": true},
	# The helicopters: helicopter_sound and helicopter_sound2. The modern
	# files' gains bring their loudest 50 ms (RMS) down to the originals'.
	"chinook": {"bus": &"Engines", "loop": true, "original": "helicopter.ogg", "flat": true},
	"rescue_rotor": {"bus": &"Engines", "loop": true, "original": "helicopter2.ogg", "flat": true},
	# Prisoners, the HUD and the menu.
	"pickup": {"bus": &"Interface", "original": "pickup.ogg", "flat": true},
	"rescue_pickup": {"bus": &"Interface", "original": "helicopter_pickup.ogg", "flat": true},
	"upgrade": {"bus": &"Interface", "original": "weapon_upgrade.ogg", "flat": true},
	"warning": {"bus": &"Interface", "flat": true},
	# GameMode's pause key: the Escape menu opening and closing.
	"pause": {"bus": &"Interface", "original": "pause.ogg", "flat": true},
	# Under everything, for as long as the preview runs.
	"ambient_sea": {"bus": &"Ambient", "loop": true, "flat": true},
	"ambient_jungle": {"bus": &"Ambient", "loop": true, "flat": true},
}
const AMBIENCE: Array[String] = ["ambient_sea", "ambient_jungle"]

# Main.load_next's songs: the parts in order, the last looping.
const MUSIC := {
	# intro_song: IntroMapMode's, which runs on into stage 1.
	"intro": ["start.ogg", "stage0_intro.ogg", "stage0_repeat.ogg"],
	# stage_song0: the Chinook's trigger after a continue.
	"stage": ["stage0_intro.ogg", "stage0_repeat.ogg"],
	"boss": ["boss_intro.ogg", "boss_repeat.ogg"],
}

# Every sound's gain and every music part's, dB, for each mode: the game's
# mix, set by ear on the menu's Mixer tab, which writes it back here (save_mix).
#
#   {"classic": {"sounds": {name: dB}, "music": {file: dB}}, "modern": {...}}
#
# Classic's sounds start at the game's own gains (Main.play_sound's volume,
# 0.65 is -3.7 dB); a file that replaces one in modern/ starts at a gain from
# its measured loudness against the classic one (tools/measure_loudness.gd).
# Missing is 0 dB; tools/verify_level3d_audio.gd holds it to SOUNDS and MUSIC.
const MIX_PATH := "res://assets/sfx3d/mix.json"
static var _mix := {}
static var _mix_saved := {}     # as the file has it, for is_mix_changed

static var mode := Mode.MODERN
# The menu's gain for each sound, 0 to MAX_GAIN over its "db" (set_gains):
# the modern mode's only -- the classic one is the game's, as the game has it.
static var _gains := {}
const MAX_GAIN := 2.0
const SILENT_DB := -80.0
static var _current: Level3DAudio
# name -> {"stream", "db", "spec"}: what a name resolved to in this mode,
# with its SOUNDS entry, the mode's own over the rest.
static var _resolved := {}

# The frame, level x, z (listen); empty until the preview has said.
static var _frame := Rect2()
var _listener: AudioListener3D
var _music: AudioStreamPlayer
var _song: Array = []       # the parts still to come, file names
var _part := ""             # the part playing, "" for none
var _pools := {}            # name -> Array of players
var _next := {}             # name -> the voice to take when all are busy
var _last := {}             # name -> Time.get_ticks_msec() of the last play
var _loops: Array = []      # [WeakRef to the parent, name]: attach_loop's
var _ambience: Array = []
var _auditions: Array = []  # audition's players of loops, while they last
# What audition_music took the music off: [the parts still to come, the part,
# where it had got to or -1], or null.
var _held_music = null
# --audio-debug: every bus's mute, gain and peak, once a second, on the
# console -- whether anything reaches Master, and what is holding it back.
var _debug := false
var _debug_left := 0.0


func _ready() -> void:
	_current = self
	# The one-shots and the music go on under the Escape menu, which pauses the
	# tree: the menu's sliders are heard as they move, and the music keeps
	# playing as the game's in-game menu keeps it. The engines, on the units,
	# stop with them.
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioSettings.install_buses()
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, BUSES[bus])
	_listener = AudioListener3D.new()
	add_child(_listener)
	_listener.make_current()
	_music = AudioStreamPlayer.new()
	_music.bus = AudioSettings.MUSIC_BUS
	_music.finished.connect(_next_part)
	add_child(_music)
	_start_ambience()
	_debug = OS.get_cmdline_user_args().has("--audio-debug")
	# Always: the loops' gains follow the frame (_process).
	set_process(true)
	if _debug:
		var found := 0
		for name in SOUNDS:
			if resolve(name).stream != null:
				found += 1
		print("audio: driver %s, %d Hz, output device \"%s\"; sounds from %s; %s; %d of %d sounds have something to play" % [
				AudioServer.get_driver_name(), AudioServer.get_mix_rate(), AudioServer.output_device,
				DIRS[mode],
				"classic" if mode == Mode.CLASSIC else "modern", found, SOUNDS.size()])


func _exit_tree() -> void:
	if _current == self:
		_current = null
		# The players still hold what they play; the cache would otherwise
		# keep every stream alive past the end of the run.
		_resolved.clear()


func _process(delta: float) -> void:
	# The loops on the units, which move in and out of the frame, take its
	# gain every frame; not the ones their owner mixes, nor one dying away.
	for loop in _loops:
		var parent = loop[0].get_ref()
		if parent == null or not is_instance_valid(parent):
			continue
		var player := loop_on(parent, loop[1])
		if player == null or player.has_meta("fading") or resolve(loop[1]).spec.get("mixed", false):
			continue
		player.volume_db = volume_db(loop[1]) + _gain_db(frame_gain(player.global_position))
	if not _debug:
		return
	_debug_left -= delta
	if _debug_left > 0.0:
		return
	_debug_left = 1.0
	var parts: Array[String] = []
	for i in AudioServer.bus_count:
		var peak := maxf(AudioServer.get_bus_peak_volume_left_db(i, 0), AudioServer.get_bus_peak_volume_right_db(i, 0))
		parts.append("%s%s %+.0fdB peak %s" % [AudioServer.get_bus_name(i),
				" MUTED" if AudioServer.is_bus_mute(i) else "", AudioServer.get_bus_volume_db(i),
				"--" if peak <= -80.0 else "%.0f" % peak])
	var playing := 0
	for player in find_children("*", "", true, false):
		if (player is AudioStreamPlayer or player is AudioStreamPlayer3D) and player.playing:
			playing += 1
	print("audio: %s | %d own voices playing" % [" | ".join(parts), playing])


# ----------------------------------------------------------------------------
# What the rest of the preview calls

# A one-shot: at `at`, level coordinates, or flat when `at` is not a Vector3,
# the sound is flat or the mode is CLASSIC. Dropped inside its gap, and when
# there is nothing to play.
static func play(name: String, at: Variant = null) -> void:
	if _current != null:
		_current._play(name, at)


# The looping `name` on `parent`, playing, to follow it about: an engine. Null
# when there is nothing to play. Freed with its parent; stop_loop stops it
# first, for a parent that stays behind as a wreck. Kept track of, so that a
# change of mode gives it the new mode's sound, or takes it away.
static func attach_loop(name: String, parent: Node3D) -> AudioStreamPlayer3D:
	if _current == null or parent == null:
		return null
	_current._loops.append([weakref(parent), name])
	return _current._attach(name, parent)


static func stop_loop(parent: Node, name: String) -> void:
	if parent == null:
		return
	if _current != null:
		_current._loops = _current._loops.filter(func(l: Array): return not (l[0].get_ref() == parent and l[1] == name))
	var player := parent.get_node_or_null("Sound_" + name)
	if player != null:
		player.queue_free()


# attach_loop's player on `parent`, or null: what a caller mixes (the BTR's
# engine), looked up rather than kept, since a change of mode replaces it.
static func loop_on(parent: Node, name: String) -> AudioStreamPlayer3D:
	return parent.get_node_or_null("Sound_" + name) as AudioStreamPlayer3D if parent != null else null


# Where the frame is: the listener hangs over `at`, its centre, looking up
# the stage, and `frame` (level x, z, the preview's _view_frame) is what
# frame_gain measures from.
static func listen(at: Vector3, frame := Rect2()) -> void:
	_frame = frame
	if _current != null and _current._listener != null:
		_current._listener.global_position = at + Vector3.UP * LISTENER_HEIGHT


# A positional sound's gain for where it is: 1 in the frame, down to 0 at
# OFFSCREEN_FADE metres outside it; 1 before there is a frame.
static func frame_gain(at: Vector3) -> float:
	if not _frame.has_area():
		return 1.0
	return _outside_gain(Vector2(at.x, at.z), _frame, OFFSCREEN_FADE)


static func _outside_gain(at: Vector2, frame: Rect2, fade: float) -> float:
	var outside := Vector2(maxf(maxf(frame.position.x - at.x, at.x - frame.end.x), 0.0),
			maxf(maxf(frame.position.y - at.y, at.y - frame.end.y), 0.0)).length()
	return clampf(1.0 - outside / fade, 0.0, 1.0)


static func _gain_db(g: float) -> float:
	return linear_to_db(g) if g > 0.0 else SILENT_DB


# For a player a module keeps itself -- the helicopters', which set their own
# volume as they fly: the stream, or null. Asked again before each play, since
# the mode can change under it. Resolves without a Level3DAudio in the tree.
static func stream(name: String) -> AudioStream:
	return resolve(name).stream


# For those same players, which are flat, so that nothing fades them with
# distance: 1 while `at` (level x, z) is in `frame` (level x, z, as the
# preview's _view_frame), down to 0 at EDGE_FADE metres outside it. A
# helicopter coming in grows out of nothing, one going out dies away, rather
# than starting and stopping at full. Always 1 in CLASSIC, whose helicopters
# are the original's: at full from the first tick.
const EDGE_FADE := 10.0

static func edge_fade(at: Vector2, frame: Rect2) -> float:
	if mode == Mode.CLASSIC:
		return 1.0
	return _outside_gain(at, frame, EDGE_FADE)


# The last of a player, flat or positional, when what it is on goes: its gain
# taken to 0 over `seconds`, then stopped, then `done`. A loop would otherwise
# be cut off wherever it was, however loud. In CLASSIC stopped at once, as the
# original's are, and `done` at once. The tween is the player's, so freeing
# the player cancels it; kill it to keep the player (a reset).
const FADE_OUT := 1.0

static func fade_out(player: Node, done: Callable = Callable(), seconds := FADE_OUT) -> Tween:
	if player == null or not player.playing or mode == Mode.CLASSIC:
		if player != null:
			player.stop()
		if done.is_valid():
			done.call()
		return null
	# Left alone by _process from now on.
	player.set_meta("fading", true)
	var from: float = player.volume_db
	var tween := player.create_tween()
	tween.tween_method(func(g: float): player.volume_db = from + linear_to_db(maxf(g, 0.0001)),
			1.0, 0.0, seconds)
	tween.tween_callback(player.stop)
	if done.is_valid():
		tween.tween_callback(done)
	return tween


# The gain the stream wants, dB, to add to the caller's own: its "db", and
# the menu's gain for it over that.
static func volume_db(name: String) -> float:
	var g := gain(name)
	return resolve(name).db + (linear_to_db(g) if g > 0.0 else SILENT_DB)


# The menu's gain for `name`, 1 for as set; always 1 in CLASSIC.
static func gain(name: String) -> float:
	return clampf(float(_gains.get(name, 1.0)), 0.0, MAX_GAIN) if mode == Mode.MODERN else 1.0


# name -> 0 to MAX_GAIN, the Sound tab's sliders; a name left out is at 1.
# What is sounding now takes it at once: the loops and the ambience here, the
# helicopters and the BTR's engine as they ask volume_db every tick.
static func set_gains(gains: Dictionary) -> void:
	_gains = gains.duplicate()
	if _current != null:
		_current._regain()


static func bus(name: String) -> StringName:
	var bus_name: StringName = resolve(name).spec.get("bus", AudioSettings.SFX_BUS)
	return bus_name if AudioServer.get_bus_index(bus_name) >= 0 else AudioSettings.SFX_BUS


static func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_resolved.clear()
	if _current != null:
		_current._remake()
		_current._swap_music()


# The menu's volumes, 0 to 1, onto the buses: Master for everything, Music,
# Sfx for every effect, EnemyFire for the enemies' guns alone, and whether
# those are heard at all.
static func set_volumes(master: float, music: float, effects: float, enemy_fire: float,
		enemy_fire_on: bool) -> void:
	_volume(AudioSettings.MASTER_BUS, master)
	_volume(AudioSettings.MUSIC_BUS, music)
	_volume(AudioSettings.SFX_BUS, effects)
	_volume(ENEMY_FIRE_BUS, enemy_fire if enemy_fire_on else 0.0)


static func _volume(bus_name: StringName, level: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, level <= 0.0)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(level, 0.0001)))


# A flat one-shot of `name` that the caller can take back (fade_out): a
# player of its own, freed when it has played out, so is_instance_valid it
# first. Not throttled, not pooled, not "with" anything; for a sound that has
# to stop when something else happens -- the rocket's launch, which runs on
# into its flight, when the rocket goes off first. Null when there is nothing
# to play.
static func hold(name: String) -> AudioStreamPlayer:
	if _current == null:
		return null
	var entry := resolve(name)
	if entry.stream == null or gain(name) <= 0.0:
		return null
	var player := AudioStreamPlayer.new()
	player.stream = entry.stream
	player.volume_db = volume_db(name)
	player.bus = bus(name)
	_current.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return player


# One of MUSIC's songs, from its start; "" stops the music.
static func play_music(song: String) -> void:
	if _current == null:
		return
	_current._held_music = null
	_current._song = MUSIC.get(song, []).duplicate()
	_current._music.stop()
	_current._next_part()


static func stop_music() -> void:
	play_music("")


# ----------------------------------------------------------------------------
# The mix (MIX_PATH), and hearing it: the menu's Mixer tab

static func _mix_loaded() -> Dictionary:
	if _mix.is_empty():
		reload_mix()
	return _mix


static func _mode_key(for_mode: int) -> String:
	return MODE_KEYS[mode if for_mode < 0 else for_mode]


# `name`'s gain in the mix, dB: the current mode's, or `for_mode`'s.
static func mix_db(name: String, for_mode: int = -1) -> float:
	return float(_mix_loaded().get(_mode_key(for_mode), {}).get("sounds", {}).get(name, 0.0))


# A music part's gain in the mix, dB, by its file name.
static func music_db(file: String, for_mode: int = -1) -> float:
	return float(_mix_loaded().get(_mode_key(for_mode), {}).get("music", {}).get(file, 0.0))


# What the file says, as against what the mix is now.
static func saved_mix_db(name: String, for_mode: int = -1) -> float:
	return float(_mix_saved.get(_mode_key(for_mode), {}).get("sounds", {}).get(name, 0.0))


static func saved_music_db(file: String, for_mode: int = -1) -> float:
	return float(_mix_saved.get(_mode_key(for_mode), {}).get("music", {}).get(file, 0.0))


static func is_mix_changed() -> bool:
	return _mix_loaded() != _mix_saved


# `name`'s gain in `for_mode`'s mix, heard at once if that is the mode
# playing, as set_gains is: the voices as they are next played, the loops and
# the ambience now, the helicopters and the BTR's engine on their next tick.
static func set_mix_db(name: String, db: float, for_mode: int = -1) -> void:
	_set_mix(_mode_key(for_mode), "sounds", name, db)
	if for_mode >= 0 and for_mode != mode:
		return
	if _resolved.has(name):
		_resolved[name].db = db
	if _current != null:
		_current._regain()


static func set_music_db(file: String, db: float, for_mode: int = -1) -> void:
	_set_mix(_mode_key(for_mode), "music", file, db)
	if _current != null and (for_mode < 0 or for_mode == mode) and _current._part == file:
		_current._music.volume_db = db


static func _set_mix(key: String, kind: String, name: String, db: float) -> void:
	var mix := _mix_loaded()
	if not mix.has(key):
		mix[key] = {"sounds": {}, "music": {}}
	if not mix[key].has(kind):
		mix[key][kind] = {}
	mix[key][kind][name] = db


# The file again, over whatever was changed since.
static func reload_mix() -> void:
	var text := FileAccess.get_file_as_string(MIX_PATH)
	var parsed = JSON.parse_string(text) if not text.is_empty() else null
	if typeof(parsed) != TYPE_DICTIONARY:
		if not text.is_empty():
			push_warning("Level3DAudio: cannot read %s" % MIX_PATH)
		parsed = {}
	for key in MODE_KEYS.values():
		if not parsed.has(key):
			parsed[key] = {}
		for kind in ["sounds", "music"]:
			if typeof(parsed[key].get(kind)) != TYPE_DICTIONARY:
				parsed[key][kind] = {}
	_mix = parsed
	_mix_saved = parsed.duplicate(true)
	for name in _resolved:
		_resolved[name].db = mix_db(name)
	if _current != null:
		_current._regain()
		if not _current._part.is_empty():
			_current._music.volume_db = music_db(_current._part)


# The mix into MIX_PATH, which only works where res:// is the project's folder
# (the editor, a run from the source), not in an exported build.
static func save_mix() -> Error:
	var out := FileAccess.open(MIX_PATH, FileAccess.WRITE)
	if out == null:
		return FileAccess.get_open_error()
	out.store_string(serialize_mix(_mix_loaded()))
	out.close()
	_mix_saved = _mix.duplicate(true)
	return OK


# The file's layout: every sound of SOUNDS and every part of MUSIC, in their
# order, one to a line, so that a change of one gain is one line of diff.
static func serialize_mix(mix: Dictionary) -> String:
	var modes: Array[String] = []
	for key in MODE_KEYS.values():
		var section: Dictionary = mix.get(key, {})
		var sounds: Array[String] = []
		for name in SOUNDS:
			sounds.append("      %s: %s" % [JSON.stringify(name), _db_text(section.get("sounds", {}).get(name, 0.0))])
		var music: Array[String] = []
		for file in music_files():
			music.append("      %s: %s" % [JSON.stringify(file), _db_text(section.get("music", {}).get(file, 0.0))])
		modes.append("  %s: {\n    \"sounds\": {\n%s\n    },\n    \"music\": {\n%s\n    }\n  }" % [
				JSON.stringify(key), ",\n".join(sounds), ",\n".join(music)])
	return "{\n%s\n}\n" % ",\n".join(modes)


static func _db_text(db: float) -> String:
	return "%.1f" % snappedf(db, 0.1)


# Every part of every song of MUSIC, once each, in order.
static func music_files() -> Array[String]:
	var files: Array[String] = []
	for song in MUSIC:
		for file in MUSIC[song]:
			if not files.has(file):
				files.append(file)
	return files


# `name` once, flat, as the mix has it: a one-shot as play plays it, "with"
# and all; a loop for AUDITION_SECONDS, then faded out.
const AUDITION_SECONDS := 3.0

static func audition(name: String) -> void:
	if _current == null:
		return
	if not spec_of(name).get("loop", false):
		_current._last.erase(name)
		play(name)
		return
	var player := hold(name)
	if player == null:
		return
	player.set_meta("sound", name)
	_current._auditions.append(player)
	player.tree_exited.connect(func(): _current._auditions.erase(player) if _current != null else null)
	var tween := player.create_tween()
	tween.tween_interval(AUDITION_SECONDS)
	tween.tween_callback(func(): fade_out(player, player.queue_free))


# A music part alone, looped, in place of the song playing, which
# end_music_audition gives back from where it was.
static func audition_music(file: String) -> void:
	if _current == null:
		return
	var c := _current
	var stream := c._music_stream(file, true)
	if stream == null:
		return
	if c._held_music == null:
		c._held_music = [c._song.duplicate(), c._part,
				c._music.get_playback_position() if c._music.playing else -1.0]
	c._song = []
	c._part = file
	c._music.stream = stream
	c._music.volume_db = music_db(file)
	c._music.play()


static func end_music_audition() -> void:
	if _current == null or _current._held_music == null:
		return
	var c := _current
	var held: Array = c._held_music
	c._held_music = null
	c._music.stop()
	c._song = held[0]
	c._part = ""
	if held[1] == "" or held[2] < 0.0:
		return
	var stream := c._music_stream(held[1], c._song.is_empty())
	if stream == null:
		return
	c._part = held[1]
	c._music.stream = stream
	c._music.volume_db = music_db(held[1])
	c._music.play(held[2])


# The mode's folder's variants of `name`, or nothing.
static func resolve(name: String) -> Dictionary:
	if _resolved.has(name):
		return _resolved[name]
	var spec := spec_of(name)
	var loop: bool = spec.get("loop", false) and mode == Mode.MODERN
	var variants: Array[AudioStream] = []
	for k in (1 if spec.get("loop", false) else MAX_VARIANTS):
		var path := "%s%s_%d.ogg" % [DIRS[mode], name, k]
		if not ResourceLoader.exists(path):
			break
		var stream: AudioStream = load(path)
		if stream == null:
			push_warning("Level3DAudio: cannot read %s" % path)
			break
		if stream is AudioStreamOggVorbis:
			# A copy, as the music's is: the loop flag is this mode's.
			stream = stream.duplicate()
			(stream as AudioStreamOggVorbis).loop = loop
		variants.append(stream)
	var entry := {"stream": null, "db": mix_db(name), "spec": spec}
	if not variants.is_empty():
		var pitch: float = spec.get("pitch", 0.0) if mode == Mode.MODERN else 0.0
		entry.stream = variants[0] if spec.get("loop", false) else _randomizer(variants, pitch)
	_resolved[name] = entry
	return entry


# SOUNDS' entry for `name`, with its "classic" or "modern" over the rest: the
# current mode's, or `for_mode`'s.
static func spec_of(name: String, for_mode: int = -1) -> Dictionary:
	var spec: Dictionary = SOUNDS.get(name, {})
	if spec.is_empty():
		push_warning("Level3DAudio: no sound called %s" % name)
	return spec.merged(spec.get(MODE_KEYS[mode if for_mode < 0 else for_mode], {}), true)


static func _randomizer(streams: Array, pitch: float) -> AudioStreamRandomizer:
	var r := AudioStreamRandomizer.new()
	r.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS if streams.size() > 2 \
			else AudioStreamRandomizer.PLAYBACK_RANDOM
	for i in streams.size():
		r.add_stream(i, streams[i])
	# random_pitch is a scale, 1 for none: 1.05 is up to 5 % either way.
	r.random_pitch = 1.0 + pitch
	return r


# ----------------------------------------------------------------------------
# The voices

func _play(name: String, at: Variant) -> void:
	var entry := resolve(name)
	var spec: Dictionary = entry.spec
	if entry.stream == null or gain(name) <= 0.0:
		return
	var gap: float = spec.get("gap", 0.0)
	if mode == Mode.CLASSIC and not spec.get("always", false):
		gap = maxf(gap, CLASSIC_GAP)
	var now := Time.get_ticks_msec()
	if gap > 0.0 and _last.has(name) and now - int(_last[name]) < int(gap * 1000.0):
		return
	var flat: bool = typeof(at) != TYPE_VECTOR3 or spec.get("flat", false) or mode == Mode.CLASSIC
	var where := 1.0 if flat else frame_gain(at)
	if where <= 0.0:
		return
	var player = _voice(name, flat)
	if player == null:
		return
	_last[name] = now
	if not flat:
		(player as AudioStreamPlayer3D).global_position = at
	player.volume_db = volume_db(name) + _gain_db(where)
	player.play()
	if spec.get("with", "") != "":
		_play(spec.with, at)


# A free voice of `name`'s pool, or the oldest busy one; the pool grows to
# its voices. Null when there is nothing to play.
func _voice(name: String, flat: bool):
	var key := name + ("/flat" if flat else "")
	if not _pools.has(key):
		_pools[key] = []
		_next[key] = 0
	var pool: Array = _pools[key]
	for player in pool:
		if not player.playing:
			return player
	var voices: int = resolve(name).spec.get("voices", 1)
	if pool.size() < voices:
		var player = _new_player(name, flat)
		if player != null:
			pool.append(player)
		return player
	if pool.is_empty():
		return null
	var i: int = _next[key] % pool.size()
	_next[key] = i + 1
	return pool[i]


func _new_player(name: String, flat: bool):
	var entry := resolve(name)
	if entry.stream == null:
		return null
	if flat:
		var player := AudioStreamPlayer.new()
		player.stream = entry.stream
		player.volume_db = volume_db(name)
		player.bus = bus(name)
		add_child(player)
		return player
	var player := AudioStreamPlayer3D.new()
	_setup_3d(player, name, entry)
	add_child(player)
	return player


func _attach(name: String, parent: Node3D) -> AudioStreamPlayer3D:
	var entry := resolve(name)
	if entry.stream == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = "Sound_" + name
	_setup_3d(player, name, entry)
	parent.add_child(player)
	if not entry.spec.get("mixed", false):
		player.volume_db += _gain_db(frame_gain(player.global_position))
	player.play()
	return player


func _setup_3d(player: AudioStreamPlayer3D, name: String, entry: Dictionary) -> void:
	player.stream = entry.stream
	player.volume_db = volume_db(name)
	player.bus = bus(name)
	# Panned from where it is, but as loud anywhere in the frame (frame_gain)
	# and not filtered: see OFFSCREEN_FADE.
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.attenuation_filter_db = 0.0
	player.panning_strength = PANNING


# After a change of mode: every voice goes, to be made again from the new
# mode's streams as it is next wanted; every loop is put back on its unit, or
# not, if the new mode has nothing for it; and the ambience starts over.
func _remake() -> void:
	for key in _pools:
		for player in _pools[key]:
			player.queue_free()
	_pools.clear()
	_next.clear()
	for player in _ambience:
		player.queue_free()
	_ambience.clear()
	var kept: Array = []
	for loop in _loops:
		var parent = loop[0].get_ref()
		if parent == null or not is_instance_valid(parent):
			continue
		var old := (parent as Node).get_node_or_null("Sound_" + loop[1])
		if old != null:
			# Renamed first: the new one takes the name before this is freed.
			old.name = "Sound_old_" + loop[1]
			old.queue_free()
		_attach(loop[1], parent)
		kept.append(loop)
	_loops = kept
	_start_ambience()


# After set_gains: the loops on the units and the ambience, which play on
# and would otherwise keep the gain they started with.
func _regain() -> void:
	for loop in _loops:
		var parent = loop[0].get_ref()
		if parent != null and is_instance_valid(parent):
			var player := loop_on(parent, loop[1])
			if player != null:
				player.volume_db = volume_db(loop[1])
	for player in _ambience:
		player.volume_db = volume_db(player.get_meta("sound"))
	for player in _auditions:
		if is_instance_valid(player) and not player.has_meta("fading"):
			player.volume_db = volume_db(player.get_meta("sound"))


func _start_ambience() -> void:
	for name in AMBIENCE:
		var player = _new_player(name, true)
		if player != null:
			player.set_meta("sound", name)
			player.play()
			_ambience.append(player)


# ----------------------------------------------------------------------------
# The music

func _next_part() -> void:
	_part = ""
	if _song.is_empty():
		return
	var file: String = _song.pop_front()
	var stream := _music_stream(file, _song.is_empty())
	if stream == null:
		push_warning("Level3DAudio: no music %s%s" % [MUSIC_DIRS[mode], file])
		_song.clear()
		return
	_part = file
	_music.stream = stream
	_music.volume_db = music_db(file)
	_music.play()


# The mode's folder's `file`, looped if it is the song's last part, or null.
func _music_stream(file: String, loop: bool) -> AudioStream:
	var path: String = MUSIC_DIRS[mode] + file
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		return null
	# A copy, as Song.make_player makes one: the loop flag is the copy's.
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	return stream


# After set_mode: the part playing, from the new mode's folder, from where the
# old one had got to. A new song need not be as long as the original: past
# its end an intro goes on to the next part, and the loop wraps round.
func _swap_music() -> void:
	if _part.is_empty() or not _music.playing:
		return
	var at := _music.get_playback_position()
	var stream := _music_stream(_part, _song.is_empty())
	if stream == null:
		push_warning("Level3DAudio: no music %s%s" % [MUSIC_DIRS[mode], _part])
		_music.stop()
		_part = ""
		_song.clear()
		return
	var length := stream.get_length()
	if at >= length:
		if not _song.is_empty():
			_music.stop()
			_next_part()
			return
		at = fmod(at, length) if length > 0.0 else 0.0
	_music.stream = stream
	_music.volume_db = music_db(_part)
	_music.play(at)
