extends Node2D
# While you're moving fast, drops mines behind you. A mine blows up when an
# enemy gets close, hurting everything in the blast. Rewards drifting around.

@export var min_drop_speed = 220.0  # you must be going at least this fast to drop mines
@export var arm_time = 0.4          # mines can't go off right after being dropped
@export var lifetime = 12.0         # unused mines fizzle out after this long
@export var trigger_radius = 26.0
@export var color = Color(1.0, 0.55, 0.15)

var level: int = 1
var player
var drop_timer: float = 0.0
var mines = []                      # each: {"pos": Vector2, "age": float}
var booms = []                      # each: {"pos": Vector2, "r": float, "age": float}


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 4


func level_up() -> void:
	level += 1


func drop_interval() -> float:
	return max(0.25, 0.75 - 0.1 * level)


func max_mines() -> int:
	return 3 + 2 * level            # 5..19 on the field at once


func blast_radius() -> float:
	return 55.0 + 12.0 * level


func damage() -> int:
	return 2 + level / 2 + player.weapon_damage_bonus    # 2, 3, 3, 4, 4, 5, 5, 6 (+ Overcharge)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	# drop a new mine
	drop_timer -= delta
	if drop_timer <= 0.0 and player.velocity.length() >= min_drop_speed:
		drop_timer = drop_interval()
		mines.append({"pos": player.global_position, "age": 0.0})
		if mines.size() > max_mines():
			mines.pop_front()       # too many: the oldest one disappears

	# age mines, and set off any with an enemy close by
	var enemies := get_tree().get_nodes_in_group("enemies")
	for i in range(mines.size() - 1, -1, -1):
		var mine = mines[i]
		mine["age"] += delta
		if mine["age"] > lifetime:
			mines.remove_at(i)
			continue
		if mine["age"] < arm_time:
			continue
		for enemy in enemies:
			if enemy.global_position.distance_to(mine["pos"]) < trigger_radius + enemy.body_radius:
				explode(mine["pos"], enemies)
				mines.remove_at(i)
				break

	for i in range(booms.size() - 1, -1, -1):
		booms[i]["age"] += delta
		if booms[i]["age"] > 0.3:
			booms.remove_at(i)
	queue_redraw()


func explode(pos: Vector2, enemies: Array) -> void:
	var r := blast_radius()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var away: Vector2 = enemy.global_position - pos
		if away.length() < r + enemy.body_radius:
			enemy.take_damage(damage(), away.normalized() * 400.0)
	booms.append({"pos": pos, "r": r, "age": 0.0})
	get_tree().call_group("camera", "add_shake", 5.0)


func _draw() -> void:
	for mine in mines:
		var armed: bool = mine["age"] >= arm_time
		var blink: float = 1.0 if fmod(mine["age"], 0.6) < 0.3 else 0.45
		draw_circle(mine["pos"], 7.0, Color(0.15, 0.15, 0.15))
		draw_circle(mine["pos"], 3.5, Color(color, blink if armed else 0.3))
	for boom in booms:
		var t: float = boom["age"] / 0.3
		draw_circle(boom["pos"], boom["r"] * (0.4 + 0.6 * t), Color(color, 0.45 * (1.0 - t)))
		draw_arc(boom["pos"], boom["r"] * (0.4 + 0.6 * t), 0.0, TAU, 48, Color(1, 0.9, 0.6, 1.0 - t), 3.0)
