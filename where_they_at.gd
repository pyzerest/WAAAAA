extends Node2D
# the ring around u w arrows pointing at the closest enemies (where they at)
# closest one gets the big bright arrow, next few get smaller fainter ones

@export var ring_radius = 58.0
@export var arrow_count = 3           # how many enemies get an arrow (1 = only the closest)
@export var hide_within = 75.0        # no arrow for enemies this close (theyre basically on u)
@export var ring_color = Color(1, 1, 1, 0.12)
@export var nearest_color = Color(1.0, 0.25, 0.25, 0.95)
@export var other_color = Color(1.0, 0.6, 0.3, 0.5)
@export var boss_color = Color(1.0, 0.85, 0.1, 1.0)     # every big shape always gets one of these
@export var ram_ring_color = Color(1.0, 0.55, 0.1, 0.6)  # ring glows when ur fast enough to ram
@export var sonic_ring_color = Color(0.85, 0.45, 1.0, 0.8)  # ...n purple at SONIC ram speed
@export var goal_color = Color(0.3, 1.0, 0.45, 1.0)       # speedrun: points at the finish

var time: float = 0.0
var targets = []                      # [{"dir": vector2, "dist": float}], closest first
var boss_dirs = []                    # direction to every boss
var can_ram: bool = false
var sonic: bool = false
var goal = null                       # speedrun: the finish line position (set by the world)


func _ready() -> void:
	z_index = 10


func _process(delta: float) -> void:
	time += delta
	var me: Vector2 = get_parent().global_position
	can_ram = get_parent().has_method("can_ram") and get_parent().can_ram()
	sonic = can_ram and get_parent().velocity.length() >= get_parent().sonic_speed

	# sort every enemy by distance n keep the closest few
	# (enemies already inside the ring are skipped, so the arrow moves on to the next one)
	var list = []
	boss_dirs = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dormant:
			continue   # sleeping speedrun enemies dont get arrows
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
	if sonic:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, sonic_ring_color, 6.0 + sin(time * 20.0) * 2.0)
	elif can_ram:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, ram_ring_color, 4.0)
	else:
		draw_arc(Vector2.ZERO, ring_radius, 0.0, TAU, 64, ring_color, 2.0)

	# draw back to front so the closest arrow ends up on top
	for i in range(targets.size() - 1, -1, -1):
		var t = targets[i]
		var nearest: bool = i == 0
		var size: float = 13.0 if nearest else 8.0
		if nearest:
			size += sin(time * 8.0) * 1.5   # little pulse
		var color: Color = nearest_color if nearest else other_color
		draw_arrow(t["dir"], size, color)

	# speedrun: a big green triple arrow toward the finish
	if goal != null:
		var gdir: Vector2 = (goal - get_parent().global_position).normalized()
		for k in 3:
			draw_arrow(gdir * (1.0 + 0.22 * k + 0.05 * sin(time * 6.0)), 15.0 - k * 2.0, goal_color)

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
