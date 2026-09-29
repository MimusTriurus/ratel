# Makes the 3D preview's two sound folders out of Level3DAudio.SOUNDS:
#
#   assets/sfx3d/classic/<name>_0.ogg  a copy of the sound's "original" in
#       assets/soundeffects/, byte for byte, or SILENCE where it has none.
#       Written every run: it is the base, and the originals are its source.
#   assets/sfx3d/modern/<name>_0.ogg   a copy of classic's, where modern has
#       no <name>_0.ogg yet. A file already there -- a new sound -- is never
#       touched, so running this again only fills in a sound added to SOUNDS.
#
#     godot --path . --headless --script tools/sfx3d_classic.gd
#
# The silence is SoX's (on PATH): half a second, mono, 44.1 kHz. Run
# --headless --import after, for new files to resolve.
extends SceneTree

const SILENCE_SECONDS := "0.5"


func _initialize() -> void:
	var classic: String = Level3DAudio.DIRS[Level3DAudio.Mode.CLASSIC]
	var modern: String = Level3DAudio.DIRS[Level3DAudio.Mode.MODERN]
	for dir in [classic, modern]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	# Encoded once and copied: each encoding has a stream serial of its own,
	# and the verify script holds every silence to be the same file. The one
	# classic already has is kept, so that a run for a new sound changes no
	# other file.
	var silence := PackedByteArray()
	for name in Level3DAudio.SOUNDS:
		if not Level3DAudio.SOUNDS[name].has("original") and FileAccess.file_exists(classic + "%s_0.ogg" % name):
			silence = FileAccess.get_file_as_bytes(classic + "%s_0.ogg" % name)
			break
	if silence.is_empty():
		var silence_path := OS.get_temp_dir().path_join("sfx3d_silence.ogg")
		var output := []
		if OS.execute("sox", ["-n", "-r", "44100", "-c", "1", "-C", "0", silence_path,
				"trim", "0", SILENCE_SECONDS], output, true) != 0:
			printerr("sox failed: %s" % "".join(output))
			quit(1)
			return
		silence = FileAccess.get_file_as_bytes(silence_path)
		DirAccess.remove_absolute(silence_path)
	var failures := 0
	var silent := 0
	var filled := 0
	for name in Level3DAudio.SOUNDS:
		var spec: Dictionary = Level3DAudio.SOUNDS[name]
		var file := "%s_0.ogg" % name
		var bytes := silence
		if spec.has("original"):
			bytes = FileAccess.get_file_as_bytes(Level3DAudio.ORIGINAL + spec.original)
			if bytes.is_empty():
				printerr("%s: cannot read %s" % [name, spec.original])
				failures += 1
				continue
		else:
			silent += 1
		var out := FileAccess.open(classic + file, FileAccess.WRITE)
		out.store_buffer(bytes)
		out.close()
		if not FileAccess.file_exists(modern + file):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(classic + file),
					ProjectSettings.globalize_path(modern + file))
			filled += 1
	print("classic: %d sounds, %d of them silence; modern: %d filled in from classic%s" % [
			Level3DAudio.SOUNDS.size(), silent, filled, "" if failures == 0 else "; %d FAILED" % failures])
	quit(1 if failures > 0 else 0)
