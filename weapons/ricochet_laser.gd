extends Node2D
# Every few seconds, fires a laser at the nearest enemy. The beam reflects off
# walls (like the disk) and pierces every enemy along its whole path.

@export var max_length = 1400.0   # total beam length, all bounces combined
@export var target_range = 900.0  # only fires if an enemy is this close
@export var beam_width = 6.0
@export var beam_time = 0.25      # how long the beam stays visible
@export var color = Color(1.0, 0.3, 0.6)

var level: int = 1
var player
var timer: float = 1.0
var beam_points = PackedVector2Array()
var beam_fade: float = 0.0


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5


func level_up() -> void:
	level += 1


func cooldown() -> float:
	return max(0.6, 2.2 - 0.3 * level)


func bounces() -> int:
	return level                  # 1..8 wall reflections


func damage() -> int:
	return 1 + level / 2 + player.weapon_damage_bonus    # 1, 2, 2, 3, 3, 4, 4, 5 (+ Overcharge)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	beam_fade -= delta
	timer -= delta
	if timer <= 0.0:
		var target = nearest_enemy(target_range)
		if target:
			fire((target.global_position - player.global_position).normalized())
			timer = cooldown()
		else:
			timer = 0.2           # nothing to shoot, check again soon
	queue_redraw()


func nearest_enemy(max_dist: float):
	var best = null
	var best_dist: float = max_dist
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var d: float = enemy.global_position.distance_to(player.global_position)
		if d < best_dist:
			best = enemy
			best_dist = d
	return best


func fire(dir: Vector2) -> void:
	# trace the beam: raycast against walls (layer 1), mirror off each one
	var space := get_world_2d().direct_space_state
	var points := PackedVector2Array([player.global_position])
	var pos: Vector2 = player.global_position
	var remaining: float = max_length
	for i in bounces() + 1:
		var query := PhysicsRayQueryParameters2D.create(pos, pos + dir * remaining, 1)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			points.append(pos + dir * remaining)
			break
		var hit_pos: Vector2 = hit["position"]
		points.append(hit_pos)
		remaining -= pos.distance_to(hit_pos)
		if remaining <= 0.0:
			break
		var normal: Vector2 = hit["normal"]
		dir = dir.bounce(normal)
		pos = hit_pos + normal * 0.5   # step off the wall so we don't hit it again

	# hurt every enemy the beam passes through (each one only once per shot)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		for i in points.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, points[i], points[i + 1])
			if closest.distance_to(enemy.global_position) < enemy.body_radius + beam_width * 0.5:
				var push := (points[i + 1] - points[i]).normalized() * 200.0
				enemy.take_damage(damage(), push)
				break

	beam_points = points
	beam_fade = beam_time


func _draw() -> void:
	if beam_fade <= 0.0 or beam_points.size() < 2:
		return
	var a: float = beam_fade / beam_time
	draw_polyline(beam_points, Color(color, 0.35 * a), beam_width * 2.5)   # glow
	draw_polyline(beam_points, Color(color, a), beam_width)
	draw_polyline(beam_points, Color(1, 1, 1, a), beam_width * 0.35)     # hot core
