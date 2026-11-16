extends Node2D
# zaps the closest enemy then the lightning jumps to the next closest one
# that it hasnt hit yet, n so on

@export var first_range = 380.0   # how far the first zap can reach from u
@export var jump_range = 190.0    # how far each jump can reach
@export var bolt_time = 0.2
@export var color = Color(1.0, 0.95, 0.35)

var level: int = 1
var player
var timer: float = 0.5
var bolts = []                    # each bolt is a jagged PackedVector2array
var bolt_fade: float = 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5


func level_up() -> void:
	level += 1


func cooldown() -> float:
	return max(0.5, 1.8 - 0.25 * level)


func targets() -> int:
	return 2 + level              # 3..10 enemies per zap


func damage() -> int:
	return 1 + (level - 1) / 2 + player.weapon_damage_bonus    # 1, 1, 2, 2, 3, 3, 4, 4 (+ overcharge)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	bolt_fade -= delta
	timer -= delta
	if timer <= 0.0:
		timer = cooldown() if zap() else 0.2
	queue_redraw()


func zap() -> bool:
	var hit = []
	var from: Vector2 = player.global_position
	var reach: float = first_range
	var new_bolts = []
	for i in targets():
		# closest enemy to the last thing we hit that hasnt been hit yet
		var next = null
		var next_dist: float = reach
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if hit.has(enemy):
				continue
			var d: float = enemy.global_position.distance_to(from)
			if d < next_dist:
				next = enemy
				next_dist = d
		if next == null:
			break
		hit.append(next)
		new_bolts.append(jagged_line(from, next.global_position))
		from = next.global_position
		reach = jump_range

	if hit.is_empty():
		return false
	for enemy in hit:
		enemy.take_damage(damage(), Vector2.ZERO)
	bolts = new_bolts
	bolt_fade = bolt_time
	return true


func jagged_line(a: Vector2, b: Vector2) -> PackedVector2Array:
	# split the line into short pieces n nudge each corner sideways
	var pts := PackedVector2Array([a])
	var side := (b - a).orthogonal().normalized()
	var steps: int = max(2, int(a.distance_to(b) / 18.0))
	for s in range(1, steps):
		pts.append(a.lerp(b, float(s) / steps) + side * randf_range(-9.0, 9.0))
	pts.append(b)
	return pts


func _draw() -> void:
	if bolt_fade <= 0.0:
		return
	var a: float = bolt_fade / bolt_time
	for bolt in bolts:
		draw_polyline(bolt, Color(color, 0.3 * a), 7.0)
		draw_polyline(bolt, Color(1, 1, 1, a), 2.0)
