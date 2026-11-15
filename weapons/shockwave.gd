extends Node2D
# Every few seconds a ring blasts out from you, hurting enemies and shoving
# them away. Great for when you get surrounded.

@export var expand_time = 0.3     # seconds for the ring to reach full size
@export var knockback = 550.0
@export var color = Color(0.6, 0.7, 1.0)

var level: int = 1
var player
var timer: float = 2.0
var wave_center: Vector2
var wave_age: float = -1.0        # < 0 means no ring active
var hit = []                      # enemies this ring already hit


func _ready() -> void:
	player = get_parent()
	top_level = true
	z_index = 5


func level_up() -> void:
	level += 1


func cooldown() -> float:
	return max(1.5, 4.0 - 0.45 * level)


func max_radius() -> float:
	return 90.0 + 25.0 * level


func damage() -> int:
	return 1 + level / 2 + player.weapon_damage_bonus    # 1, 2, 2, 3, 3, 4, 4, 5 (+ Overcharge)


func current_radius() -> float:
	return max_radius() * clamp(wave_age / expand_time, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	timer -= delta
	if timer <= 0.0:
		timer = cooldown()
		wave_center = player.global_position
		wave_age = 0.0
		hit = []
		get_tree().call_group("camera", "add_shake", 4.0)

	if wave_age >= 0.0:
		wave_age += delta
		wave_center = player.global_position   # the ring follows you
		var r := current_radius()
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if hit.has(enemy):
				continue
			var away: Vector2 = enemy.global_position - wave_center
			if away.length() < r + enemy.body_radius:
				enemy.take_damage(damage(), away.normalized() * knockback)
				hit.append(enemy)
		if wave_age > expand_time + 0.15:
			wave_age = -1.0
	queue_redraw()


func _draw() -> void:
	if wave_age < 0.0:
		return
	var a: float = 1.0 - clamp((wave_age - expand_time) / 0.15, 0.0, 1.0)
	var r := current_radius()
	draw_circle(wave_center, r, Color(color, 0.12 * a))
	draw_arc(wave_center, r, 0.0, TAU, 64, Color(color, 0.9 * a), 4.0)
