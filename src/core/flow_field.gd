# The precomputed flow field in assets/maps/dirs-N.dat: a direction for every
# (from-cell, to-cell) pair on a 128 px grid, which is how tanks path in O(1)
# through GameMode.suggest_direction* and _lookup_direction.
#
# Reading, writing and building it all live here. The file is a big-endian
# java.io.DataInputStream dump like the maps used to be, and it stays binary:
# a stage is 2M packed 3-bit directions, derived from the collision grid rather
# than authored, so there is nothing in it for a human to read.
#
# BUILDING IT IS NOT A FAITHFUL PORT. The generator that produced the shipped
# files is not in this repo, so the rule was reverse engineered from the data
# and it does not reproduce it exactly -- see build_directions for what was
# established and what was chosen. Rebuild only after editing the collision
# grid, which invalidates the field anyway, and check the result by playing:
# the tanks either behave as before or they do not, and no percentage settles
# that.
class_name FlowField
extends RefCounted

const MAPS := "res://assets/maps/"

# One field cell is four tiles to a side.
const TILES_PER_CELL := 4

# Three bits a direction, twenty-one to a 64-bit word, which is what makes the
# whole all-pairs table fit in 790 KB.
const BITS := 3
const PER_WORD := 21

# GameMode.DIR_*, in the order the direction codes are numbered.
const DX: Array[int] = [0, 0, -1, 1, -1, 1, -1, 1]
const DY: Array[int] = [-1, 1, 0, 0, -1, -1, 1, 1]
const OPPOSITE: Array[int] = [1, 0, 3, 2, 7, 6, 5, 4]

# Direction codes by octant, for the straight-line fallback: index is
# round(angle / 45) with angle measured from +x, y downwards.
const OCTANT_DIRECTIONS: Array[int] = [3, 7, 1, 6, 2, 4, 0, 5]

# GameMode.TYPE_* a tank can drive over. Water is not among them: the field is
# for the ground units, and the boats do not consult it.
const DRIVABLE: Array[int] = [MapIO.TYPE_EMPTY, MapIO.TYPE_SWAMP, MapIO.TYPE_CONVEYOR]


static func _open(path: String) -> FileAccess:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	f.big_endian = true
	return f


static func _s32(f: FileAccess) -> int:
	var v := f.get_32()
	return v - 4294967296 if v >= 2147483648 else v


static func load_into(index: int, stage: Stage) -> void:
	var f := _open(MAPS + "dirs-%d.dat" % index)
	if f == null:
		return
	var size := _s32(f)
	stage.directions_width = _s32(f)
	stage.directions_height = _s32(f)
	var dirs := PackedInt64Array()
	dirs.resize(size)
	for i in size:
		dirs[i] = f.get_64()
	stage.directions = dirs
	f.close()


static func save(index: int, stage: Stage) -> Error:
	var path := MAPS + "dirs-%d.dat" % index
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		var error := FileAccess.get_open_error()
		push_error("Cannot write %s (error %d)" % [path, error])
		return error
	f.big_endian = true
	f.store_32(stage.directions.size())
	f.store_32(stage.directions_width)
	f.store_32(stage.directions_height)
	for word in stage.directions:
		f.store_64(word)
	f.close()
	return OK


# Which 128 px cells a ground unit can occupy: the four tiles in the middle of
# the cell. Established by asking the shipped field which cells it steps into --
# they run 12 to 14 tiles clear out of 16, so the rule tolerates blocked tiles
# around the rim but not in the middle. Requiring all sixteen makes the field
# step into cells it calls walls 2.5% of the time; this rule, 0.3%.
#
# The measure that settles it is whether the shipped field, followed cell by
# cell, arrives where it says it is going. Counting by file index, under this
# rule it does on 99% of dirs-0's walks, 98% of dirs-2's, 87% of dirs-3's and
# 86% of dirs-5's. Nothing beats it: counting drivable tiles instead, loosening
# the middle to two tiles or one, and letting water count all score the same or
# worse on every stage.
#
# Two files are the exception and no rule helps them: dirs-1 arrives on 38% and
# dirs-4 on 56%, whatever passability is assumed. Those two disagree with their
# own collision grids, which most likely means they were generated from a
# different revision of those maps. Rebuilding them will change how tanks move
# there -- towards the map that is actually in the game.
static func passable_cells(stage: Stage) -> PackedByteArray:
	var width := stage.map_width / TILES_PER_CELL
	var height := stage.map_height / TILES_PER_CELL
	var cells := PackedByteArray()
	cells.resize(width * height)

	for cy in height:
		for cx in width:
			var open := true
			for dy in [1, 2]:
				for dx in [1, 2]:
					var t: int = stage.types_map[cy * TILES_PER_CELL + dy][
						cx * TILES_PER_CELL + dx]
					if not DRIVABLE.has(t):
						open = false
						break
				if not open:
					break
			cells[cx + cy * width] = 1 if open else 0

	return cells


# Fills stage.directions from stage.types_map.
#
# What the data says: the field is a shortest path over the 128 px cells, eight
# connected, and it routes around obstacles rather than pointing straight at the
# target. What was chosen, because the data does not settle it: a plain
# breadth-first search from each target, neighbours visited in direction-code
# order, each cell taking the direction back to whichever neighbour reached it
# first. That agrees with the shipped files on 66% of pairs, and where it
# disagrees it is usually the shipped direction that is one step longer -- 94%
# of the shipped directions are optimal under this model, and every direction
# this produces is.
#
# A cell no path reaches -- a wall, or a pocket sealed off from the target --
# gets the straight line towards the target, so that an enemy standing somewhere
# it should not be still moves sensibly instead of stalling.
static func build(stage: Stage) -> void:
	var width := stage.map_width / TILES_PER_CELL
	var height := stage.map_height / TILES_PER_CELL
	var count := width * height

	# _lookup_direction indexes with ((Y << 4) + X) << 4, so the cell grid has to
	# be sixteen wide -- which it is, every map being 64 tiles across.
	if width != 16:
		push_error("The flow field index assumes 16 cells across, got %d" % width)
		return

	var cells := passable_cells(stage)
	var directions := PackedByteArray()
	directions.resize(count * count)

	var distance := PackedInt32Array()
	distance.resize(count)
	var step := PackedByteArray()
	step.resize(count)
	var queue := PackedInt32Array()
	queue.resize(count)

	for target in count:
		for i in count:
			distance[i] = -1
			step[i] = 8  # no direction yet

		var head := 0
		var tail := 0
		if cells[target] != 0:
			distance[target] = 0
			queue[0] = target
			tail = 1

		while head < tail:
			var cell := queue[head]
			head += 1
			var cx := cell % width
			var cy := cell / width
			for k in 8:
				var nx := cx + DX[k]
				var ny := cy + DY[k]
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var n := nx + ny * width
				if cells[n] == 0 or distance[n] >= 0:
					continue
				distance[n] = distance[cell] + 1
				step[n] = OPPOSITE[k]
				queue[tail] = n
				tail += 1

		var tx := target % width
		var ty := target / width
		for source in count:
			var value: int
			if source == target:
				value = 0
			elif step[source] < 8:
				value = step[source]
			else:
				value = _straight_direction(source % width, source / width, tx, ty)
			directions[source * count + target] = value

	stage.directions_width = width
	stage.directions_height = height
	stage.directions = _pack(directions)


static func _straight_direction(sx: int, sy: int, tx: int, ty: int) -> int:
	var angle := rad_to_deg(atan2(float(ty - sy), float(tx - sx)))
	if angle < 0.0:
		angle += 360.0
	return OCTANT_DIRECTIONS[int(round(angle / 45.0)) % 8]


static func _pack(directions: PackedByteArray) -> PackedInt64Array:
	var total := directions.size()
	var words := PackedInt64Array()
	words.resize((total + PER_WORD - 1) / PER_WORD)

	var i := 0
	for w in words.size():
		var word := 0
		for k in PER_WORD:
			if i >= total:
				break
			word |= directions[i] << (BITS * k)
			i += 1
		words[w] = word

	return words


# The reader in GameMode._lookup_direction, so that a check can compare a built
# field with a loaded one without going through GameMode.
static func direction_at(stage: Stage, source: int, target: int) -> int:
	var i: int = source * (stage.directions_width * stage.directions_height) + target
	return int((stage.directions[i / PER_WORD] >> (BITS * (i % PER_WORD))) & 7)
