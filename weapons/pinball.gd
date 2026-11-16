extends Node2D
# shoots steel pinballs that bounce off walls AND enemies for a few secs
# rlly good in long corridors, they just rattle back n forth hitting everything

const Boing = preload("res://weapons/boing_math.gd")

@export var ball_speed = 480.0
@export var ball_radius = 7.0
@export var color = Color(0.85, 0.9, 1.0)

var level: int = 1
var player
var timer: float = 1.0
var balls = []   # each: {"pos", "vel", "life", "hit": {enemy: cooldown}}


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5


func level_up() -> void:
	level += 1


func cooldown() -> float:
	return max(1.0, 3.0 - 0.25 * level)


func balls_per_launch() -> int:
	return 1 + level / 3                 # 1, 1, 2, 2, 2, 3, 3, 3


func lifetime() -> float:
	return 3.0 + 0.5 * level


func max_balls() -> int:
	return 3 + 2 * level


func damage() -> int:
	return 1 + level / 3 + player.weapon_damage_bonus


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var space := get_world_2d().direct_space_state

	timer -= delta
	if timer <= 0.0:
		timer = cooldown()
		for i in balls_per_launch():
			if balls.size() >= max_balls():
				balls.pop_front()        # oldest ball drops out
			var dir := Vector2.from_angle(randf() * TAU)
			balls.append({"pos": player.global_position, "vel": dir * ball_speed, "life": lifetime(), "hit": {}})

	for i in range(balls.size() - 1, -1, -1):
		var ball = balls[i]
		ball["life"] -= delta
		if ball["life"] <= 0.0:
			balls.remove_at(i)
			continue
		var res := Boing.step(space, ball["pos"], ball["vel"], delta)
		ball["pos"] = res[0]
		ball["vel"] = res[1]

		for enemy in ball["hit"].keys():
			ball["hit"][enemy] -= delta
			if ball["hit"][enemy] <= 0.0:
				ball["hit"].erase(enemy)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if ball["hit"].has(enemy):
				continue
			var away: Vector2 = ball["pos"] - enemy.global_position
			if away.length() < ball_radius + enemy.body_radius:
				enemy.take_damage(damage(), -away.normalized() * 180.0)
				ball["hit"][enemy] = 0.3
				# bounce off the enemy like a pinball bumper
				ball["vel"] = ball["vel"].bounce(away.normalized())
				if ball["vel"].dot(away) < 0.0:
					ball["vel"] = away.normalized() * ball_speed
				break
	queue_redraw()


func _draw() -> void:
	for ball in balls:
		var fade: float = clamp(ball["life"] / 0.5, 0.0, 1.0)   # fade out at the end
		draw_circle(ball["pos"], ball_radius, Color(0.45, 0.5, 0.6, fade))
		draw_circle(ball["pos"], ball_radius * 0.75, Color(color, fade))
		draw_circle(ball["pos"] + Vector2(-2, -2), ball_radius * 0.3, Color(1, 1, 1, fade))
