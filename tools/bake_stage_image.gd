# Bakes a stage's tile grid into background chunks -- the image-backdrop
# alternative to assembling the map out of tiles-N.png at draw time.
#
#     godot --path . --headless --script tools/bake_stage_image.gd -- all
#     godot --path . --headless --script tools/bake_stage_image.gd -- 2 --water
#     godot --path . --headless --script tools/bake_stage_image.gd -- all --chunk 1024 --out /tmp/levels
#
# What comes out is what GameMode._draw_background() draws today, pixel for
# pixel: this loads the same data the game does -- MapIO for the stage,
# Main.load_tiles for the sheets -- and blits the same sprite into the same
# place. So a stage switched over to an image backdrop can be compared against
# the tile path frame by frame, and the images double as wallpaper to paint over
# by hand.
#
# Chunks, not one texture per stage: a stage is 2048x11488 (2048x12512 for
# stage 5), which is 94 MB of RGBA8 -- and Main.load_stages() loads all six up
# front. Chunk k covers rows [k * chunk / 32, ...) and is named stage-N-K.png,
# so nothing has to be written down: the count and the last chunk's height
# follow from Stage.map_height. The map is exactly one frame wide
# (map_width * 32 == Main.SCREEN_WIDTH, which is why max_camera_x is 0), so
# chunks are only ever stacked vertically.
#
# Three things are left out of the image on purpose, because they move:
#
#   - Stage 2's water. tiles-2 is the one sheet with transparency (tile 8 is
#     blank, tiles 9..31 partial), and _draw_background cross-fades two water
#     sets underneath every cell whose tile is under 32. Baking the terrain
#     layer alone therefore leaves holes in exactly the shape of the water,
#     which is what an animated layer drawn under the image wants. --water fills
#     them in at the mid-point of WATER_ALPHAS for a look at the whole picture;
#     that is for looking at, not for shipping.
#   - Stage 5's conveyor, where GameMode swaps tiles[0] for a frame of
#     main.conveyors every tick. Frame 0 is baked in. The frames are opaque, so
#     an animated layer over the image covers it.
#   - Destruction. trigger_group() rewrites the cells listed in the stage's
#     groups, 16 to 50 cells a stage, and TileDebris flings the old tile away
#     first. Those cells are baked in the pristine state the tile path starts
#     them in.
extends SceneTree

const LEVELS := "res://assets/images/levels/"
const TILE := 32

# Mid-point of GameMode.WATER_ALPHAS, for --water only.
const WATER_PREVIEW_ALPHA := 0.5

var images: Dictionary = {}   # texture instance id -> Image
var faded: Dictionary = {}    # tile index -> Image, the --water half-alpha copies


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var stages: Array[int] = []
	var out_dir := LEVELS
	var chunk := 2048
	var water := false

	var i := 0
	while i < args.size():
		var arg: String = args[i]
		match arg:
			"--out":
				i += 1
				if i == args.size():
					print("--out wants a directory")
					quit(1)
					return
				out_dir = args[i]
			"--chunk":
				i += 1
				if i == args.size():
					print("--chunk wants a height in pixels")
					quit(1)
					return
				chunk = int(args[i])
				if chunk <= 0 or chunk % TILE != 0:
					print("--chunk must be a positive multiple of %d" % TILE)
					quit(1)
					return
			"--water":
				water = true
			"all":
				for s in 6:
					stages.append(s)
			_:
				if not arg.is_valid_int() or int(arg) < 0 or int(arg) > 5:
					print("no such stage: %s" % arg)
					quit(1)
					return
				stages.append(int(arg))
		i += 1

	if stages.is_empty():
		print("usage: -- <stage 0-5> ... | all  [--out DIR] [--chunk PX] [--water]")
		quit(1)
		return

	if not out_dir.ends_with("/"):
		out_dir += "/"
	var error := DirAccess.make_dir_recursive_absolute(out_dir)
	if error != OK:
		print("cannot create %s: %d" % [out_dir, error])
		quit(1)
		return

	print("chunk %d px (%d rows) -> %s%s"
		% [chunk, chunk / TILE, out_dir, "  [water baked in]" if water else ""])
	var sizes := MapIO.load_trigger_sizes()
	var total := 0
	for index in stages:
		total += _bake(index, out_dir, chunk, water, sizes)
	print("\n%d chunks, %.1f MB on disk" % [total, _dir_bytes(out_dir) / 1048576.0])
	quit(0)


func _bake(index: int, out_dir: String, chunk: int, water: bool,
		sizes: Array) -> int:
	var stage := Stage.new()
	MapIO.load_stage(index, stage, sizes)

	# Main owns the tile sheets, and load_tiles is the only thing needed off it
	# -- as in src/tools/map_editor.gd. Never in the tree, so nothing else runs.
	var main := Main.new()
	main.load_tiles(index, stage)
	main.free()

	faded.clear()
	if water and index == 2:
		for t in 4:
			faded[t] = _fade(stage.tiles[t], WATER_PREVIEW_ALPHA)

	var width: int = stage.map_width * TILE
	var height: int = stage.map_height * TILE
	var rows_per_chunk := chunk / TILE
	var chunks: int = (stage.map_height + rows_per_chunk - 1) / rows_per_chunk
	var started := Time.get_ticks_msec()
	var written := 0

	for k in chunks:
		var y0: int = k * rows_per_chunk
		var rows: int = mini(rows_per_chunk, stage.map_height - y0)
		var img := Image.create_empty(width, rows * TILE, false, Image.FORMAT_RGBA8)

		for y in range(y0, y0 + rows):
			var row: PackedInt32Array = stage.tile_map[y]
			var Y := (y - y0) * TILE
			for x in stage.map_width:
				var tile := row[x]
				var X := x * TILE

				# _draw_background lays the animated water down first, in a 2x2
				# checkerboard keyed off the absolute cell, under every cell
				# whose tile is under 32.
				if water and index == 2 and tile < 32:
					var w := ((y & 1) << 1) + (x & 1)
					_paint(img, stage.tiles[w + 4], X, Y, false)
					_paint_image(img, faded[w], X, Y, true)

				# The two passes of _draw_background -- the tiles under 225,
				# then the sheet 6 tiles over the top -- collapse into one blit
				# here. Both are per cell and a cell holds one tile, so which
				# pass a cell is drawn in cannot change what lands in these 32
				# pixels.
				_paint(img, stage.tiles[tile], X, Y, water)

		var path := "%sstage-%d-%d.png" % [out_dir, index, k]
		var save := img.save_png(path)
		if save != OK:
			print("  stage %d chunk %d: FAILED (%d)" % [index, k, save])
			continue
		written += 1

	print("  stage %d: %d rows, %dx%d px, %d chunks (last %d px), %d ms"
		% [index, stage.map_height, width, height, chunks,
			(stage.map_height - (chunks - 1) * rows_per_chunk) * TILE,
			Time.get_ticks_msec() - started])
	return written


# Blends when something may already be underneath, copies verbatim otherwise.
# A verbatim copy keeps the tile's own alpha, which is the whole point on stage
# 2: the holes in the terrain are where the water shows through.
func _paint(dst: Image, s: Spr, x: int, y: int, blend: bool) -> void:
	if s == null:
		return
	_paint_region(dst, _image_of(s.tex), Rect2i(s.region), x, y, blend)


func _paint_image(dst: Image, src: Image, x: int, y: int, blend: bool) -> void:
	_paint_region(dst, src, Rect2i(Vector2i.ZERO, src.get_size()), x, y, blend)


func _paint_region(dst: Image, src: Image, region: Rect2i, x: int, y: int,
		blend: bool) -> void:
	if blend:
		dst.blend_rect(src, region, Vector2i(x, y))
	else:
		dst.blit_rect(src, region, Vector2i(x, y))


func _image_of(tex: Texture2D) -> Image:
	var key := tex.get_instance_id()
	if images.has(key):
		return images[key]
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	images[key] = img
	return img


# Spr carries its own alpha and blend_rect has no factor, so the faded copy is
# made once rather than per cell.
func _fade(s: Spr, alpha: float) -> Image:
	var src := _image_of(s.tex)
	var img := Image.create_empty(int(s.w), int(s.h), false, Image.FORMAT_RGBA8)
	img.blit_rect(src, Rect2i(s.region), Vector2i.ZERO)
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			c.a *= alpha
			img.set_pixel(x, y, c)
	return img


func _dir_bytes(dir_path: String) -> int:
	var bytes := 0
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	for name in dir.get_files():
		if not name.ends_with(".png"):
			continue
		var f := FileAccess.open(dir_path + name, FileAccess.READ)
		if f != null:
			bytes += f.get_length()
	return bytes
