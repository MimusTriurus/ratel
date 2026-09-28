# Puts stage 1's walls, bridge and gate into its level file, off what
# tools/blender/extract_structures.py read from the hand-built base:
#
#     blender-launcher -b resources/3d/jackal_stage1_lowpoly.blend --python tools/blender/extract_structures.py -- build/level3d/structures.json
#     godot --path . --headless --script tools/level_structures_from_base.gd
#
# "walls" and "bridges" are written whole; the gate is an object, Gate, tied
# to the level's GATE entity as a bunker is to its gun. Run again after the
# base's walls, bridge or gate frame change; nothing else in the file moves.
extends SceneTree

const STRUCTURES := "res://build/level3d/structures.json"


func _init() -> void:
	var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(STRUCTURES))
	if typeof(read) != TYPE_DICTIONARY or read.has("error"):
		push_error("Cannot read %s: %s" % [STRUCTURES, read.get("error", "") if read is Dictionary else ""])
		quit(1)
		return
	var found: Dictionary = read
	var doc := Level3DIO.read(Level3DMap.STAGE)
	doc["walls"] = found["walls"]
	doc["bridges"] = found["bridges"]
	var gate: Dictionary = found["gate"]
	for e in doc["entities"]:
		if e["type"] == "GATE":
			gate["entity"] = e["id"]
	var objects: Array = (doc["objects"] as Array).filter(func(o): return o["asset"] != "Gate")
	objects.append(gate)
	doc["objects"] = objects
	var error := Level3DIO.save(doc)
	print("stage 0: %d walls, %d bridges, the gate at %s for %s -- %s" % [doc["walls"].size(),
			doc["bridges"].size(), gate["pos"], gate.get("entity", "no GATE"),
			"written" if error == OK else "FAILED %d" % error])
	quit(0 if error == OK else 1)
