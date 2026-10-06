extends SceneTree

# The 3D preview's mission's end (Level3DVictoryScreen, the scene of
# Level3DVictory and the summary over it) on its own, without the stage, to
# a PNG -- the one way to see it while the preview does not open it. Needs a
# window (--headless has no framebuffer to read back). Without the preview
# there are no HUD icons: the summary's row of prisoners is missing.
#
#     godot --path . --windowed --resolution 1920x1080 --script tools/victory_shot.gd \
#         -- <out.png> <players, 1 or 2> [<seconds>] [<upgrade>,...]
#
# `seconds` (6 if not given) is how long it runs before the shot: the summary
# comes in from 1.6 s and is all there by about 5. The upgrades, the shop's
# ids, are on every jeep; the first's olive, the second's blue, both on the
# missile.

func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	if args.size() < 2:
		push_error("usage: -- <out.png> <players> [<seconds>] [<upgrade>,...]")
		quit(1)
		return
	var players := clampi(int(args[1]), 1, 2)
	var seconds := float(args[2]) if args.size() > 2 else 6.0
	var upgrades: Array[String] = []
	if args.size() > 3:
		for id in String(args[3]).split(",", false):
			upgrades.append(id)
	var paints: Array[String] = []
	var kits: Array = []
	for i in players:
		paints.append(["olive", "blue"][i])
		var kit := Level3DRun.Kit.new()
		kit.set_weapon(1)
		kit.upgrades = upgrades.duplicate()
		kits.append(kit)
	var rescued: Array[int] = []
	for i in 9:
		rescued.append(i % players)
	var screen := Level3DVictoryScreen.new()
	root.add_child(screen)
	# The tree's first frame: nothing added in _initialize is ready before it,
	# and the jeeps (Level3DBtr) are made from their _ready.
	await process_frame
	screen.open(rescued, 13, 46200, paints, kits, true)
	await create_timer(seconds).timeout
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(String(args[0]))
	if error != OK:
		push_error("Cannot write %s (error %d)" % [args[0], error])
	quit()
