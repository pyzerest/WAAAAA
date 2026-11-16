extends Node2D
# draws the boost pads, n in speedrun the START n FINISH
# world tells it where they go

var pads = []            # world positions
var pad_cooldown = []    # secs until each pad can fire again (it dims meanwhile)
var start = null         # vector2 or null
var finish = null        # vector2 or null
var finish_radius: float = 96.0
var time: float = 0.0


func _ready() -> void:
	z_index = -5


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect()
	var cam := get_viewport().get_camera_2d()
	var center: Vector2 = cam.get_screen_center_position() if cam else Vector2.ZERO
	var reach: float = view.size.length() / (cam.zoom.x if cam else 1.0)
	for i in pads.size():
		var p: Vector2 = pads[i]
		if p.distance_to(center) > reach:
			continue   # off screen
		var ready_k: float = 1.0 if pad_cooldown[i] <= 0.0 else 0.35
		var pulse: float = 0.5 + 0.5 * sin(time * 6.0 + i)
		draw_circle(p, 22.0, Color(0.1, 0.9, 1.0, 0.12 * ready_k))
		draw_arc(p, 22.0, 0.0, TAU, 32, Color(0.2, 0.95, 1.0, (0.5 + 0.4 * pulse) * ready_k), 3.0)
		# lightning-ish chevrons
		for k in 2:
			var o := Vector2(-7.0 + k * 9.0, 0.0)
			draw_polyline(PackedVector2Array([p + o + Vector2(-4, -9), p + o + Vector2(4, 0), p + o + Vector2(-4, 9)]),
				Color(0.7, 1.0, 1.0, 0.9 * ready_k), 3.0)
	if start != null:
		draw_gate(start, 60.0, Color(0.3, 1.0, 0.4), "START")
	if finish != null:
		draw_gate(finish, finish_radius, Color(1.0, 0.85, 0.2), "FINISH")


func draw_gate(p: Vector2, r: float, color: Color, text: String) -> void:
	# a checkered ring w a label
	var n := 24
	for i in n:
		var a0 := TAU * i / n + time * 0.4
		var a1 := TAU * (i + 1) / n + time * 0.4
		draw_arc(p, r, a0, a1, 4, Color.WHITE if i % 2 == 0 else Color.BLACK, 8.0)
	draw_circle(p, r - 4.0, Color(color, 0.12 + 0.06 * sin(time * 4.0)))
	draw_arc(p, r + 8.0 + 4.0 * sin(time * 3.0), 0.0, TAU, 48, Color(color, 0.6), 3.0)
	var font := ThemeDB.fallback_font
	var size := 28
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(font, p + Vector2(-width / 2.0, 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, Color.BLACK)
	draw_string(font, p + Vector2(-width / 2.0, 10.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
