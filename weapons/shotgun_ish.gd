extends Node2D
# shotgun-ish. sprays pellets at the closest enemy, they bounce off walls a few times
# so even if u miss they can come back n hit smth

const Boing = preload("res://weapons/boing_math.gd")

@export var pellet_speed = 720.0
@export var spread = 40.0           # degrees, whole fan
@export var pellet_life = 1.6
@export var color = Color(0.7, 1.0, 0.4)

var level: int = 1
var player
var timer: float = 0.7
var pellets = []   # each: {"pos", "vel", "life", "bounces"}


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5


func level_up() -> void:
	level += 1


func cooldown() -> float:
	return max(0.7, 1.9 - 0.15 * level)


func pellet_count() -> int:
	return 3 + level                     # 4..11


func max_bounces() -> int:
	return 1 + level / 2                 # 1, 2, 2, 3, 3, 4, 4, 5


func damage() -> int:
	return 1 + level / 4 + player.weapon_damage_bonus


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var space := get_world_2d().direct_space_state

	timer -= delta
	if timer <= 0.0:
		var target = Boing.nearest_enemy(get_tree(), player.global_position, 700.0)
		if target:
			timer = cooldown()
			var aim: Vector2 = (target.global_position - player.global_position).normalized()
			var n := pellet_count()
			for i in n:
				var t: float = (i / float(n - 1) - 0.5) if n > 1 else 0.0
				var dir := aim.rotated(deg_to_rad(spread) * t + randf_range(-0.05, 0.05))
				pellets.append({"pos": player.global_position, "vel": dir * pellet_speed * randf_range(0.9, 1.1), "life": pellet_life, "bounces": max_bounces()})
		else:
			timer = 0.2

	for i in range(pellets.size() - 1, -1, -1):
		var pel = pellets[i]
		pel["life"] -= delta
		var res := Boing.step(space, pel["pos"], pel["vel"], delta)
		pel["pos"] = res[0]
		pel["vel"] = res[1]
		pel["bounces"] -= res[2]
		var done: bool = pel["life"] <= 0.0 or pel["bounces"] < 0
		if not done:
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if enemy.global_position.distance_to(pel["pos"]) < 4.0 + enemy.body_radius:
					enemy.take_damage(damage(), pel["vel"].normalized() * 150.0)
					done = true          # pellets stop at the first enemy they hit
					break
		if done:
			pellets.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for pel in pellets:
		var tail: Vector2 = pel["pos"] - pel["vel"].normalized() * 10.0
		draw_line(tail, pel["pos"], color, 3.0)
