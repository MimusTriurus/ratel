# How loud a sound file is: its peak and its loudest 50 ms (RMS), both dBFS,
# played at 0 dB into an AudioEffectCapture. What Level3DAudio.SOUNDS' "db"
# were set from: a placeholder swapped for another wants measuring again.
#
#     godot --path . --headless --script tools/measure_loudness.gd -- res://assets/sfx_wt/gun_0.ogg ...
#
# A path under assets/sfx_wt/ is read off the disk, as Level3DAudio reads it
# (the folder is never imported); anything else through the importer. Plays
# each in real time, so a long list takes as long as the files do (at most
# four seconds each).
extends SceneTree


func _initialize() -> void:
	root.add_child(Measure.new())


class Measure extends Node:
	const WINDOW := 0.05
	const LONGEST := 4.0

	var _capture: AudioEffectCapture
	var _player: AudioStreamPlayer

	func _ready() -> void:
		var bus := AudioServer.bus_count
		AudioServer.add_bus(bus)
		AudioServer.set_bus_name(bus, "Measure")
		_capture = AudioEffectCapture.new()
		_capture.buffer_length = LONGEST + 1.0
		AudioServer.add_bus_effect(bus, _capture)
		_player = AudioStreamPlayer.new()
		_player.bus = "Measure"
		add_child(_player)
		for path in OS.get_cmdline_user_args():
			var stream: AudioStream = AudioStreamOggVorbis.load_from_file(path) \
					if path.begins_with(Level3DAudio.DIR) else load(path)
			if stream == null:
				printerr("cannot read %s" % path)
				continue
			var loudness := await _measure(stream)
			print("%-48s peak %6.1f  rms %6.1f  %5.2f s" % [path.get_file(), loudness.x, loudness.y,
					stream.get_length()])
		get_tree().quit()

	# (peak, loudest WINDOW's RMS), dBFS.
	func _measure(stream: AudioStream) -> Vector2:
		_capture.clear_buffer()
		_player.stream = stream
		_player.play()
		var frames := PackedVector2Array()
		var length := clampf(stream.get_length(), 0.2, LONGEST)
		var start := Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < int(length * 1000.0) + 150:
			await get_tree().process_frame
			var available := _capture.get_frames_available()
			if available > 0:
				frames.append_array(_capture.get_buffer(available))
		_player.stop()
		await get_tree().create_timer(0.05).timeout
		var window := int(AudioServer.get_mix_rate() * WINDOW)
		var peak := 0.0
		var sum := 0.0
		var loudest := 0.0
		for i in frames.size():
			var f := frames[i]
			peak = maxf(peak, maxf(absf(f.x), absf(f.y)))
			sum += (f.x * f.x + f.y * f.y) * 0.5
			if i >= window:
				var old := frames[i - window]
				sum -= (old.x * old.x + old.y * old.y) * 0.5
			if i >= window - 1:
				loudest = maxf(loudest, sum / window)
		return Vector2(linear_to_db(peak), linear_to_db(sqrt(maxf(loudest, 1e-12))))
