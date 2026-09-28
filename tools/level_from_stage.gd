# Writes assets/level3d/stage-0.json, stage 1's 3D level file, out of what
# already exists: the game's map (assets/maps/stage-0.json) and the level
# Blender built from screenshots (resources/3d/jackal_stage1.glb).
#
#     godot --path . --headless --script tools/level_from_stage.gd
#
# From the map: the grid, the destruction groups and the triggers of both
# difficulties as one list of entities. From the level: the scenery placed a
# piece at a time -- palms, rocks, pebbles, sandbag nests, bunkers and pads.
# The terrain, the water, the forest and the walls stay in the .blend for now;
# docs/level-editor-plan.md has the order they come in.
#
# Run it again after either source changes. It overwrites the level file, so
# anything edited in that file since is lost -- which is why nothing but this
# script has written it yet. tools/verify_level3d.gd checks the result.
extends SceneTree

const STAGE := 0
const LEVEL_GLB := "res://resources/3d/jackal_stage1.glb"
# glTF prefixes a mesh's name with the file it came from.
const MESH_PREFIX := "jackal_stage1_"

# Level nodes that are one placed asset each, by name prefix. The first two
# are single meshes and name their asset by the mesh; the rest are collection
# instances and name it here. Bunker covers BunkerN and BunkerN3, which are
# bunkers from later fragments of the screenshots.
const MESH_ASSETS: Array[String] = ["Palm", "Pebble", "Rock_"]
const INSTANCE_ASSETS := {
	"Bunker": "Bunker",
	"SandbagNest": "SandbagNest",
	"HangarPad": "HangarPad",
	"Helipad": "Helipad",
}
# Which entity a placed asset belongs to: the nearest one of these types.
const OWNERS := {
	"Bunker": ["GRAY_GUN", "YELLOW_GUN"],
	"Helipad": ["LANDING_PORT_RIGHT"],
}


func _init() -> void:
	var source := MapIO.read_document(STAGE)
	var stage := Stage.new()
	MapIO.load_stage(STAGE, stage, MapIO.load_trigger_sizes())
	var grid := {
		"width": int(source["width"]), "height": int(source["height"]),
		"tile_px": MapIO.TILE, "m_per_px": Level3DMap.PX,
		"origin": [Level3DMap.ORIGIN.x, Level3DMap.ORIGIN.y],
	}

	var groups: Array = []
	for g in source["groups"]:
		var cells: Array = []
		for cell in g["cells"]:
			cells.append([int(cell[0]), int(cell[1]), cell[3]])
		groups.append({"index": int(g["index"]), "cells": cells})

	var entities := _entities(source, stage, grid)
	var objects := _objects(entities)
	var doc := {
		"stage": STAGE, "grid": grid, "nav": source["types"], "groups": groups,
		"entities": entities, "objects": objects,
	}
	# The ground is tools/level_terrain_from_glb.gd's, and kept as it is.
	if FileAccess.file_exists(Level3DIO.path(STAGE)):
		var old := Level3DIO.read(STAGE)
		for key in ["terrain", "water", "forest"]:
			if old.has(key):
				doc[key] = old[key]
	var error := Level3DIO.save(doc)
	print("%s: %d rows, %d groups, %d entities, %d objects -- %s" % [
		Level3DIO.path(STAGE), (doc["nav"] as Array).size(), groups.size(),
		entities.size(), objects.size(), "written" if error == OK else "FAILED"])
	quit(0 if error == OK else 1)


# Both difficulties' triggers as one list. A trigger both have is one entity on
# both, and the list is their shortest common supersequence, so each
# difficulty's triggers, picked out of it, come back in their own order: the
# order in a row decides the order the elements update in.
func _entities(source: Dictionary, stage: Stage, grid: Dictionary) -> Array:
	var normal: Array = source["triggers"]["normal"]
	var hard: Array = source["triggers"]["hard"]
	var n := normal.size()
	var m := hard.size()
	var a := PackedStringArray()
	for t in normal:
		a.append(_key(t))
	var b := PackedStringArray()
	for t in hard:
		b.append(_key(t))

	# lcs[i * (m + 1) + j]: the longest common subsequence of a[i:] and b[j:].
	var lcs := PackedInt32Array()
	lcs.resize((n + 1) * (m + 1))
	for i in range(n - 1, -1, -1):
		for j in range(m - 1, -1, -1):
			if a[i] == b[j]:
				lcs[i * (m + 1) + j] = lcs[(i + 1) * (m + 1) + j + 1] + 1
			else:
				lcs[i * (m + 1) + j] = maxi(lcs[(i + 1) * (m + 1) + j],
						lcs[i * (m + 1) + j + 1])

	var merged: Array = []  # [trigger, difficulties]
	var i := 0
	var j := 0
	while i < n or j < m:
		if i < n and j < m and a[i] == b[j] \
				and lcs[i * (m + 1) + j] == lcs[(i + 1) * (m + 1) + j + 1] + 1:
			merged.append([normal[i], ["normal", "hard"]])
			i += 1
			j += 1
		elif j >= m or (i < n and lcs[(i + 1) * (m + 1) + j] >= lcs[i * (m + 1) + j + 1]):
			merged.append([normal[i], ["normal"]])
			i += 1
		else:
			merged.append([hard[j], ["hard"]])
			j += 1

	var consts := MapIO.trigger_constants()
	var sizes := Level3DIO.footprints()
	var counts := {}
	var out: Array = []
	for entry in merged:
		var trigger: Dictionary = entry[0]
		var type: String = trigger["type"]
		var tile := Vector2i(int(trigger["x"]), int(trigger["y"]))
		var pos := Level3DIO.entity_pos(grid, sizes[type], tile)
		var number: int = counts.get(type, 0)
		counts[type] = number + 1
		var entity := {
			"id": "%s_%d" % [type.to_lower(), number], "type": type,
			"pos": [Level3DIO.round_mm(pos.x), Level3DIO.round_mm(pos.y)],
			"difficulty": entry[1],
		}
		var index: int = consts[type]
		if MapIO.GROUP_PROBES.has(index):
			var cell: Vector2i = tile + MapIO.GROUP_PROBES[index]
			var group: int = stage.groups_map[cell.y][cell.x]
			if not _covers(stage.groups[group], cell):
				push_warning("%s probes %s, which no group covers: it gets group %d"
						% [entity["id"], cell, group])
			entity["group"] = group
		out.append(entity)
	print("  triggers: %d normal, %d hard, %d both" % [n, m, lcs[0]])
	return out


static func _key(trigger: Dictionary) -> String:
	return "%s,%d,%d" % [trigger["type"], int(trigger["x"]), int(trigger["y"])]


static func _covers(group: Array, cell: Vector2i) -> bool:
	for g in group:
		if g[0] == cell.x and g[1] == cell.y:
			return true
	return false


func _objects(entities: Array) -> Array:
	var scene: PackedScene = load(LEVEL_GLB)
	var level := scene.instantiate()
	var out: Array = []
	var owned := {}
	for child in level.get_children():
		var node := child as Node3D
		var asset := _asset_of(node)
		if asset == "":
			continue
		if not is_zero_approx(node.rotation.x) or not is_zero_approx(node.rotation.z) \
				or not node.scale.is_equal_approx(Vector3.ONE * node.scale.x):
			push_error("%s is tilted or scaled unevenly, which a level object cannot say"
					% node.name)
		var p := node.position
		var object := {
			"id": String(node.name), "asset": asset,
			"pos": [Level3DIO.round_mm(p.x), Level3DIO.round_mm(p.y), Level3DIO.round_mm(p.z)],
			"yaw": wrapf(node.rotation_degrees.y, -180.0, 180.0), "scale": node.scale.x,
		}
		if OWNERS.has(asset):
			var owner := _nearest(entities, OWNERS[asset], Vector2(p.x, p.z))
			if owned.has(owner):
				push_error("%s and %s are both nearest %s" % [owned[owner], node.name, owner])
			owned[owner] = node.name
			object["entity"] = owner
		out.append(object)
	level.free()
	return out


static func _asset_of(node: Node3D) -> String:
	var name := String(node.name)
	if node is MeshInstance3D:
		for prefix in MESH_ASSETS:
			if name.begins_with(prefix):
				return (node as MeshInstance3D).mesh.resource_name.trim_prefix(MESH_PREFIX)
		return ""
	for prefix in INSTANCE_ASSETS:
		if name.begins_with(prefix):
			return INSTANCE_ASSETS[prefix]
	return ""


static func _nearest(entities: Array, types: Array, at: Vector2) -> String:
	var best := ""
	var best_distance := INF
	for e in entities:
		if not types.has(e["type"]):
			continue
		var d := at.distance_to(Vector2(e["pos"][0], e["pos"][1]))
		if d < best_distance:
			best_distance = d
			best = e["id"]
	return best
