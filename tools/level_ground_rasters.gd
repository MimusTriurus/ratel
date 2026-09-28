# Gives a level file that only has ground polygons the rasters the level
# editor paints (Level3DGround), and traces its polygons again off them, so
# that the two agree from then on:
#
#     godot --path . --headless --script tools/level_ground_rasters.gd -- 0
#
# The rasters go to assets/level3d/rasters/stage-N-ground.png and -height.png.
# Run once per level; after that the rasters are the source and the editor
# keeps the polygons in step on every save.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var stage := int(args[0]) if not args.is_empty() else 0
	var started := Time.get_ticks_msec()
	var doc := Level3DIO.read(stage)
	if doc.is_empty():
		quit(1)
		return
	if doc["terrain"].has("raster"):
		print("stage %d already has its rasters: %s" % [stage, doc["terrain"]["raster"]])
		quit()
		return
	var ground := Level3DGround.from_polygons(doc)
	print("  rasterized %d x %d at %.2f m (%d ms)" % [ground.grid.w, ground.grid.h, ground.grid.r,
			Time.get_ticks_msec() - started])
	var error := ground.save_rasters(doc, Level3DIO.DIR, "stage-%d" % stage)
	if error == OK:
		ground.trace(doc)
		error = Level3DIO.save(doc)
	print("stage %d: %d land, %d water, %d forest polygons traced (%d ms) -- %s" % [stage,
			doc["terrain"]["land"].size(), doc["water"].size(), doc["forest"].size(),
			Time.get_ticks_msec() - started, "written" if error == OK else "FAILED %d" % error])
	quit(0 if error == OK else 1)
