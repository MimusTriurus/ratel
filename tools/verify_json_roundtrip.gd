# Loads every stage and writes it straight back out, unmodified.
#
#     godot --path . --headless --script tools/verify_json_roundtrip.gd
#     git diff --exit-code assets/maps
#
# A clean diff means MapIO.serialize agrees with tools/map_json.py down to the
# byte, which is what keeps an edit to one tile from rewriting the whole file.
extends SceneTree


func _init() -> void:
	var sizes := MapIO.load_trigger_sizes()
	for index in 6:
		var stage := Stage.new()
		var doc := MapIO.read_document(index)
		MapIO.load_stage(index, stage, sizes)
		var error := MapIO.save_stage(index, stage, doc)
		print("  stage %d: %s" % [index, "written" if error == OK else "FAILED"])
	print("\nnow check: git diff --exit-code assets/maps")
	quit(0)
