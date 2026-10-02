# Checks the 3D preview's sound (src/tools/level3d_audio.gd) in both of its
# modes, and the 8-bit sounds that fill in the classic one's gaps
# (assets/sfx3d/chip/). Each mode's folder, assets/sfx3d/classic/ and
# modern/, holds nothing that is no sound's in Level3DAudio.SOUNDS; classic's must be what
# tools/sfx3d_classic.gd made, <name>_0.ogg alone, the sound's "original"
# byte for byte, and nothing for a sound with none. A sound with no file is
# silent, in either mode, and not wrong. Every sound is then resolved,
# played positional and flat, and, if it loops, hung on a node and taken off
# again; the table says what each one got -- the original's, new (a modern
# file that is no longer classic's), or missing, silent. Then the mode
# is switched with a loop hung. The music's folders, assets/music3d/classic/
# and modern/, must hold every file the mode plays and nothing else, classic's
# the 2D game's byte for byte; every song is started in both modes, and one is
# carried over a change of mode. The boss's song, which in modern follows the
# fight (ADAPTIVE), is checked part by part, through a layer, an accent and a
# change of mode.
#
#     godot --path . --headless --script tools/verify_level3d_audio.gd
#
# Exits 1 on anything wrong.
extends SceneTree


func _initialize() -> void:
	var audio := Level3DAudio.new()
	root.add_child(audio)
	await process_frame
	var failures := 0
	for mode in [Level3DAudio.Mode.MODERN, Level3DAudio.Mode.CLASSIC]:
		Level3DAudio.set_mode(mode)
		failures += await _check_mode()
	failures += await _check_chip()
	# A loop on a unit through a change of mode: put back on it in the new
	# mode, if the new mode has something to play.
	var unit := Node3D.new()
	root.add_child(unit)
	Level3DAudio.attach_loop("tank_engine", unit)
	Level3DAudio.set_mode(Level3DAudio.Mode.MODERN)
	await process_frame
	var modern_has := Level3DAudio.resolve("tank_engine").stream != null
	if (Level3DAudio.loop_on(unit, "tank_engine") != null) != modern_has:
		failures += _fail("tank_engine: not put back after the change of mode")
	failures += _check_mix()
	# A gain moved: heard at once, the mix changed, and put back unchanged.
	var was := Level3DAudio.mix_db("gun")
	Level3DAudio.set_mix_db("gun", was - 6.0)
	if not is_equal_approx(Level3DAudio.volume_db("gun"), was - 6.0 + linear_to_db(Level3DAudio.gain("gun"))) \
			or not Level3DAudio.is_mix_changed():
		failures += _fail("the mix's gun at -6 dB is not what plays")
	Level3DAudio.reload_mix()
	if Level3DAudio.is_mix_changed() or not is_equal_approx(Level3DAudio.mix_db("gun"), was):
		failures += _fail("reload_mix did not give the file's mix back")
	for mode in [Level3DAudio.Mode.MODERN, Level3DAudio.Mode.CLASSIC]:
		Level3DAudio.set_mode(mode)
		failures += _check_music_files()
		for song in Level3DAudio.MUSIC:
			Level3DAudio.play_music(song)
			await process_frame
			if not audio._music.playing:
				failures += _fail("music %s does not play" % song)
	# The music through a change of mode: the same part, from the other folder.
	Level3DAudio.play_music("stage")
	await process_frame
	var part: String = audio._part
	Level3DAudio.set_mode(Level3DAudio.Mode.MODERN)
	await process_frame
	if not audio._music.playing or audio._part != part:
		failures += _fail("music: %s not carried over the change of mode (%s)" % [part, audio._part])
	failures += await _check_chain(audio)
	failures += await _check_adaptive(audio)
	Level3DAudio.stop_music()
	# The menu's per-sound gains: a slider for every sound but enemy_hit, a
	# gain in dB over the sound's own, silence at 0, none in CLASSIC.
	var listed := {}
	for group in Level3DMenu.SOUND_GROUPS:
		for pair in group[1]:
			listed[pair[0]] = true
	for name in Level3DAudio.SOUNDS:
		if name != "enemy_hit" and not listed.has(name):
			failures += _fail("%s has no slider in the Sound tab" % name)
	for name in listed:
		if not Level3DAudio.SOUNDS.has(name):
			failures += _fail("the Sound tab has a slider for %s, which is no sound" % name)
	var plain := Level3DAudio.volume_db("gun")
	Level3DAudio.set_gains({"gun": 0.5, "hit_armor": 0.0})
	if not is_equal_approx(Level3DAudio.volume_db("gun"), plain + linear_to_db(0.5)):
		failures += _fail("gun at 50 %%: %.2f dB, not %.2f" % [Level3DAudio.volume_db("gun"), plain + linear_to_db(0.5)])
	var voices := audio.get_child_count()
	audio._last.erase("hit_armor")
	Level3DAudio.play("hit_armor")
	if audio.get_child_count() != voices and audio._pools.get("hit_armor/flat", []).any(func(p): return p.playing):
		failures += _fail("hit_armor at 0 % still plays")
	Level3DAudio.set_mode(Level3DAudio.Mode.CLASSIC)
	if not is_equal_approx(Level3DAudio.gain("gun"), 1.0):
		failures += _fail("a gain applied in the classic mode")
	Level3DAudio.set_mode(Level3DAudio.Mode.MODERN)
	Level3DAudio.set_gains({})
	Level3DAudio.set_volumes(1.0, 0.5, 1.0, 0.3, false)
	if not AudioServer.is_bus_mute(AudioServer.get_bus_index(Level3DAudio.ENEMY_FIRE_BUS)):
		failures += _fail("the enemies' fire switched off but not muted")
	print("%s" % ("all good" if failures == 0 else "%d FAILED" % failures))
	# Out of the tree first, which empties Level3DAudio's static cache, and a
	# few frames for the audio server to let go of what was still playing:
	# quit alone reports both as leaked.
	unit.free()
	audio.free()
	for i in 10:
		await process_frame
	quit(1 if failures > 0 else 0)


func _check_mode() -> int:
	var classic := Level3DAudio.mode == Level3DAudio.Mode.CLASSIC
	var dir: String = Level3DAudio.DIRS[Level3DAudio.mode]
	var classic_dir: String = Level3DAudio.DIRS[Level3DAudio.Mode.CLASSIC]
	print("--- %s, %s" % ["classic" if classic else "modern", dir])
	var counts := {"original": 0, "new": 0, "missing": 0}
	var failures := 0
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() != "ogg":
			continue
		var base := file.get_basename()
		var name := base.left(base.rfind("_"))
		if not Level3DAudio.SOUNDS.has(name) or not base.substr(base.rfind("_") + 1).is_valid_int():
			failures += _fail("%s%s is no sound's" % [dir, file])
		elif classic and not base.ends_with("_0"):
			failures += _fail("%s%s: classic has one of each" % [dir, file])
	for name in Level3DAudio.SOUNDS:
		var spec := Level3DAudio.spec_of(name)
		var path := "%s%s_0.ogg" % [dir, name]
		var kind := "missing"
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			var base := FileAccess.get_file_as_bytes("%s%s_0.ogg" % [classic_dir, name])
			kind = "original" if spec.has("original") and bytes == base else "new"
			if classic:
				if not spec.has("original"):
					failures += _fail("%s: the original had no sound for it, and classic has one" % path)
				elif bytes != FileAccess.get_file_as_bytes(Level3DAudio.ORIGINAL + spec.original):
					failures += _fail("%s: not a copy of %s" % [name, spec.original])
		elif classic and spec.has("original"):
			failures += _fail("%s is missing" % path)
		var entry := Level3DAudio.resolve(name)
		var variants := 0
		if entry.stream != null:
			var first: AudioStream = entry.stream
			variants = 1
			if first is AudioStreamRandomizer:
				variants = (first as AudioStreamRandomizer).streams_count
				first = (first as AudioStreamRandomizer).get_stream(0)
			var looped: bool = first is AudioStreamOggVorbis and (first as AudioStreamOggVorbis).loop
			if looped != (spec.get("loop", false) and not classic):
				failures += _fail("%s: looped %s in %s" % [name, looped, "classic" if classic else "modern"])
		elif kind != "missing":
			failures += _fail("%s: a file, and nothing to play" % name)
		counts[kind] += 1
		print("%-16s %-8s %2d  %-10s %6.1f dB" % [name, kind, variants, Level3DAudio.bus(name), entry.db])
		Level3DAudio.play(name, Vector3(3.0, 0.0, -2.0))
		Level3DAudio.play(name)
		if spec.get("loop", false):
			var holder := Node3D.new()
			root.add_child(holder)
			var loop := Level3DAudio.attach_loop(name, holder)
			if (loop != null) != (entry.stream != null):
				failures += _fail("%s: attach_loop and resolve disagree" % name)
			Level3DAudio.stop_loop(holder, name)
			holder.queue_free()
	Level3DAudio.listen(Vector3(1.0, 0.0, 1.0))
	for i in 30:
		await process_frame
	print("original %d, new %d, missing (silent) %d of %d%s" % [counts.original,
			counts.new, counts.missing, Level3DAudio.SOUNDS.size(), "" if failures == 0 else ", %d FAILED" % failures])
	return failures


# The classic mode's gaps, filled in (Level3DAudio.set_chip): CHIP_DIR holds
# a <name>_0.ogg for every sound the original had none for, and nothing for
# one it had. With the switch on, classic plays each of those from it --
# looped where the sound loops, which classic's own never are -- and its own
# file for the rest; off, they are silent again; and modern never takes one.
func _check_chip() -> int:
	var failures := 0
	var dir := Level3DAudio.CHIP_DIR
	print("--- chip, %s" % dir)
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() != "ogg":
			continue
		var name := file.get_basename().trim_suffix("_0")
		if not file.ends_with("_0.ogg") or not Level3DAudio.SOUNDS.has(name):
			failures += _fail("%s%s is no sound's" % [dir, file])
		elif Level3DAudio.SOUNDS[name].has("original"):
			failures += _fail("%s%s: the original has a sound for it" % [dir, file])
	var gaps := 0
	Level3DAudio.set_mode(Level3DAudio.Mode.CLASSIC)
	Level3DAudio.set_chip(true)
	for name in Level3DAudio.SOUNDS:
		var spec := Level3DAudio.spec_of(name)
		var gap := not spec.has("original")
		var entry := Level3DAudio.resolve(name)
		if gap:
			gaps += 1
			if not FileAccess.file_exists("%s%s_0.ogg" % [dir, name]):
				failures += _fail("%s: a gap in classic, and no %s%s_0.ogg" % [name, dir, name])
				continue
		if entry.stream == null or entry.chip != gap:
			failures += _fail("%s: classic with the 8-bit switch on plays %s" % [name,
					"nothing" if entry.stream == null else "chip/" if entry.chip else "classic/"])
			continue
		var looped: bool = entry.stream is AudioStreamOggVorbis and (entry.stream as AudioStreamOggVorbis).loop
		if looped != (gap and spec.get("loop", false)):
			failures += _fail("%s: looped %s with the 8-bit switch on" % [name, looped])
		Level3DAudio.play(name)
		if spec.get("loop", false):
			var holder := Node3D.new()
			root.add_child(holder)
			if Level3DAudio.attach_loop(name, holder) == null:
				failures += _fail("%s: nothing hung on its unit with the 8-bit switch on" % name)
			Level3DAudio.stop_loop(holder, name)
			holder.queue_free()
	Level3DAudio.set_chip(false)
	for name in Level3DAudio.SOUNDS:
		if not Level3DAudio.SOUNDS[name].has("original") and Level3DAudio.resolve(name).stream != null:
			failures += _fail("%s: plays in classic with the 8-bit switch off" % name)
	Level3DAudio.set_mode(Level3DAudio.Mode.MODERN)
	Level3DAudio.set_chip(true)
	for name in Level3DAudio.SOUNDS:
		if Level3DAudio.resolve(name).chip:
			failures += _fail("%s: modern plays the 8-bit sound" % name)
	Level3DAudio.set_chip(false)
	for i in 10:
		await process_frame
	print("an 8-bit sound for each of classic's %d gaps%s" % [gaps, "" if failures == 0 else ", %d FAILED" % failures])
	return failures


# The mix: a gain for every sound of SOUNDS and every part of MUSIC in both
# modes and nothing else, and the file as save_mix would write it, so that a
# save with nothing moved leaves no diff.
func _check_mix() -> int:
	var failures := 0
	var text := FileAccess.get_file_as_string(Level3DAudio.MIX_PATH)
	var mix = JSON.parse_string(text)
	if typeof(mix) != TYPE_DICTIONARY:
		return _fail("%s: not a JSON object" % Level3DAudio.MIX_PATH)
	for key in mix:
		if not Level3DAudio.MODE_KEYS.values().has(key):
			failures += _fail("mix: %s is no mode" % key)
	var wants := {"sounds": Level3DAudio.SOUNDS.keys(), "music": Level3DAudio.music_files()}
	for key in Level3DAudio.MODE_KEYS.values():
		for kind in wants:
			var have: Dictionary = mix.get(key, {}).get(kind, {})
			for name in wants[kind]:
				if not have.has(name):
					failures += _fail("mix: %s has no %s %s" % [key, kind, name])
			for name in have:
				if not wants[kind].has(name):
					failures += _fail("mix: %s %s %s is none of the game's" % [key, kind, name])
	if Level3DAudio.serialize_mix(mix) != text:
		failures += _fail("mix: %s is not laid out as save_mix writes it" % Level3DAudio.MIX_PATH)
	print("mix: %d sounds and %d music parts a mode" % [wants.sounds.size(), wants.music.size()])
	return failures


# A song of several parts, in both modes: one AudioStreamInteractive of them
# all, each running on into the next and the last looped, so that no part
# waits for the one before's `finished`; and through a change of mode, the
# same part with the same parts to come.
func _check_chain(audio: Level3DAudio) -> int:
	var failures := 0
	for mode in [Level3DAudio.Mode.MODERN, Level3DAudio.Mode.CLASSIC]:
		Level3DAudio.set_mode(mode)
		Level3DAudio.play_music("intro")
		await process_frame
		var files: Array = Level3DAudio.MUSIC["intro"]
		var stream := audio._music.stream as AudioStreamInteractive
		if stream == null or stream.clip_count != files.size():
			failures += _fail("intro in %s: not one stream of its %d parts" % [mode, files.size()])
			continue
		for i in files.size():
			var last := i == files.size() - 1
			var ogg := stream.get_clip_stream(i) as AudioStreamOggVorbis
			if stream.get_clip_name(i) != StringName(files[i]) or ogg == null or ogg.loop != last:
				failures += _fail("intro in %s: clip %d is not %s%s" % [mode, i, files[i], ", looped" if last else ""])
			elif not last and (stream.get_clip_auto_advance(i) != AudioStreamInteractive.AUTO_ADVANCE_ENABLED
					or stream.get_clip_auto_advance_next_clip(i) != i + 1):
				failures += _fail("intro in %s: %s does not run on into the next part" % [mode, files[i]])
		if audio._part != files[0] or audio._parts_to_come() != files.slice(1):
			failures += _fail("intro in %s: at %s, %s to come" % [mode, audio._part, audio._parts_to_come()])
	# A change of mode in the chain: its part alone, the rest still to come.
	Level3DAudio.set_mode(Level3DAudio.Mode.MODERN)
	await process_frame
	if not audio._music.playing or audio._part != "start.ogg" or audio._song != ["stage0_intro.ogg", "stage0_repeat.ogg"]:
		failures += _fail("intro: not carried over the change of mode (%s, then %s)" % [audio._part, audio._song])
	Level3DAudio.stop_music()
	return failures


# The songs that follow the fight (Level3DAudio.ADAPTIVE), in modern: one
# AudioStreamInteractive of the intro, the loop and the end -- the intro and
# every part of the loop a whole number of bars, the loop's parts looped and
# all as long as each other, so that they stay together -- with the layers
# silent until an enemy is on the field, then on, and the accent played.
# Then in classic: the classic song, and the end its stop.
func _check_adaptive(audio: Level3DAudio) -> int:
	var failures := 0
	for song in Level3DAudio.ADAPTIVE:
		var spec: Dictionary = Level3DAudio.ADAPTIVE[song]
		var bar := int(spec.bar_beats)
		Level3DAudio.set_mode(Level3DAudio.Mode.MODERN)
		Level3DAudio.play_music(song)
		await process_frame
		var stream := audio._music.stream as AudioStreamInteractive
		if stream == null or stream.clip_count != 3:
			failures += _fail("%s: not an AudioStreamInteractive of an intro, a loop and an end" % song)
			continue
		var intro := stream.get_clip_stream(Level3DAudio.CLIP_INTRO) as AudioStreamOggVorbis
		if intro == null or intro.loop or intro.beat_count == 0 or intro.beat_count % bar != 0:
			failures += _fail("%s: %s is not a clip of whole bars" % [song, spec.intro])
		var sync := stream.get_clip_stream(Level3DAudio.CLIP_LOOP) as AudioStreamSynchronized
		var parts: Array = [spec.lead] + spec.layers
		if sync == null or sync.stream_count != parts.size():
			failures += _fail("%s: its loop is not the lead and %d layers" % [song, spec.layers.size()])
			continue
		var beats := -1
		for i in parts.size():
			var part := sync.get_sync_stream(i) as AudioStreamOggVorbis
			if part == null or not part.loop or part.beat_count == 0 or part.beat_count % bar != 0 					or (beats >= 0 and part.beat_count != beats):
				failures += _fail("%s: %s is not a loop of whole bars as long as the lead" % [song, parts[i]])
			elif beats < 0:
				beats = part.beat_count
		if sync.get_sync_stream_volume(1) > Level3DAudio.SILENT_DB:
			failures += _fail("%s: a layer is heard with no enemy on the field" % song)
		var on := []
		on.resize(spec.layers.size())
		on.fill(false)
		on[0] = true
		Level3DAudio.music_layers(on)
		if audio._layers_on != on or audio._layer_from[0] < audio._beat_zero:
			failures += _fail("%s: the first layer is not on its way in" % song)
		if spec.has("accent"):
			Level3DAudio.music_accent()
			await process_frame
			if audio._accent == null or not audio._accent.playing:
				failures += _fail("%s: the accent does not play" % song)
		# Linearly: the same, the loop the one file of them all, as long as the
		# lead; and back, the layers again.
		Level3DAudio.set_adaptive(false)
		await process_frame
		stream = audio._music.stream as AudioStreamInteractive
		var full := stream.get_clip_stream(Level3DAudio.CLIP_LOOP) as AudioStreamOggVorbis if stream != null else null
		if full == null or not full.loop or full.beat_count != beats or audio._sync != null:
			failures += _fail("%s: played linearly, its loop is not %s, a loop as long as the lead" % [song, spec.full])
		Level3DAudio.set_adaptive(true)
		await process_frame
		stream = audio._music.stream as AudioStreamInteractive
		if stream == null or not stream.get_clip_stream(Level3DAudio.CLIP_LOOP) is AudioStreamSynchronized:
			failures += _fail("%s: not layered again after linear" % song)
		Level3DAudio.set_mode(Level3DAudio.Mode.CLASSIC)
		await process_frame
		if not audio._music.playing or not Level3DAudio.MUSIC[song].has(audio._part):
			failures += _fail("%s: in classic not its own song (%s)" % [song, audio._part])
		Level3DAudio.music_end()
		if audio._music.playing:
			failures += _fail("%s: in classic the end does not stop it" % song)
		print("adaptive %s: an intro, a loop of the lead and %d layers of %d bars, an end" % [
				song, spec.layers.size(), beats / bar])
	# The checks after this one are the modern mode's, as before it.
	Level3DAudio.set_mode(Level3DAudio.Mode.MODERN)
	return failures


# The mode's music folder: every file the mode plays and nothing else --
# MUSIC's parts, and in modern ADAPTIVE's clips in place of a song's it has --
# classic's a copy of the 2D game's.
func _check_music_files() -> int:
	var classic := Level3DAudio.mode == Level3DAudio.Mode.CLASSIC
	var dir: String = Level3DAudio.MUSIC_DIRS[Level3DAudio.mode]
	var classic_dir: String = Level3DAudio.MUSIC_DIRS[Level3DAudio.Mode.CLASSIC]
	var parts := {}
	for file in Level3DAudio.mode_music_files():
		parts[file] = true
	var failures := 0
	for file in DirAccess.get_files_at(dir):
		if file.get_extension() == "ogg" and not parts.has(file):
			failures += _fail("%s%s is no song's" % [dir, file])
	var counts := {"original": 0, "new": 0}
	for file in parts:
		if not FileAccess.file_exists(dir + file):
			failures += _fail("%s%s is missing" % [dir, file])
			continue
		var bytes := FileAccess.get_file_as_bytes(dir + file)
		if classic and bytes != FileAccess.get_file_as_bytes(Level3DAudio.ORIGINAL_MUSIC + file):
			failures += _fail("%s: not a copy of %s%s" % [file, Level3DAudio.ORIGINAL_MUSIC, file])
		counts["original" if bytes == FileAccess.get_file_as_bytes(classic_dir + file) else "new"] += 1
	print("music, %s: original %d, new %d of %d" % [dir, counts.original, counts.new, parts.size()])
	return failures


func _fail(message: String) -> int:
	printerr(message)
	return 1
