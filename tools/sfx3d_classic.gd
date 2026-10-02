# Makes the 3D preview's original sound folder out of Level3DAudio.SOUNDS,
# and fills in modern's from it (classic's, the 8-bit mode's, is
# tools/sfx_chiptune.py --install's, out of modern's):
#
#   assets/sfx3d/original/<name>_0.ogg  a copy of the sound's "original" in
#       assets/soundeffects/, byte for byte, and nothing for a sound that has
#       none: a file missing is silence. Written every run: it is the base,
#       and the originals are its source.
#   assets/sfx3d/modern/<name>_0.ogg   a copy of the original's, where modern
#       has no <name>_0.ogg yet and the original has one. A file already there -- a new
#       sound -- is never touched, so running this again only fills in a
#       sound added to SOUNDS.
#   assets/music3d/original/<file>     every part of Level3DAudio.MUSIC, a
#       copy of the 2D game's in assets/music/, and modern/<file> a copy of
#       it where modern has none yet and plays it: the same, song for song,
#       but for a song modern plays as Level3DAudio.ADAPTIVE has it, whose
#       clips are its own.
#
#     godot --path . --headless --script tools/sfx3d_classic.gd
#
# Run --headless --import after, for new files to resolve.
extends SceneTree


func _initialize() -> void:
	var classic: String = Level3DAudio.DIRS[Level3DAudio.Mode.ORIGINAL]
	var modern: String = Level3DAudio.DIRS[Level3DAudio.Mode.MODERN]
	for dir in [classic, modern]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var failures := 0
	var silent := 0
	var filled := 0
	for name in Level3DAudio.SOUNDS:
		var spec: Dictionary = Level3DAudio.SOUNDS[name]
		var file := "%s_0.ogg" % name
		if not spec.has("original"):
			# The original had no sound for it: classic has none either.
			if FileAccess.file_exists(classic + file):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(classic + file))
			silent += 1
			continue
		var bytes := FileAccess.get_file_as_bytes(Level3DAudio.ORIGINAL + spec.original)
		if bytes.is_empty():
			printerr("%s: cannot read %s" % [name, spec.original])
			failures += 1
			continue
		var out := FileAccess.open(classic + file, FileAccess.WRITE)
		out.store_buffer(bytes)
		out.close()
		if not FileAccess.file_exists(modern + file):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(classic + file),
					ProjectSettings.globalize_path(modern + file))
			filled += 1
	# The music the same way: classic's a copy of the 2D game's, modern's of
	# classic's where it has none yet.
	var music_classic: String = Level3DAudio.MUSIC_DIRS[Level3DAudio.Mode.ORIGINAL]
	var music_modern: String = Level3DAudio.MUSIC_DIRS[Level3DAudio.Mode.MODERN]
	for dir in [music_classic, music_modern]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var songs := 0
	var songs_filled := 0
	for file in _music_files():
		var bytes := FileAccess.get_file_as_bytes(Level3DAudio.ORIGINAL_MUSIC + file)
		if bytes.is_empty():
			printerr("music: cannot read %s" % file)
			failures += 1
			continue
		var out := FileAccess.open(music_classic + file, FileAccess.WRITE)
		out.store_buffer(bytes)
		out.close()
		songs += 1
		# Not a part modern plays otherwise (the boss's loop, Level3DAudio.ADAPTIVE).
		if Level3DAudio.mode_music_files(Level3DAudio.Mode.MODERN).has(file) \
				and not FileAccess.file_exists(music_modern + file):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(music_classic + file),
					ProjectSettings.globalize_path(music_modern + file))
			songs_filled += 1
	print("original: %d sounds, %d of them silent (no file), %d songs; modern: %d sounds and %d songs filled in%s" % [
			Level3DAudio.SOUNDS.size(), silent, songs, filled, songs_filled,
			"" if failures == 0 else "; %d FAILED" % failures])
	quit(1 if failures > 0 else 0)


# Every part of every song of Level3DAudio.MUSIC, once each.
static func _music_files() -> Array:
	var files := []
	for song in Level3DAudio.MUSIC:
		for file in Level3DAudio.MUSIC[song]:
			if not files.has(file):
				files.append(file)
	return files
