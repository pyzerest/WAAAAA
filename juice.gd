extends Node2D
# the juice. damage numbers, boom rings, screen flashes
# world makes one of these, then anything can do world.fx.number(...) etc

var rings = []   # {"pos", "radius", "color", "age", "life"}
var flash_rect: ColorRect


func _ready() -> void:
	z_index = 40


func number(pos: Vector2, text: String, color: Color, size: int = 18) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_constant_override("outline_size", max(4, size / 4))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.position = pos + Vector2(randf_range(-10, 10), -20) - Vector2(size * 0.6, size * 0.7)
	add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 30.0 - size, 0.7).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


func ring(pos: Vector2, radius: float, color: Color, life: float = 0.35) -> void:
	rings.append({"pos": pos, "radius": radius, "color": color, "age": 0.0, "life": life})


func flash(color: Color, hud: CanvasLayer) -> void:
	if flash_rect == null:
		flash_rect = ColorRect.new()
		flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(flash_rect)
	flash_rect.color = color
	var tween := flash_rect.create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, 0.3)


func _process(delta: float) -> void:
	for i in range(rings.size() - 1, -1, -1):
		rings[i]["age"] += delta
		if rings[i]["age"] >= rings[i]["life"]:
			rings.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for r in rings:
		var k: float = r["age"] / r["life"]
		var c: Color = r["color"]
		c.a *= 1.0 - k
		draw_arc(r["pos"], r["radius"] * (0.3 + 0.7 * sqrt(k)), 0.0, TAU, 48, c, 6.0 * (1.0 - k) + 1.0)
