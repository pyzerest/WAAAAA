extends Node2D
# A ring around the player with arrows on it pointing at the nearest enemies.
# The closest enemy gets the big bright arrow; the next few get smaller, fainter ones.

@export var ring_radius = 58.0
@export var arrow_count = 3           # how many enemies get an arrow (1 = only the nearest)
@export var hide_within = 75.0        # no arrow for enemies this close (they're basically on you)
@export var ring_color = Color(1, 1, 1, 0.12)
@export var nearest_color = Color(1.0, 0.25, 0.25, 0.95)
@export var other_color = Color(1.0, 0.6, 0.3, 0.5)
@export var boss_color = Color(1.0, 0.85, 0.1, 1.0)     # every big shape always gets one of these
@export var ram_ring_color = Color(1.0, 0.55, 0.1, 0.6)  # ring glows when you're fast enough to ram

var time: float = 0.0
var targets = []                      # [{"dir": Vector2, "dist": float}], nearest first
var boss_dirs = []                    # direction to every boss
var can_ram: bool = false


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	time += delta
	var me: Vector2 = get_parent().global_position
	can_ram = get_parent().has_method("can_ram") and get_parent().can_ram()

	# sort every enemy by distance and keep the closest few
	# (enemies already inside the ring are skipped, so the arrow moves on to the next one)
	var list = []
	boss_dirs = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector2 = enemy.global_position - me
		if enemy.is_boss and offset.length() >= hide_within:
			boss_dirs.append(offset.normalized())
			continue
		if offset.length() >= hide_within:
			list.append({"dir": offset.normalized(), "dist": offset.length()})
	list.sort_custom(func(a, b): return a["dist"] < b["dist"])
	targets = list.slice(0, arrow_count)
	queue_redraw()


func _draw() -> void:
	if can_ram:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, ram_ring_color, 4.0)
	else:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, ring_color, 2.0)

	# draw back to front so the nearest arrow ends up on top
	for i in range(targets.size() - 1, -1, -1):
		var t = targets[i]
		var nearest: bool = i == 0
		var size: float = 13.0 if nearest else 8.0
		if nearest:
			size += sin(time * 8.0) * 1.5   # little pulse
		var color: Color = nearest_color if nearest else other_color
		draw_arrow(t["dir"], size, color)

	# bosses: a big double arrow, always shown no matter how far away
	for dir in boss_dirs:
		draw_arrow(dir, 16.0, boss_color)
		draw_arrow(dir * 1.25, 12.0, boss_color)


func draw_arrow(dir: Vector2, size: float, color: Color) -> void:
	# triangle sitting on the ring, tip pointing outward toward the enemy
	var base: Vector2 = dir * ring_radius
	var side: Vector2 = dir.orthogonal()
	var tip: Vector2 = base + dir * size
	var left: Vector2 = base - dir * size * 0.3 + side * size * 0.7
	var right: Vector2 = base - dir * size * 0.3 - side * size * 0.7
	draw_colored_polygon(PackedVector2Array([tip, left, right]), color)
