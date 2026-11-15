extends Node2D
# Throws boomerangs at the nearest enemy. They ricochet off walls on the way
# out, then fly back to you (through walls), cutting everything both ways.

const Bounce = preload("res://weapons/bounce_physics.gd")

@export var throw_speed = 560.0
@export var return_speed = 650.0
@export var return_accel = 1800.0
@export var hit_radius = 12.0
@export var color = Color(1.0, 0.6, 0.2)

var level: int = 1
var player
var timer: float = 0.8
var rangs = []   # each: {"pos", "vel", "age", "back": bool, "hit": {enemy: cooldown}}


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5


func level_up() -> void:
	level += 1


func cooldown() -> float:
	return max(0.8, 2.4 - 0.2 * level)


func count() -> int:
	return 1 + (level - 1) / 2           # 1, 1, 2, 2, 3, 3, 4, 4


func out_time() -> float:
	return 0.6 + 0.06 * level            # how long before it turns around


func damage() -> int:
	return 1 + (level - 1) / 2 + player.weapon_damage_bonus


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var space := get_world_2d().direct_space_state

	timer -= delta
	if timer <= 0.0:
		var target = Bounce.nearest_enemy(get_tree(), player.global_position, 800.0)
		if target:
			var aim: Vector2 = (target.global_position - player.global_position).normalized()
			var n := count()
			for i in n:
				var dir := aim.rotated((i - (n - 1) / 2.0) * 0.35)
				rangs.append({"pos": player.global_position, "vel": dir * throw_speed, "age": 0.0, "back": false, "hit": {}})
			timer = cooldown()
		else:
			timer = 0.2

	for i in range(rangs.size() - 1, -1, -1):
		var r = rangs[i]
		r["age"] += delta
		if not r["back"]:
			var res := Bounce.step(space, r["pos"], r["vel"], delta)
			r["pos"] = res[0]
			r["vel"] = res[1]
			if r["age"] >= out_time():
				r["back"] = true
				r["hit"] = {}               # can hit the same enemies again on the way back
		else:
			var to_player: Vector2 = (player.global_position - r["pos"]).normalized()
			var chase: float = max(return_speed, player.velocity.length() + 250.0)   # keeps up with you at any speed
			r["vel"] = r["vel"].move_toward(to_player * chase, max(return_accel, chase * 3.0) * delta)
			r["pos"] += r["vel"] * delta
			if r["pos"].distance_to(player.global_position) < 24.0 + chase * delta or r["age"] > 6.0:
				rangs.remove_at(i)
				continue
		hit_enemies(r, delta)
	queue_redraw()


func hit_enemies(r: Dictionary, delta: float) -> void:
	for enemy in r["hit"].keys():
		r["hit"][enemy] -= delta
		if r["hit"][enemy] <= 0.0:
			r["hit"].erase(enemy)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if r["hit"].has(enemy):
			continue
		if enemy.global_position.distance_to(r["pos"]) < hit_radius + enemy.body_radius:
			enemy.take_damage(damage(), r["vel"].normalized() * 220.0)
			r["hit"][enemy] = 0.4


func _draw() -> void:
	for r in rangs:
		# a spinning V shape
		var spin: float = r["age"] * 18.0
		var a := Vector2.from_angle(spin) * 11.0
		var b := Vector2.from_angle(spin + 1.9) * 11.0
		draw_line(r["pos"] + a, r["pos"], color, 4.0)
		draw_line(r["pos"], r["pos"] + b, color, 4.0)
