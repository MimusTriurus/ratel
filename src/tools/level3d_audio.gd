# The 3D preview's sound and music: what is heard, where it is heard from, and
# on which bus. Nothing here is the game's -- Main's Sfx, Song and their 125 ms
# throttle stay with the 2D game.
#
# Two modes, the menu's Sound tab (Level3DSettings.sound_mode):
#
#   CLASSIC  the original's effects only, as the game plays them: flat, at the
#            game's gains (explode at 0.65, enemy_hit at 0.6 under it), inside
#            Main's 125 ms throttle. What the original had no sound for --
#            engines, the enemies' guns, rounds landing, the sea -- is silent.
#   MODERN   placeholders where there are any, positional, with engines,
#            ambience and the enemies' fire; the original's effect where there
#            is none, and silence where the original had none either.
#
# The placeholders are looked for in assets/sfx_wt/, which
# tools/wt_placeholders.py fills from War Thunder's FMOD project for modders.
# That content is licensed for War Thunder mods only, so the folder is in
# .gitignore, excluded from the export preset and carries a .gdignore: never
# imported, committed or shipped. The files are read straight off the disk
# (AudioStreamOggVorbis.load_from_file) for the same reason. Without them --
# a fresh clone, anyone else's machine, an exported build -- MODERN is CLASSIC
# with positional sound. Every entry point below is a no-op when there is
# nothing to play, and when there is no Level3DAudio in the tree at all.
#
# The music is the original's in both modes, chained as Song chains it: an
# intro, then a loop (MUSIC).
#
#   name -> {
#     bus        a sub-bus of Sfx, BUSES
#     db         gain for the placeholder, dB: set from its measured loudness
#                (the loudest 50 ms, RMS) to a level per kind, so that the
#                placeholders sit where the original's effects do and each
#                kind against the others -- the enemies' fire well under the
#                BTR's gun
#     fallback   the original's file in assets/soundeffects/, or absent
#     fdb        gain for the fallback, dB: the game's own (Main.play_sound's
#                volume, 0.65 is -3.7 dB)
#     with       another sound played with the fallback, as
#                play_hit_explode_sound plays enemy_hit under explode
#     always     not throttled in CLASSIC, as play_sound_always is not
#     pitch      random pitch either way, a fraction (0.05 = +-5 %)
#     loop       looped, for attach_loop and stream; no variants, no pitch
#     voices     how many can sound at once; the oldest is cut off after that
#     gap        seconds: a second play inside it is dropped (CLASSIC takes
#                the longer of it and Main's 125 ms)
#     flat       not positional: the HUD's and the player's own
#   }
class_name Level3DAudio
extends Node3D

enum Mode { CLASSIC, MODERN }

const DIR := "res://assets/sfx_wt/"
const ORIGINAL := "res://assets/soundeffects/"
const MUSIC_DIR := "res://assets/music/"
# name_0.ogg, name_1.ogg ... : looked for until the first one missing.
const MAX_VARIANTS := 16
# Main.MINIMUM_SOUND_TIME.
const CLASSIC_GAP := 0.125

# Under Sfx, which AudioSettings installs; EnemyFire under Weapons, so that
# the enemies' guns can be turned down or off on their own.
const BUSES := {&"Weapons": &"Sfx", &"EnemyFire": &"Weapons", &"Explosions": &"Sfx",
		&"Engines": &"Sfx", &"Ambient": &"Sfx", &"Interface": &"Sfx"}
const ENEMY_FIRE_BUS := &"EnemyFire"

# The frame is 30 m across at zoom 1 (the level's 2048 px at Level3DMap.PX),
# so everything on it is within about 17 m of its centre. The listener hangs
# over that centre (listen); a sound is at full gain inside UNIT_SIZE of it and
# gone at MAX_DISTANCE, a frame and a half away.
const LISTENER_HEIGHT := 8.0
const UNIT_SIZE := 10.0
const MAX_DISTANCE := 60.0
const PANNING := 0.6

const SOUNDS := {
	# The player's weapons. The gun at the original's machine_gun, -17 dB.
	"gun": {"bus": &"Weapons", "db": -10.5, "pitch": 0.05, "voices": 6, "gap": 0.03,
			"fallback": "machine_gun.ogg", "always": true, "flat": true},
	"grenade_launch": {"bus": &"Weapons", "db": -13.0, "pitch": 0.05, "fallback": "throw.ogg", "flat": true},
	"rocket_launch": {"bus": &"Weapons", "db": -6.5, "pitch": 0.05, "fallback": "missile.ogg", "flat": true},
	# Where rounds land, the player's and the enemies'. The original had none.
	"hit_ground": {"bus": &"Weapons", "db": -18.5, "pitch": 0.1, "voices": 4, "gap": 0.04},
	"hit_water": {"bus": &"Weapons", "db": -21.0, "pitch": 0.1, "voices": 4, "gap": 0.04},
	"hit_hard": {"bus": &"Weapons", "db": -25.0, "pitch": 0.1, "voices": 4, "gap": 0.04},
	# Enemy.bullet_attack's bullet_hit_sound: armour that took the round.
	"hit_armor": {"bus": &"Weapons", "db": -13.5, "pitch": 0.08, "voices": 4, "gap": 0.04,
			"fallback": "bullet_hit.ogg", "always": true},
	# The enemies' guns, which the original fired in silence: a machine gun
	# for the soldiers, a cannon for the bunkers, tanks and boats, both at
	# -26 dB, nine under the BTR's gun, and on EnemyFire.
	"enemy_mg": {"bus": &"EnemyFire", "db": -21.0, "pitch": 0.06, "voices": 4, "gap": 0.05},
	"enemy_cannon": {"bus": &"EnemyFire", "db": -21.0, "pitch": 0.05, "voices": 4, "gap": 0.05},
	# Blasts. A grenade's and the mortar's are explode_sound2, a missile's
	# explode_sound3; both at 0.65.
	"blast_small": {"bus": &"Explosions", "db": -6.5, "pitch": 0.08, "voices": 4,
			"fallback": "explode2.ogg", "fdb": -3.7},
	"blast_missile": {"bus": &"Explosions", "db": -6.5, "pitch": 0.08, "voices": 4,
			"fallback": "explode3.ogg", "fdb": -3.7},
	"blast_water": {"bus": &"Explosions", "db": -3.5, "pitch": 0.08, "voices": 3,
			"fallback": "explode2.ogg", "fdb": -3.7},
	# Anything destroyed: play_hit_explode_sound, enemy_hit under explode.
	"blast": {"bus": &"Explosions", "db": -3.5, "pitch": 0.06, "voices": 4,
			"fallback": "explode.ogg", "fdb": -3.7, "with": "enemy_hit"},
	"enemy_hit": {"bus": &"Explosions", "voices": 4, "fallback": "enemy_hit.ogg", "fdb": -4.4},
	"building": {"bus": &"Explosions", "db": -2.0, "pitch": 0.05, "voices": 2, "fallback": "hut.ogg"},
	# A boss tank's first round of damage, which the preview shows as a breach.
	"breach": {"bus": &"Explosions", "db": -13.5, "pitch": 0.05, "voices": 2,
			"fallback": "bullet_hit.ogg", "always": true},
	"player_explodes": {"bus": &"Explosions", "db": -2.5, "fallback": "player_explodes.ogg", "flat": true},
	"soldier_death": {"bus": &"Explosions", "pitch": 0.1, "voices": 3, "gap": 0.125,
			"fallback": "soldier_killed.ogg"},
	# Engines. The original's jeep and tanks had none.
	"btr_idle": {"bus": &"Engines", "db": -3.0, "loop": true},
	"btr_drive": {"bus": &"Engines", "db": -6.5, "loop": true},
	"tank_engine": {"bus": &"Engines", "db": -10.0, "loop": true},
	"boat_engine": {"bus": &"Engines", "db": -16.0, "loop": true},
	# The helicopters: helicopter_sound and helicopter_sound2, which the
	# original replays each time it runs out rather than looping.
	"chinook": {"bus": &"Engines", "db": -3.0, "loop": true, "fallback": "helicopter.ogg", "flat": true},
	"rescue_rotor": {"bus": &"Engines", "db": -5.5, "loop": true, "fallback": "helicopter2.ogg",
			"flat": true},
	# Prisoners, the HUD and the menu.
	"pickup": {"bus": &"Interface", "fallback": "pickup.ogg", "flat": true},
	"rescue_pickup": {"bus": &"Interface", "db": -1.0, "fallback": "helicopter_pickup.ogg", "flat": true},
	"upgrade": {"bus": &"Interface", "db": -11.0, "fallback": "weapon_upgrade.ogg", "flat": true},
	"warning": {"bus": &"Interface", "db": 3.0, "flat": true},
	# GameMode's pause key: the Escape menu opening and closing.
	"pause": {"bus": &"Interface", "fallback": "pause.ogg", "flat": true},
	# Under everything, for as long as the preview runs.
	"ambient_sea": {"bus": &"Ambient", "db": -6.5, "loop": true, "flat": true},
	"ambient_jungle": {"bus": &"Ambient", "db": 10.0, "loop": true, "flat": true},
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

static var mode := Mode.MODERN
# The menu's gain for each sound, 0 to MAX_GAIN over its "db" (set_gains):
# the modern mode's only -- the classic one is the game's, as the game has it.
static var _gains := {}
const MAX_GAIN := 2.0
const SILENT_DB := -80.0
static var _current: Level3DAudio
# name -> {"stream", "db", "original"}: what a name resolved to in this mode.
static var _resolved := {}

var _listener: AudioListener3D
var _music: AudioStreamPlayer
var _song: Array = []       # the parts still to come, file names
var _pools := {}            # name -> Array of players
var _next := {}             # name -> the voice to take when all are busy
var _last := {}             # name -> Time.get_ticks_msec() of the last play
var _loops: Array = []      # [WeakRef to the parent, name]: attach_loop's
var _ambience: Array = []
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
	set_process(_debug)
	if _debug:
		var found := 0
		for name in SOUNDS:
			if resolve(name).stream != null:
				found += 1
		print("audio: driver %s, %d Hz, output device \"%s\"; placeholders %s; %s; %d of %d sounds have something to play" % [
				AudioServer.get_driver_name(), AudioServer.get_mix_rate(), AudioServer.output_device,
				"found" if DirAccess.dir_exists_absolute(DIR) else "absent",
				"classic" if mode == Mode.CLASSIC else "modern", found, SOUNDS.size()])


func _exit_tree() -> void:
	if _current == self:
		_current = null
		# The players still hold what they play; the cache would otherwise
		# keep every stream alive past the end of the run.
		_resolved.clear()


func _process(delta: float) -> void:
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


# Where the frame is: the listener hangs over it, looking up the stage.
static func listen(at: Vector3) -> void:
	if _current != null and _current._listener != null:
		_current._listener.global_position = at + Vector3.UP * LISTENER_HEIGHT


# For a player a module keeps itself -- the helicopters', which set their own
# volume as they fly: the stream, or null. Asked again before each play, since
# the mode can change under it. Resolves without a Level3DAudio in the tree.
static func stream(name: String) -> AudioStream:
	return resolve(name).stream


# The gain the stream wants, dB, to add to the caller's own: its "db" or
# "fdb", and the menu's gain for it over that.
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
	var bus_name: StringName = SOUNDS.get(name, {}).get("bus", AudioSettings.SFX_BUS)
	return bus_name if AudioServer.get_bus_index(bus_name) >= 0 else AudioSettings.SFX_BUS


static func set_mode(new_mode: Mode) -> void:
	if new_mode == mode:
		return
	mode = new_mode
	_resolved.clear()
	if _current != null:
		_current._remake()


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


# One of MUSIC's songs, from its start; "" stops the music.
static func play_music(song: String) -> void:
	if _current == null:
		return
	_current._song = MUSIC.get(song, []).duplicate()
	_current._music.stop()
	_current._next_part()


static func stop_music() -> void:
	play_music("")


# The placeholder's variants, else the original's file, else nothing; in
# CLASSIC, the original's or nothing.
static func resolve(name: String) -> Dictionary:
	if _resolved.has(name):
		return _resolved[name]
	var spec: Dictionary = SOUNDS.get(name, {})
	if spec.is_empty():
		push_warning("Level3DAudio: no sound called %s" % name)
	var loop: bool = spec.get("loop", false)
	var variants: Array[AudioStream] = []
	if mode == Mode.MODERN:
		for k in (1 if loop else MAX_VARIANTS):
			var path := "%s%s_%d.ogg" % [DIR, name, k]
			if not FileAccess.file_exists(path):
				break
			var ogg := AudioStreamOggVorbis.load_from_file(path)
			if ogg == null:
				push_warning("Level3DAudio: cannot read %s" % path)
				break
			ogg.loop = loop
			variants.append(ogg)
	var entry := {"stream": null, "db": 0.0, "original": false}
	if not variants.is_empty():
		entry.db = spec.get("db", 0.0)
		entry.stream = variants[0] if loop else _randomizer(variants, spec.get("pitch", 0.0))
	elif spec.has("fallback") and ResourceLoader.exists(ORIGINAL + spec.fallback):
		# The original's own file, as it is: not looped even for a loop, since
		# the original replays it when it runs out, and the modules that loop
		# it do too; and in CLASSIC not pitched, as the game does not.
		var original: AudioStream = load(ORIGINAL + spec.fallback)
		entry.db = spec.get("fdb", 0.0)
		entry.original = true
		var pitch: float = spec.get("pitch", 0.0) if mode == Mode.MODERN else 0.0
		entry.stream = original if loop else _randomizer([original], pitch)
	_resolved[name] = entry
	return entry


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
	var spec: Dictionary = SOUNDS.get(name, {})
	var entry := resolve(name)
	if entry.stream == null or gain(name) <= 0.0:
		return
	var gap: float = spec.get("gap", 0.0)
	if mode == Mode.CLASSIC and not spec.get("always", false):
		gap = maxf(gap, CLASSIC_GAP)
	var now := Time.get_ticks_msec()
	if gap > 0.0 and _last.has(name) and now - int(_last[name]) < int(gap * 1000.0):
		return
	var flat: bool = typeof(at) != TYPE_VECTOR3 or spec.get("flat", false) or mode == Mode.CLASSIC
	var player = _voice(name, flat)
	if player == null:
		return
	_last[name] = now
	if not flat:
		(player as AudioStreamPlayer3D).global_position = at
	player.volume_db = volume_db(name)
	player.play()
	if entry.original and spec.has("with"):
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
	var voices: int = SOUNDS.get(name, {}).get("voices", 1)
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
	player.play()
	return player


func _setup_3d(player: AudioStreamPlayer3D, name: String, entry: Dictionary) -> void:
	player.stream = entry.stream
	player.volume_db = volume_db(name)
	player.bus = bus(name)
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = UNIT_SIZE
	player.max_distance = MAX_DISTANCE
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
	if _song.is_empty():
		return
	var file: String = _song.pop_front()
	var stream: AudioStream = load(MUSIC_DIR + file) if ResourceLoader.exists(MUSIC_DIR + file) else null
	if stream == null:
		push_warning("Level3DAudio: no music %s" % file)
		_song.clear()
		return
	# A copy, as Song.make_player makes one: the loop flag is the copy's.
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = _song.is_empty()
	_music.stream = stream
	_music.play()
