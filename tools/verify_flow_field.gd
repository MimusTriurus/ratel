# Builds every stage's flow field and compares it with the shipped dirs-N.dat.
#
#     godot --path . --headless --script tools/verify_flow_field.gd
#
# It writes nothing. Two numbers per stage:
#
#   agreement -- how often the built direction is the shipped one. This will not
#     reach 100%: the generator that produced the shipped files is lost and the
#     rule was reverse engineered (see FlowField.build). Roughly two thirds is
#     what the current model gets; a sharp drop means something broke.
#
#   valid -- how often following the built field from a cell actually arrives at
#     the target. This one must be 100%. A field that does not lead anywhere is
#     a bug no matter how well it agrees with anything.
extends SceneTree

const SAMPLE_TARGETS := 24

const WALKED_INTO_WALL := -1
const WALKED_IN_CIRCLES := -2

var failures := 0


func _init() -> void:
	var sizes := MapIO.load_trigger_sizes()
	var random := RandomNumberGenerator.new()
	random.seed = 20260826

	for index in 6:
		var stage := Stage.new()
		MapIO.load_stage(index, stage, sizes)
		FlowField.load_into(index, stage)

		var shipped := stage.directions
		var shipped_width := stage.directions_width
		var shipped_height := stage.directions_height

		var started := Time.get_ticks_msec()
		FlowField.build(stage)
		var elapsed := Time.get_ticks_msec() - started

		if stage.directions_width != shipped_width \
				or stage.directions_height != shipped_height \
				or stage.directions.size() != shipped.size():
			failures += 1
			print("  FAIL stage %d: built %dx%d/%d words, shipped %dx%d/%d"
				% [index, stage.directions_width, stage.directions_height,
					stage.directions.size(), shipped_width, shipped_height,
					shipped.size()])
			continue

		var count := stage.directions_width * stage.directions_height
		var cells := FlowField.passable_cells(stage)

		# Only pairs with a path between them mean anything. The maps are full of
		# ground a tank cannot drive between -- the far bank of a river, an island
		# -- and what the field says about those is a fallback on both sides.
		var component := _components(stage, cells, count)

		var pairs := 0
		var agree := 0
		var stranded := 0
		for source in count:
			if cells[source] == 0:
				continue
			for target in count:
				if cells[target] == 0 or source == target:
					continue
				if component[source] != component[target]:
					stranded += 1
					continue
				pairs += 1
				var built := FlowField.direction_at(stage, source, target)
				var i: int = source * count + target
				var was := int((shipped[i / FlowField.PER_WORD]
					>> (FlowField.BITS * (i % FlowField.PER_WORD))) & 7)
				if built == was:
					agree += 1

		# How the two fields differ where it shows: the number of cells a tank
		# crosses on its way. Anything the built field does that the shipped one
		# does not is a change in how the game plays.
		var walks := 0
		var arrived := 0
		var same := 0
		var shorter := 0
		var longer := 0
		var shipped_wall := 0
		var shipped_looped := 0
		for _i in SAMPLE_TARGETS:
			var target := random.randi_range(0, count - 1)
			if cells[target] == 0:
				continue
			for source in count:
				if cells[source] == 0 or source == target \
						or component[source] != component[target]:
					continue
				walks += 1
				var built_steps := _walk(stage.directions, stage.directions_width,
					stage.directions_height, cells, source, target, count)
				if built_steps >= 0:
					arrived += 1
				var was_steps := _walk(shipped, shipped_width, shipped_height,
					cells, source, target, count)
				if was_steps == WALKED_INTO_WALL:
					shipped_wall += 1
				elif was_steps == WALKED_IN_CIRCLES:
					shipped_looped += 1
				elif built_steps < 0:
					pass
				elif built_steps == was_steps:
					same += 1
				elif built_steps < was_steps:
					shorter += 1
				else:
					longer += 1

		var valid := 100.0 * arrived / maxi(walks, 1)
		if arrived != walks:
			failures += 1
		print("  stage %d: %d cells open, %.0f%% of pairs connected, agreement %.1f%%, valid %.1f%%, built in %d ms"
			% [index, _count_open(cells),
				100.0 * pairs / maxi(pairs + stranded, 1),
				100.0 * agree / maxi(pairs, 1), valid, elapsed])
		print("      paths over %d walks: same %.1f%%, shorter %.1f%%, longer %.1f%%"
			% [walks, 100.0 * same / maxi(walks, 1), 100.0 * shorter / maxi(walks, 1),
				100.0 * longer / maxi(walks, 1)])
		print("      shipped field walked into a wall on %.1f%%, in circles on %.1f%% (its own fallback, same idea as ours)"
			% [100.0 * shipped_wall / maxi(walks, 1),
				100.0 * shipped_looped / maxi(walks, 1)])

	if failures == 0:
		print("\nevery built field leads to its target")
	else:
		print("\n%d stage(s) failed" % failures)
	quit(1 if failures > 0 else 0)


# Follows a field one cell at a time and returns how many steps it took, or -1
# if it walked into a wall, off the grid, or in circles. A field that leads
# anywhere at all gets there in fewer steps than there are cells.
func _walk(field: PackedInt64Array, width: int, height: int,
		cells: PackedByteArray, source: int, target: int, count: int) -> int:
	var cell := source
	for step in count:
		if cell == target:
			return step
		var i: int = cell * count + target
		var direction := int((field[i / FlowField.PER_WORD]
			>> (FlowField.BITS * (i % FlowField.PER_WORD))) & 7)
		var x: int = cell % width + FlowField.DX[direction]
		var y: int = cell / width + FlowField.DY[direction]
		if x < 0 or y < 0 or x >= width or y >= height:
			return WALKED_INTO_WALL
		cell = x + y * width
		if cells[cell] == 0:
			return WALKED_INTO_WALL
	return WALKED_IN_CIRCLES


# Labels each open cell with the connected region it belongs to, over the same
# eight-way neighbourhood the field is built on.
func _components(stage: Stage, cells: PackedByteArray, count: int) -> PackedInt32Array:
	var width := stage.directions_width
	var height := stage.directions_height
	var label := PackedInt32Array()
	label.resize(count)
	label.fill(-1)

	var next := 0
	for start in count:
		if cells[start] == 0 or label[start] >= 0:
			continue
		label[start] = next
		var queue: Array[int] = [start]
		while not queue.is_empty():
			var cell: int = queue.pop_back()
			var cx := cell % width
			var cy := cell / width
			for k in 8:
				var x: int = cx + FlowField.DX[k]
				var y: int = cy + FlowField.DY[k]
				if x < 0 or y < 0 or x >= width or y >= height:
					continue
				var n := x + y * width
				if cells[n] != 0 and label[n] < 0:
					label[n] = next
					queue.append(n)
		next += 1

	return label


func _count_open(cells: PackedByteArray) -> int:
	var open := 0
	for c in cells:
		if c != 0:
			open += 1
	return open
