extends CharacterBody2D

signal caught

@export var return_speed = 700.0
@export var return_accel = 2500.0
@export var catch_radius = 28.0
@export var spin_speed = 20.0      # radians per second, just for looks
@export var catch_only_when_returning = true  # false = you can also grab it mid-flight

var thrower
var damage: int = 1
var max_bounces: int = 3
var bounces: int = 0
var returning: bool = false
var catch_delay: float = 0.2       # can't be caught right after throwing


func throw(player, start_velocity: Vector2) -> void:
	thrower = player
	global_position = player.global_position
	damage = player.disk_damage
	max_bounces = player.disk_bounces
	velocity = start_velocity


func _physics_process(delta: float) -> void:
	if not is_instance_valid(thrower):
		queue_free()
		return

	catch_delay -= delta
	$Sprite2D.rotation += spin_speed * delta

	if returning:
		# fly back to the player, ignoring walls
		# always faster than you, so it can catch up even at crazy speeds
		var chase: float = max(return_speed, thrower.velocity.length() + 300.0)
		var to_player: Vector2 = (thrower.global_position - global_position).normalized()
		velocity = velocity.move_toward(to_player * chase, max(return_accel, chase * 3.5) * delta)
		global_position += velocity * delta
	else:
		var collision := move_and_collide(velocity * delta)
		if collision:
			var body = collision.get_collider()
			if body and body.is_in_group("enemies"):
				body.take_damage(damage, velocity.normalized() * 300.0)
			velocity = velocity.bounce(collision.get_normal())
			bounces += 1
			if bounces > max_bounces:
				returning = true

	# catch it by touching it
	var can_catch := returning or not catch_only_when_returning
	var reach: float = catch_radius + (velocity.length() + thrower.velocity.length()) * delta   # don't fly past at high speed
	if can_catch and catch_delay <= 0.0 and global_position.distance_to(thrower.global_position) < reach:
		caught.emit()
		queue_free()
