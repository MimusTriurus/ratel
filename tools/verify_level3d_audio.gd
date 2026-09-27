# Checks the 3D preview's sound (src/tools/level3d_audio.gd) in both of its
# modes, with the War Thunder placeholders in assets/sfx_wt/ or without them.
# Every sound in Level3DAudio.SOUNDS is resolved, played positional and flat,
# and, if it loops, hung on a node and taken off again; the table says what
# each one got -- wt, the original's effect, or silent. Then the mode is
# switched with a loop hung, and every song of MUSIC is started.
#
#     godot --path . --headless --script tools/verify_level3d_audio.gd
#
# In the classic mode, and in the modern one without the placeholders, every
# sound with a "fallback" must come out as the original's and the rest silent,
# which is the preview on a fresh clone; with them, a loop must loop. Exits 1
# on anything else.
extends SceneTree


func _initialize() -> void:
	var audio := Level3DAudio.new()
	root.add_child(audio)
	await process_frame
	var failures := 0
	for mode in [Level3DAudio.Mode.MODERN, Level3DAudio.Mode.CLASSIC]:
		Level3DAudio.set_mode(mode)
		failures += await _check_mode()
	# A loop on a unit through a change of mode: taken off in CLASSIC (the
	# engines have no original), put back in MODERN if there is one to play.
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
	var have_wt := DirAccess.dir_exists_absolute(Level3DAudio.DIR) and not classic
	print("--- %s" % ("classic" if classic else "modern"))
	var counts := {"wt": 0, "original": 0, "silent": 0}
	var failures := 0
	for name in Level3DAudio.SOUNDS:
		var spec: Dictionary = Level3DAudio.SOUNDS[name]
		var entry := Level3DAudio.resolve(name)
		var kind := "silent"
		var variants := 0
		if entry.stream != null:
			var first: AudioStream = entry.stream
			variants = 1
			if first is AudioStreamRandomizer:
				variants = (first as AudioStreamRandomizer).streams_count
				first = (first as AudioStreamRandomizer).get_stream(0)
			kind = "original" if first.resource_path.begins_with(Level3DAudio.ORIGINAL) else "wt"
			if kind == "wt" and spec.get("loop", false) and not (first as AudioStreamOggVorbis).loop:
				failures += _fail("%s is a loop that does not loop" % name)
		if not have_wt and kind != ("original" if spec.has("fallback") else "silent"):
			failures += _fail("%s: %s without the placeholders" % [name, kind])
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
	print("%s: wt %d, original %d, silent %d of %d%s" % [
			"placeholders" if have_wt else "no placeholders", counts.wt, counts.original,
			counts.silent, Level3DAudio.SOUNDS.size(), "" if failures == 0 else ", %d FAILED" % failures])
	return failures


func _fail(message: String) -> int:
	printerr(message)
	return 1
