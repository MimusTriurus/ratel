# Loads every stage and writes it straight back out, unmodified.
#
#     godot --path . --headless --script tools/verify_json_roundtrip.gd
#     git diff --exit-code assets/maps
#
# A clean diff means MapIO.serialize agrees with tools/map_json.py down to the
# byte, which is what keeps an edit to one tile from rewriting the whole file.
#
# The backdrop block is checked here too, in memory rather than on disk: it is
# optional, and a stage that has never been baked has to come out byte for byte
# without it.
extends SceneTree

var failures := 0


func _init() -> void:
	var sizes := MapIO.load_trigger_sizes()
	for index in 6:
		var stage := Stage.new()
		var doc := MapIO.read_document(index)
		MapIO.load_stage(index, stage, sizes)
		var error := MapIO.save_stage(index, stage, doc)
		print("  stage %d: %s" % [index, "written" if error == OK else "FAILED"])

	print("")
	_check_background(sizes)

	if failures == 0:
		print("\nnow check: git diff --exit-code assets/maps")
		quit(0)
	else:
		print("\n%d backdrop check(s) FAILED" % failures)
		quit(1)


func _check_background(sizes: Array) -> void:
	var stage := Stage.new()
	var doc := MapIO.read_document(0)
	MapIO.load_stage(0, stage, sizes)

	_check("stage 0 carries a backdrop", doc.has("background"))
	_check("chunk height parsed", stage.background_chunk_height == 2048)
	_check("chunk rows derived", MapIO.background_chunk_rows(stage) == 64)
	# 360 rows over 64 a chunk: five full chunks and 40 rows left over.
	_check("chunk count derived", MapIO.background_chunk_count(stage) == 6)

	var missing := PackedStringArray()
	for stage_index in 6:
		var s := Stage.new()
		MapIO.load_stage(stage_index, s, sizes)
		for k in MapIO.background_chunk_count(s):
			var path := MapIO.background_chunk_path(stage_index, k)
			if not ResourceLoader.exists(path):
				missing.append(path)
	_check("every chunk a stage names exists", missing.is_empty())
	for path in missing:
		print("      missing %s" % path)

	# Both modes write the block; the mode is the only thing that differs.
	var mode := stage.background_mode
	stage.background_mode = MapIO.BACKGROUND_IMAGE
	var image_text := MapIO.serialize(0, stage, doc)
	_check("image mode written", image_text.contains(
		'  "background": {"mode": "image", "chunk_height": 2048},'))
	stage.background_mode = mode
	_check("tiles mode written", MapIO.serialize(0, stage, doc).contains(
		'  "background": {"mode": "tiles", "chunk_height": 2048},'))

	# A stage with no backdrop must come out exactly as it would have before the
	# block existed -- the same text minus that one line.
	var on_disk := FileAccess.get_file_as_string("res://assets/maps/stage-0.json")
	var line := '  "background": {"mode": "tiles", "chunk_height": 2048},\n'
	var bare := Stage.new()
	MapIO.load_stage(0, bare, sizes)
	bare.background_mode = MapIO.BACKGROUND_TILES
	bare.background_chunk_height = 0
	var source := doc.duplicate()
	source.erase("background")
	_check("an unbaked stage writes no backdrop block",
		MapIO.serialize(0, bare, source) == on_disk.replace(line, ""))


func _check(what: String, ok: bool) -> void:
	print("  %s: %s" % [what, "ok" if ok else "FAILED"])
	if not ok:
		failures += 1
