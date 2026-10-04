# Plays every stage with a fixed seed and a scripted pad and writes the state
# of every logic tick: the camera, the jeep, its lives, score and weapon, and
# how many elements each layer holds. Two revisions that play the same write
# the same file, so a refactor that is meant to change nothing is checked by
# running this on both and comparing:
#
#     godot --path . --headless --script tools/play_trace.gd -- build/play_trace/a.txt
#     godot --path . --headless --script tools/play_trace.gd -- build/play_trace/b.txt ghost
#     godot --path . --headless --script tools/play_trace.gd -- build/play_trace/c.txt coop
#
# Plain, the jeep drives a fixed pattern and dies, which covers the deaths, the
# respawns and the continue screen, but rarely gets far. With `ghost` it cannot
# die, starts with missiles at full power, and is carried up through the stage
# at its own speed whatever is in the way, swinging across the frame: every
# trigger fires, and every boss is reached and fought. `coop` plays two jeeps
# off two pads, and says how often either was outside the frame, which must be
# never. None of them draws anything -- the loop runs inside one frame, so
# nothing is rendered, and render-side counters do not advance;
# tools/verify_backdrop.gd draws.
extends SceneTree

const TICKS := 24000

var main: Main
var started := false


func _initialize() -> void:
	main = load("res://src/game2d/main.tscn").instantiate()
	root.add_child(main)


# Main._ready has run by the first frame; everything happens in it.
func _process(_delta: float) -> bool:
	if not started:
		started = true
		_run()
	return true


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out_path: String = args[0] if args.size() > 0 else "build/play_trace/trace.txt"
	var ghost := args.has("ghost")
	var coop := args.has("coop")
	DirAccess.make_dir_recursive_absolute(out_path.get_base_dir())

	# Driven by hand from here, at the original's 100 ticks to 60 frames.
	main.set_physics_process(false)
	main.set_process(false)

	var lines := PackedStringArray()
	var off_frame := 0
	var outs := 0
	for stage in 6:
		main.set_player_count(2 if coop else 1)
		var pads: Array[HumanInput] = []
		for i in main.player_states.size():
			var pad: HumanInput = load("res://tools/play_trace_input.gd").new()
			pad.ghost = ghost
			# The second pad plays the same pattern a third of a cycle later.
			pad.t = 300 * i
			pads.append(pad)
			main.player_states[i].input = pad
		main.input = pads[0]
		main.random.seed = 1234 + stage
		main.start_player()
		main.stage_index = stage
		main.request_mode(Modes.GAME)
		var gm: GameMode = Main.game_mode
		var frame_acc := 0.0
		for t in TICKS:
			if main.mode != gm:
				lines.append("stage %d tick %d left to %s" % [stage, t,
					main.mode.get_script().resource_path.get_file()])
				break
			if ghost:
				for i in gm.players.size():
					var g: Player = gm.players[i]
					g.invincible = 2
					if t == 0:
						g.state.has_missiles = true
						g.state.missile_power = 2
					if gm.playing:
						g.y = maxf(g.y - Player.SPEED, gm.camera_y + 300.0)
						g.x = 1024.0 + 760.0 * sin(t / 180.0 + i * PI)
			for pad in pads:
				pad.snap()
			main.mode.update()
			frame_acc += 0.6
			while frame_acc >= 1.0:
				frame_acc -= 1.0
				main._process(1.0 / 60.0)
			if main.mode != gm:
				continue
			var counts := PackedStringArray()
			for layer in gm.elements:
				counts.append(str(layer.size()))
			var p: Player = gm.players[0]
			var ps: PlayerState = p.state
			var line := "%d %d %.3f %.3f %.3f a%d r%d i%d L%d S%d M%s%d P%d %s E%d" % [
				stage, t, gm.camera_y, p.x, p.y, p.angle, p.respawning, p.invincible,
				ps.extra_lives, ps.score, ps.has_missiles, ps.missile_power, p.pows,
				",".join(counts), gm.enemies.size()]
			for i in range(1, gm.players.size()):
				var q: Player = gm.players[i]
				var qs: PlayerState = q.state
				line += " | %.3f %.3f a%d r%d i%d L%d S%d M%s%d P%d O%s" % [
					q.x, q.y, q.angle, q.respawning, q.invincible, qs.extra_lives,
					qs.score, qs.has_missiles, qs.missile_power, q.pows, qs.out]
			lines.append(line)
			# Two jeeps must both be inside the frame whenever the game moves.
			if coop and gm.playing and not gm.boss_camera_pan and not gm.ending_camera_pan:
				for q in gm.players:
					if not q.state.out and (q.y < gm.camera_y + GameMode.COOP_EDGE - 0.01
							or q.y > gm.camera_y + Main.SCREEN_HEIGHT - GameMode.COOP_EDGE + 0.01):
						off_frame += 1
						if off_frame <= 5:
							print("off the frame: stage %d tick %d jeep %d y %.1f camera %.1f"
								% [stage, t, q.state.index, q.y, gm.camera_y])
		for q in gm.players:
			if q.state.out:
				outs += 1

	var f := FileAccess.open(out_path, FileAccess.WRITE)
	f.store_string("
".join(lines) + "
")
	f.close()
	main.stop_all_sound()
	print("%d lines to %s" % [lines.size(), out_path])
	if coop:
		print("jeeps off the frame: %d ticks; out of the game at a stage's end: %d"
			% [off_frame, outs])
