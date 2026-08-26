# Port of jackal.LoadingMode.
class_name LoadingMode
extends RefCounted

var main: Main
var percent_width: int  # 0 to 516


func init(p_main: Main) -> void:
	main = p_main


func update() -> void:
	percent_width = int(516 * main.load_next())


func render() -> void:
	main.draw_rect(Rect2(0, 0, Main.DISPLAY_WIDTH, Main.DISPLAY_HEIGHT),
		Color.BLACK, true)

	main.draw(main.controllers[0], 256, 307)

	main.set_clip(254, 305, percent_width, 222)
	main.draw(main.controllers[1], 256, 307)
	main.clear_clip()

	main.draw_text("loading", 400, 557, Main.FONT_GRAY)
