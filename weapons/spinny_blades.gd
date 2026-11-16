extends Node2D
# blades spinning around u, hurts anything they touch

@export var orbit_radius = 85.0
@export var blade_size = 10.0
@export var hit_cooldown = 0.35   # secs before the same enemy can be hit again
@export var color = Color(0.4, 0.95, 1.0)

var level: int = 1
var player
var angle: float = 0.0
var recently_hit = {}             # enemy -> secs until it can be hit again


func _ready() -> void:
	player = get_parent()
	top_level = true              # draw in world coordinates
	z_index = 5


func level_up() -> void:
	level += 1


func blade_count() -> int:
	return 1 + level              # 2 .. 9


func spin_speed() -> float:
	return 2.6 + 0.35 * level     # radians per sec


func damage() -> int:
	return 1 + (level - 1) / 2 + player.weapon_damage_bonus    # 1, 1, 2, 2, 3, 3, 4, 4 (+ overcharge)


func blade_positions() -> Array:
	var points = []
	var n := blade_count()
	for i in n:
		var a := angle + TAU * i / n
		points.append(player.global_position + Vector2.from_angle(a) * orbit_radius)
	return points


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	angle = wrapf(angle + spin_speed() * delta, 0.0, TAU)

	# tick down the per-enemy cooldowns
	for enemy in recently_hit.keys():
		recently_hit[enemy] -= delta
		if recently_hit[enemy] <= 0.0 or not is_instance_valid(enemy):
			recently_hit.erase(enemy)

	var blades := blade_positions()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if recently_hit.has(enemy):
			continue
		for blade in blades:
			if enemy.global_position.distance_to(blade) < blade_size + enemy.body_radius:
				var away: Vector2 = (enemy.global_position - player.global_position).normalized()
				enemy.take_damage(damage(), away * 250.0)
				recently_hit[enemy] = hit_cooldown
				break
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(player):
		return
	draw_arc(player.global_position, orbit_radius, 0.0, TAU, 64, Color(color, 0.12), 2.0)
	for blade in blade_positions():
		# a little spinning shuriken: 4 points
		var pts := PackedVector2Array()
		for k in 8:
			var r: float = blade_size if k % 2 == 0 else blade_size * 0.4
			pts.append(blade + Vector2.from_angle(angle * 3.0 + k * TAU / 8.0) * r)
		draw_colored_polygon(pts, color)
