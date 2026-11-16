extends Control
# speedometer in the bottom left. no top speed so after 2000 the needle just goes round again lol
# orange tick = fast enough to ram, purple tick = SONIC ram (blows up everything around)

@export var dial_max = 2000.0

var player


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 120)
	size = custom_minimum_size
	place()
	get_viewport().size_changed.connect(place)


func place() -> void:
	position = Vector2(16.0, get_viewport_rect().size.y - size.y - 10.0)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if player == null or not is_instance_valid(player):
		return
	var speed: float = player.velocity.length()
	var c := Vector2(size.x / 2.0, size.y - 22.0)
	var r: float = 70.0
	var a0: float = PI          # left
	var a1: float = TAU         # right (half circle over the top)
	draw_arc(c, r, a0, a1, 48, Color(0, 0, 0, 0.55), 16.0)
	var laps: int = int(speed / dial_max)
	var frac: float = fmod(speed, dial_max) / dial_max
	var col := Color(0.3, 0.9, 1.0)
	if speed >= player.sonic_speed:
		col = Color(0.8, 0.4, 1.0)
	elif player.can_ram():
		col = Color(1.0, 0.6, 0.15)
	if laps > 0:
		draw_arc(c, r, a0, a1, 48, Color(col, 0.35), 12.0)   # already went round once
	if frac > 0.002:
		draw_arc(c, r, a0, a0 + PI * frac, 48, col, 12.0)
	for mark in [[player.ram_speed, Color(1.0, 0.6, 0.15)], [player.sonic_speed, Color(0.8, 0.4, 1.0)]]:
		var a: float = a0 + PI * clamp(mark[0] / dial_max, 0.0, 1.0)
		var dir := Vector2.from_angle(a)
		draw_line(c + dir * (r - 12.0), c + dir * (r + 12.0), mark[1], 3.0)
	var font := ThemeDB.fallback_font
	var text := str(int(speed))
	var fs := 34
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, c + Vector2(-w / 2.0, -6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 8, Color.BLACK)
	draw_string(font, c + Vector2(-w / 2.0, -6.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	var label := "SONIC" if speed >= player.sonic_speed else ("RAM" if player.can_ram() else "speed")
	var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(font, c + Vector2(-lw / 2.0, 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col, 0.9))
