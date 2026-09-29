# Checks the 3D preview's sound (src/tools/level3d_audio.gd) in both of its
# modes. Each mode's folder, assets/sfx3d/classic/ and modern/, must hold
# <name>_0.ogg for every sound in Level3DAudio.SOUNDS and nothing that is not
# one; classic's must be what tools/sfx3d_classic.gd made, the sound's
# "original" byte for byte or the silence, and _0 alone. Every sound is then
# resolved, played positional and flat, and, if it loops, hung on a node and
# taken off again; the table says what each one got -- the original's, the
# silence, or new (a modern file that is no longer classic's). Then the mode
# is switched with a loop hung, and every song of MUSIC is started.
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
	for song in Level3DAudio.MUSIC:
		Level3DAudio.play_music(song)
		await process_frame
		if not audio._music.playing:
			failures += _fail("music %s does not play" % song)
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
	var counts := {"original": 0, "silence": 0, "new": 0, "missing": 0}
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
	# The silence: every classic file of a sound without an original is one
	# and the same file.
	var silence := PackedByteArray()
	for name in Level3DAudio.SOUNDS:
		var spec := Level3DAudio.spec_of(name)
		var path := "%s%s_0.ogg" % [dir, name]
		var kind := "missing"
		if FileAccess.file_exists(path):
			var bytes := FileAccess.get_file_as_bytes(path)
			var base := FileAccess.get_file_as_bytes("%s%s_0.ogg" % [classic_dir, name])
			if spec.has("original") and bytes == base:
				kind = "original"
			elif not spec.has("original") and bytes == base:
				kind = "silence"
			else:
				kind = "new"
			if classic:
				if spec.has("original") and bytes != FileAccess.get_file_as_bytes(Level3DAudio.ORIGINAL + spec.original):
					failures += _fail("%s: not a copy of %s" % [name, spec.original])
				if not spec.has("original"):
					if silence.is_empty():
						silence = bytes
					elif bytes != silence:
						failures += _fail("%s: has no original, and is not the silence" % name)
		else:
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
	print("original %d, silence %d, new %d, missing %d of %d%s" % [counts.original, counts.silence,
			counts.new, counts.missing, Level3DAudio.SOUNDS.size(), "" if failures == 0 else ", %d FAILED" % failures])
	return failures


func _fail(message: String) -> int:
	printerr(message)
	return 1
