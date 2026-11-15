extends Node2D
# Every time you wall-bounce (SPACE against a wall), a fan of shards blasts off
# the wall with you. The shards ricochet around and pierce enemies.

const Bounce = preload("res://weapons/bounce_physics.gd")

@export var shard_speed = 650.0
@export var fan = 140.0             # degrees, whole fan around the wall's direction
@export var shard_life = 1.2
@export var min_gap = 0.25          # seconds between bursts, so spamming can't flood the screen
@export var color = Color(0.4, 0.8, 1.0)

var level: int = 1
var player
var gap_timer: float = 0.0
var shards = []   # each: {"pos", "vel", "life", "bounces", "hit": {enemy: true}}


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5
	player.bounced.connect(_on_player_bounced)


func level_up() -> void:
	level += 1


func shard_count() -> int:
	return 4 + 2 * level                 # 6..20


func max_bounces() -> int:
	return 1 + level / 3                 # 1, 1, 2, 2, 2, 3, 3, 3


func damage() -> int:
	return 1 + level / 2 + player.weapon_damage_bonus


func _on_player_bounced() -> void:
	if gap_timer > 0.0:
		return
	gap_timer = min_gap
	var n := shard_count()
	for i in n:
		var t: float = i / float(n - 1) - 0.5
		var dir: Vector2 = player.wall_normal.rotated(deg_to_rad(fan) * t)
		shards.append({"pos": player.global_position, "vel": dir * shard_speed, "life": shard_life, "bounces": max_bounces(), "hit": {}})
	get_tree().call_group("camera", "add_shake", 4.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	gap_timer -= delta
	var space := get_world_2d().direct_space_state
	for i in range(shards.size() - 1, -1, -1):
		var sh = shards[i]
		sh["life"] -= delta
		var res := Bounce.step(space, sh["pos"], sh["vel"], delta)
		sh["pos"] = res[0]
		sh["vel"] = res[1]
		sh["bounces"] -= res[2]
		if sh["life"] <= 0.0 or sh["bounces"] < 0:
			shards.remove_at(i)
			continue
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if sh["hit"].has(enemy):
				continue
			if enemy.global_position.distance_to(sh["pos"]) < 5.0 + enemy.body_radius:
				enemy.take_damage(damage(), sh["vel"].normalized() * 200.0)
				sh["hit"][enemy] = true   # pierces: each shard hits each enemy once
	queue_redraw()


func _draw() -> void:
	for sh in shards:
		var a: float = clamp(sh["life"] / 0.3, 0.0, 1.0)
		var dir: Vector2 = sh["vel"].normalized()
		var pts := PackedVector2Array([sh["pos"] + dir * 7.0, sh["pos"] + dir.orthogonal() * 3.0, sh["pos"] - dir * 6.0, sh["pos"] - dir.orthogonal() * 3.0])
		draw_colored_polygon(pts, Color(color, a))
