extends SceneTree

# The 3D preview's game over screen (Level3DGameOverScreen, the cemetery of
# Level3DGameOver under its plate) on its own, without the stage under it, to
# a PNG: quicker to look at than the preview's --shot with --game-over, which
# loads the whole stage first. Needs a window (--headless has no framebuffer
# to read back):
#
#     godot --path . --windowed --resolution 1920x1080 --script tools/game_over_shot.gd \
#         -- <out.png> <rescued, "7" or "7,4"[:<total>]> [<seconds>] [<scores, "12300,4500">] [--menu]
#
# `seconds` (4 if not given) is how long it runs before the shot: the guard
# salutes from 1.2 s on, the plate comes at 2.4 s. --menu presses a key once
# it is all in, for CONTINUE / END, and takes the shot half a second after.

func _initialize() -> void:
	var args := Array(OS.get_cmdline_user_args())
	var menu := args.has("--menu")
	args.erase("--menu")
	if args.size() < 2:
		push_error("usage: -- <out.png> <rescued[,rescued][:total]> [<seconds>] [<scores>] [--menu]")
		quit(1)
		return
	var parts := String(args[1]).split(":")
	var rescued: Array[int] = []
	for n in parts[0].split(","):
		rescued.append(int(n))
	var total := int(parts[1]) if parts.size() > 1 else 24
	var seconds := float(args[2]) if args.size() > 2 else 4.0
	# The players' colours as the preview's HUD has them.
	var preview: GDScript = load("res://src/game3d/level3d_preview.gd")
	var scores: Array[int] = []
	var colours: Array[Color] = []
	for i in rescued.size():
		scores.append(0)
		colours.append(preview._crew_colour(i))
	if args.size() > 3:
		var given := String(args[3]).split(",")
		for i in mini(given.size(), scores.size()):
			scores[i] = int(given[i])
	var screen := Level3DGameOverScreen.new()
	root.add_child(screen)
	screen.open(scores, rescued, colours, total, true)
	await create_timer(seconds).timeout
	if menu:
		var press := InputEventKey.new()
		press.keycode = KEY_ENTER
		press.pressed = true
		Input.parse_input_event(press)
		await create_timer(0.5).timeout
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(String(args[0]))
	if error != OK:
		push_error("Cannot write %s (error %d)" % [args[0], error])
	quit()
