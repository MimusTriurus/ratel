# Proves an image backdrop draws what the tile grid drew.
#
#     godot --path . --windowed --resolution 1280x720 --script tools/verify_backdrop.gd
#
# It needs a real window: the frames are read back off the framebuffer, and
# --headless has none. Nothing is written unless something differs, and a
# mismatching pair is dumped as diff-<stage>-<sample>-{tiles,image}.png in the
# working directory (or wherever the first user argument points).
#
# The game is booted for real, a stage entered, and then frozen -- paused, with
# the fade-in cut short -- so nothing spawns and the camera stays where it is
# put. Each sample is rendered twice, once with the stage switched to
# MapIO.BACKGROUND_TILES and once with MapIO.BACKGROUND_IMAGE, and the two frames
# are compared byte for byte. What the samples are for:
#
#   - even: six places down the stage, the ordinary case.
#   - seam: the boundary between two chunks halfway down the frame, where an
#     off-by-one in the chunk offset would show and nowhere else.
#   - group: every destruction group fired, parked on the group's first cell.
#     This is the patch overlay -- the cells the image no longer describes.
#
# Then background_sprite(), the sub-image TileDebris flings, against the tile the
# sheet holds for the same cell, over a grid of cells in every stage.
#
# The stage files themselves are not touched: the mode is switched on the loaded
# Stage, so this checks both paths whatever the files happen to say.
extends SceneTree

const SAMPLES := 6
const HALF_FRAME := Main.SCREEN_HEIGHT / 2
# Columns the debris check walks, and how many rows of them.
const DEBRIS_COLUMNS: Array[int] = [0, 17, 31, 48, 63]
const DEBRIS_ROWS := 40
# process/fix_alpha_border rewrites the colour under near-zero alpha at import
# time, and a chunk has been through the importer a second time, so colour is
# compared only where the pixel can be seen.
const ALPHA_FLOOR := 8.0 / 255.0

var queue: Array[Callable] = []
var main_node: Node = null
var game_mode: GameMode = null
var stage_res: Stage = null
var frame_a: Image = null
var mismatches := 0
var compared := 0
var debris_checked := 0
var debris_bad := 0
var out_dir := "."


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0]

	main_node = load("res://src/main.tscn").instantiate()
	root.add_child(main_node)

	for stage_index in 6:
		queue.append(_enter.bind(stage_index))
		queue.append(_nop)
		queue.append(_check_debris_sprites)
		for sample in SAMPLES:
			_queue_sample("even %d" % sample, _park_fraction.bind(sample), false)
		for seam in 6:
			_queue_sample("seam %d" % seam, _park_seam.bind(seam), false)
		for group in 25:
			_queue_sample("group %d" % group, _park_group.bind(group), true)
	queue.append(_done)


# One sample is a queue of steps, one per frame: the readback returns the frame
# that has already been drawn, so each pass needs a frame of its own to land in.
func _queue_sample(label: String, park: Callable, destroy: bool) -> void:
	queue.append(park)
	queue.append(_mode.bind(MapIO.BACKGROUND_TILES))
	if destroy:
		queue.append(_destroy)
	queue.append(_nop)
	queue.append(_grab_a)
	queue.append(_mode.bind(MapIO.BACKGROUND_IMAGE))
	if destroy:
		queue.append(_destroy)
	queue.append(_nop)
	queue.append(_compare.bind(label))


func _process(_delta: float) -> bool:
	if queue.is_empty():
		return true
	var step: Callable = queue.pop_front()
	step.call()
	return false


func _nop() -> void:
	pass


func _enter(stage_index: int) -> void:
	main_node.stage_index = stage_index
	main_node.request_mode(Modes.GAME)
	game_mode = Main.game_mode
	stage_res = main_node.stages[stage_index]

	# update() returns immediately while paused, so no trigger fires, no element
	# moves and the camera stays where it is put.
	game_mode.paused = true
	# Entering a stage starts a fade-in, and Main._process advances it every
	# frame: the two passes are three frames apart, so the ramp alone would
	# darken one of them by a fifth.
	main_node.fading = false
	# The conveyor frame is chosen by the update tick, which is frozen. Any frame
	# but 0 will do -- it has to be one the baked image cannot have got right by
	# accident.
	if stage_index == 5:
		game_mode.tiles[0] = main_node.conveyors[7]

	print("stage %d: %d chunks of %d rows, %d groups"
		% [stage_index, MapIO.background_chunk_count(stage_res),
			MapIO.background_chunk_rows(stage_res), game_mode.groups.size()])


func _park(y: float, phase: int) -> void:
	game_mode.camera_y = clampf(y, 0.0, game_mode.max_camera_y)
	# The water cross-fade advances from the update tick as well, so each sample
	# names its own phase rather than leaving all of them at 0.
	game_mode.water_alpha_index = (phase * 17) % GameMode.WATER_ALPHAS_PERIOD


func _park_fraction(sample: int) -> void:
	_park(floor(game_mode.max_camera_y * sample / float(SAMPLES - 1)), sample)


func _park_seam(seam: int) -> void:
	_park(float(seam * stage_res.background_chunk_height - HALF_FRAME), seam)


func _park_group(group: int) -> void:
	if group >= game_mode.groups.size():
		# Fewer groups than the loop allows for; park somewhere harmless and let
		# the comparison run anyway.
		_park(0.0, group)
		return
	var cell: Array = game_mode.groups[group][0]
	_park(float(int(cell[1]) * 32 - HALF_FRAME), group)


func _destroy() -> void:
	# Switching backdrops clears the patch set, so the groups are fired again for
	# each pass; trigged_groups is what would otherwise make this a no-op.
	game_mode.trigged_groups.fill(0)
	for i in game_mode.groups.size():
		game_mode.trigger_group(i)


func _mode(mode: int) -> void:
	stage_res.background_mode = mode
	game_mode.prepare_background()


func _grab_a() -> void:
	frame_a = root.get_texture().get_image()


func _compare(label: String) -> void:
	var frame_b := root.get_texture().get_image()
	compared += 1
	if frame_a.get_data() == frame_b.get_data():
		return

	mismatches += 1
	var differing := 0
	for y in frame_a.get_height():
		for x in frame_a.get_width():
			if frame_a.get_pixel(x, y) != frame_b.get_pixel(x, y):
				differing += 1
	print("  MISMATCH stage %d %s (camera_y %d): %d of %d px"
		% [game_mode.stage_index, label, int(game_mode.camera_y), differing,
			frame_a.get_width() * frame_a.get_height()])

	var name := "%s/diff-%d-%s" % [out_dir, game_mode.stage_index,
		label.replace(" ", "-")]
	frame_a.save_png(name + "-tiles.png")
	frame_b.save_png(name + "-image.png")


func _check_debris_sprites() -> void:
	stage_res.background_mode = MapIO.BACKGROUND_IMAGE
	game_mode.prepare_background()

	var bad := 0
	@warning_ignore("integer_division")
	var step: int = maxi(1, game_mode.map_height / DEBRIS_ROWS)
	for y in range(0, game_mode.map_height, step):
		for x in DEBRIS_COLUMNS:
			debris_checked += 1
			if _same_pixels(game_mode.background_sprite(x, y),
					game_mode.tiles[game_mode.tile_map[y][x]]):
				continue
			bad += 1
			print("      cell %d,%d differs: tile %d, type %d"
				% [x, y, game_mode.tile_map[y][x], game_mode.types_map[y][x]])
	debris_bad += bad
	print("  debris sprites off the chunks: %s"
		% ["ok" if bad == 0 else "%d WRONG" % bad])


func _same_pixels(a: Spr, b: Spr) -> bool:
	var ia: Image = a.tex.get_image()
	var ib: Image = b.tex.get_image()
	for y in 32:
		for x in 32:
			var pa := ia.get_pixel(int(a.region.position.x) + x,
				int(a.region.position.y) + y)
			var pb := ib.get_pixel(int(b.region.position.x) + x,
				int(b.region.position.y) + y)
			if pa.a != pb.a:
				return false
			if pa.a > ALPHA_FLOOR \
					and (pa.r != pb.r or pa.g != pb.g or pa.b != pb.b):
				return false
	return true


func _done() -> void:
	print("\n%d frames compared, %d differ" % [compared, mismatches])
	print("%d debris sprites checked, %d wrong" % [debris_checked, debris_bad])
	quit(1 if mismatches > 0 or debris_bad > 0 else 0)
