extends CharacterBody2D

signal died

@export var speed = 120.0     # chase speed (px/s)
@export var accel = 400.0     # how fast it turns/recovers (px/s²)
@export var max_health = 2
@export var xp_value = 1     # XP the player gets for killing this enemy
@export var contact_damage = 1  # HP the player loses when this enemy touches them
@export var separation = 120.0  # how hard enemies push away from each other (px/s)
@export var separation_radius = 30.0
@export var death_color = Color(0.93, 0.11, 0.14)  # colour of the little squares it bursts into
@export var knockback_resist = 0.0  # 0 = gets shoved around fully, 1 = can't be pushed at all
@export var is_boss = false         # the big shapes: always show a health bar + their own arrow
@export var boss_name = ""          # shown on screen when it spawns
@export var spin = 0.0              # sprite spin speed (radians/s), just for looks

var health: int = 0
var player
var body_radius: float = 11.0   # weapons use this for hit checks (set from the collision shape)
var tint: Color = Color.WHITE   # stronger enemies get redder
var elite: bool = false


func _ready() -> void:
	health = max_health
	add_to_group("enemies")
	player = get_tree().get_first_node_in_group("player")
	$Sprite2D.modulate = tint
	if elite:
		# bigger body: copy the shape first, otherwise every enemy would grow
		var shape: CircleShape2D = $CollisionShape2D.shape.duplicate()
		shape.radius *= 1.6
		$CollisionShape2D.shape = shape
		$Sprite2D.scale *= 1.6
		separation_radius *= 1.6
	body_radius = $CollisionShape2D.shape.radius


# Called by the world before the enemy is added. threat goes up over time:
# 0 at the start, +1 every minute (see world.gd).
func power_up(threat: float, make_elite: bool) -> void:
	var hp_growth: float = 0.35 if is_boss else 0.5   # bosses start huge, so they grow a bit slower
	max_health = int(round(max_health * (1.0 + hp_growth * threat)))
	contact_damage += int(threat / 4.0)
	xp_value += int(threat / 3.0)
	speed += 8.0 * threat
	tint = Color.WHITE.lerp(Color(1.0, 0.3, 0.3), clamp(threat / 8.0, 0.0, 1.0))
	if make_elite:
		elite = true
		max_health *= 4
		contact_damage += 1
		xp_value *= 5
		speed *= 0.75
		tint = Color(0.75, 0.4, 1.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	if spin != 0.0:
		$Sprite2D.rotation += spin * delta

	# follow the maze if the world can path for us, otherwise go straight at the player
	var dir: Vector2
	var world = get_parent()
	if world.has_method("chase_direction"):
		dir = world.chase_direction(global_position)
	else:
		dir = (player.global_position - global_position).normalized()
	# gently push away from enemies that are overlapping us (they don't collide with each other)
	var push := Vector2.ZERO
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self:
			var away: Vector2 = global_position - other.global_position
			var d := away.length()
			if d > 0.0 and d < separation_radius:
				push += away / d * (1.0 - d / separation_radius)
	velocity = velocity.move_toward(dir * speed + push * separation, accel * delta)
	move_and_slide()

	for i in get_slide_collision_count():
		if get_slide_collision(i).get_collider() == player:
			player.take_damage(contact_damage, self)


func take_damage(amount: int, knockback: Vector2) -> void:
	if health <= 0:
		return   # already dying (two disks hit on the same frame)
	# white hit flash
	modulate = Color(8, 8, 8)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

	get_tree().call_group("camera", "add_shake", 3.0)

	health -= amount
	velocity = knockback * (1.0 - knockback_resist)
	queue_redraw()   # update the health bar
	if health <= 0:
		remove_from_group("enemies")   # so weapons and arrows stop targeting it right away
		burst_into_squares()
		get_tree().call_group("camera", "add_shake", 5.0)
		died.emit()
		queue_free()


func burst_into_squares() -> void:
	# a one-shot spray of tiny squares, left behind in the world after the enemy is gone
	var p := CPUParticles2D.new()
	p.position = position               # same parent as us (the world), so same coordinates
	p.z_index = 3
	p.amount = 70 if is_boss else 18
	p.one_shot = true
	p.explosiveness = 1.0               # all at once
	p.lifetime = 0.9 if is_boss else 0.6
	p.direction = Vector2.RIGHT
	p.spread = 180.0                    # every direction
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 420.0 if is_boss else 260.0
	p.damping_min = 250.0               # slow down as they fly
	p.damping_max = 400.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 3.0            # no texture = squares this many pixels wide
	p.scale_amount_max = 5.0
	var fade := Gradient.new()
	fade.set_color(0, death_color * tint)
	fade.set_color(1, Color(death_color * tint, 0.0))
	p.color_ramp = fade
	p.finished.connect(p.queue_free)
	get_parent().add_child(p)
	p.emitting = true


func _draw() -> void:
	# small health bar once the enemy has been hurt (bosses always show theirs)
	if health <= 0 or (health >= max_health and not is_boss):
		return
	var w: float = body_radius * (3.0 if is_boss else 2.2)
	var h: float = 6.0 if is_boss else 4.0
	var top := Vector2(-w / 2.0, -body_radius * (1.8 if is_boss else 1.0) - 14.0)
	draw_rect(Rect2(top, Vector2(w, h)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(top, Vector2(w * health / max_health, h)), Color(1.0, 0.3, 0.3))
