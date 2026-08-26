# Rebuilds assets/maps/dirs-N.dat from the collision grid.
#
#     godot --path . --headless --script tools/dirs_build.gd -- 3
#     godot --path . --headless --script tools/dirs_build.gd -- all
#
# Run it after editing the collision types of a stage, which is the only thing
# that invalidates the field. Editing tiles or triggers does not.
#
# This overwrites data that shipped with the port, and the generator behind that
# data is lost -- what this produces agrees with it on roughly two thirds of
# pairs (see FlowField.build and tools/verify_flow_field.gd). So rebuild the
# stage you changed, not all six, unless you mean to.
extends SceneTree


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("usage: -- <stage 0-5> | all")
		quit(1)
		return

	var stages: Array[int] = []
	if args[0] == "all":
		for i in 6:
			stages.append(i)
	else:
		for arg in args:
			var index := int(arg)
			if index < 0 or index > 5:
				print("no such stage: %s" % arg)
				quit(1)
				return
			stages.append(index)

	var sizes := MapIO.load_trigger_sizes()
	for index in stages:
		var stage := Stage.new()
		MapIO.load_stage(index, stage, sizes)
		var started := Time.get_ticks_msec()
		FlowField.build(stage)
		var elapsed := Time.get_ticks_msec() - started
		var error := FlowField.save(index, stage)
		print("  stage %d: %d words in %d ms, %s"
			% [index, stage.directions.size(), elapsed,
				"written" if error == OK else "FAILED"])

	print("\ncheck it with: godot --path . --headless --script tools/verify_flow_field.gd")
	quit(0)
