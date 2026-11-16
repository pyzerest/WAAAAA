extends Control
# lil map in the corner. M = big map
# shows the whole maze, u, enemies, boost pads, the finish n ur ghost

@export var small_size = 200.0
@export var big_size = 620.0

var world
var map_texture: ImageTexture
var big: bool = false
var time: float = 0.0


func setup(w, image: Image) -> void:
	world = w
	map_texture = ImageTexture.create_from_image(image)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	place()
	get_viewport().size_changed.connect(place)


func place() -> void:
	var screen := get_viewport_rect().size
	var s: float = min(big_size, screen.y - 80.0, screen.x - 40.0) if big else small_size
	size = Vector2(s, s)
	if big:
		position = (screen - size) / 2.0
	else:
		position = Vector2(screen.x - s - 14.0, screen.y - s - 14.0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		big = not big
		place()


func _process(delta: float) -> void:
	time += delta
	queue_redraw()


func to_map(world_pos: Vector2) -> Vector2:
	# world position -> point on the minimap
	var g = world.grid
	var cell: Vector2 = (world_pos - g.center_of(g.rect.position)) / 32.0 + Vector2(0.5, 0.5)
	return cell / Vector2(g.w, g.h) * size


func _draw() -> void:
	if world == null or map_texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size).grow(4.0), Color(0, 0, 0, 0.75))
	draw_texture_rect(map_texture, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.9))
	var dot: float = 2.0 if not big else 3.0
	for p in world.course.pads:
		draw_circle(to_map(p), dot * 0.8, Color(0.2, 0.95, 1.0, 0.8))
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var c := Color(1.0, 0.85, 0.1) if enemy.is_boss else Color(1.0, 0.3, 0.3)
		if enemy.dormant:
			c.a = 0.4
		draw_circle(to_map(enemy.global_position), dot * (2.0 if enemy.is_boss else 1.0), c)
	if world.course.finish != null:
		var f: Vector2 = to_map(world.course.finish)
		var r: float = 5.0 + 2.0 * sin(time * 5.0)
		draw_rect(Rect2(f - Vector2(r, r), Vector2(r, r) * 2.0), Color.WHITE, false, 2.0)
		draw_circle(f, 3.0, Color(1.0, 0.85, 0.2))
	if world.ghost and world.ghost.visible:
		draw_circle(to_map(world.ghost.global_position), dot + 1.0, Color(0.55, 0.9, 1.0, 0.8))
	var me: Vector2 = to_map(world.player.global_position)
	draw_circle(me, dot + 2.5, Color.BLACK)
	draw_circle(me, dot + 1.5, Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.3), false, 1.0)
	if big:
		draw_string(ThemeDB.fallback_font, Vector2(8, size.y - 10), "M to close", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.7))
