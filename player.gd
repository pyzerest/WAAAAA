extends CharacterBody2D

signal died
signal stats_changed   # health or disk count changed -> HUD refreshes
signal bounced         # did a wall bounce (the tutorial listens for this)

const WeaponList = preload("res://weapons/weapon_list.gd")

# oh yeah its mr driftin it
@export var max_speed = 500.0
@export var speeeeee = 1300.0       # acceleration (px/s²)
@export var friction = 400.0
@export var slow_tf_down = 950.0    # must stay bigger than (speeeeee - friction) = 900

# ADAMS BOUNCING ON IT
@export var wall_bounce = 350.0
@export var wall_friction = 0.9
@export var cooldown = 0.12         # grace window after touching a wall (0.12 s ≈ 7 frames)
@export var into_wall_tolerance = 0.0  # 0 = any push into the wall blocks the bounce

# Health
@export var max_health = 5
@export var invincible_time = 0.6

# Ramming: drive into an enemy fast enough and IT takes the damage, not you
@export var ram_speed = 430.0       # how fast you must be going to dash-kill (max_speed is 500)
@export var ram_damage = 2          # +1 more for every 100 px/s above ram_speed
@export var ram_knockback = 450.0
@export var ram_grace = 0.3         # seconds you stay safe right after a ram (you slow down on impact)

# Disk
@export var disk_scene: PackedScene
@export var disk_damage = 1
@export var disk_bounces = 3
@export var disk_speed = 600.0
@export var disk_inherit = 0.5
@export var disk_count = 1          # how many disks you own
@export var throw_count = 1         # how many disks one click throws (spread)
@export var spread_angle = 12.0     # degrees between disks in one throw

var wall_normal: Vector2 = Vector2.ZERO
var wall_timer: float = 0.0
var health: int = 0
var invincible_timer: float = 0.0
var disks_available: int = 1
var weapons = {}       # extra weapons you've picked up: id -> weapon node (see weapons/)
var weapon_damage_bonus: int = 0   # from the Overcharge upgrade, added to every extra weapon
var ram_timer: float = 0.0
var recently_rammed = {}           # enemy -> seconds before you can ram it again

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	health = max_health
	disks_available = disk_count
	add_to_group("player")


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("democratic", "conservative", "were going up up up its our moment", "hell")

	# Drift movement
	velocity += direction * speeeeee * delta
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)

	if velocity.length() > max_speed:
		velocity = velocity.move_toward(velocity.limit_length(max_speed), slow_tf_down * delta)

	# Wall bounce (blocked if you're pushing into the wall)
	wall_timer -= delta
	if Input.is_action_just_pressed("bounce") and wall_timer > 0.0 and direction.dot(wall_normal) >= -into_wall_tolerance:
		if velocity.dot(wall_normal) < 0.0:
			velocity = velocity.bounce(wall_normal)
		velocity = velocity * wall_friction + wall_normal * wall_bounce
		wall_timer = 0.0
		bounced.emit()

	# Invincibility flicker
	invincible_timer -= delta
	if invincible_timer > 0.0:
		sprite.visible = fmod(invincible_timer, 0.1) < 0.05
	else:
		sprite.visible = true

	var velocity_before := velocity
	move_and_slide()
	ram_enemies(velocity_before, delta)

	if is_on_wall():
		wall_normal = get_wall_normal()
		wall_timer = cooldown

	# Aim and throw
	var dirs := throw_directions()
	if Input.is_action_just_pressed("throw") and dirs.size() > 0:
		throw_disks(dirs)


# ---------- Disks ----------

func throw_directions() -> Array:
	# one direction per disk in this throw, fanned out around the mouse
	var n: int = min(throw_count, disks_available)
	var aim := (get_global_mouse_position() - global_position).normalized()
	var dirs = []
	for i in n:
		var offset := (i - (n - 1) / 2.0) * deg_to_rad(spread_angle)
		dirs.append(aim.rotated(offset))
	return dirs


func disk_velocity(dir: Vector2) -> Vector2:
	return dir * disk_speed + velocity * disk_inherit


func throw_disks(dirs: Array) -> void:
	if disk_scene == null:
		push_warning("Drag weapon.tscn into the Player's Disk Scene slot!")
		return
	for dir in dirs:
		var disk = disk_scene.instantiate()
		get_parent().add_child(disk)
		disk.throw(self, disk_velocity(dir))
		disk.caught.connect(_on_disk_caught)
		disks_available -= 1
	stats_changed.emit()


func _on_disk_caught() -> void:
	disks_available = min(disks_available + 1, disk_count)
	stats_changed.emit()


func add_disk() -> void:
	disk_count += 1
	disks_available += 1
	stats_changed.emit()


# ---------- Extra weapons ----------

func weapon_level(id: String) -> int:
	return weapons[id].level if weapons.has(id) else 0


func add_weapon(id: String) -> void:
	# first pick gives you the weapon, every pick after that levels it up
	if weapons.has(id):
		weapons[id].level_up()
	else:
		var weapon = WeaponList.WEAPONS[id]["script"].new()
		weapon.name = id
		add_child(weapon)
		weapons[id] = weapon
	stats_changed.emit()


func weapon_summary() -> String:
	var parts := PackedStringArray()
	for id in weapons:
		parts.append("%s %d" % [WeaponList.WEAPONS[id]["name"], weapons[id].level])
	return "    ".join(parts)


# ---------- Ramming ----------

func can_ram() -> bool:
	return velocity.length() >= ram_speed


func is_ramming_into(enemy) -> bool:
	# fast enough AND heading roughly at the enemy (not just getting caught from behind)
	if ram_timer > 0.0:
		return true
	var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
	return can_ram() and velocity.normalized().dot(to_enemy) > 0.3


func ram_enemies(velocity_before: Vector2, delta: float) -> void:
	ram_timer -= delta
	for enemy in recently_rammed.keys():
		recently_rammed[enemy] -= delta
		if recently_rammed[enemy] <= 0.0 or not is_instance_valid(enemy):
			recently_rammed.erase(enemy)

	var speed := velocity_before.length()
	if speed < ram_speed:
		return
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var enemy = hit.get_collider()
		if enemy == null or not enemy.is_in_group("enemies") or recently_rammed.has(enemy):
			continue
		var to_enemy: Vector2 = (enemy.global_position - global_position).normalized()
		if velocity_before.normalized().dot(to_enemy) <= 0.3:
			continue   # just scraped it sideways
		var dmg: int = ram_damage + int((speed - ram_speed) / 100.0)
		enemy.take_damage(dmg, velocity_before.normalized() * ram_knockback)
		recently_rammed[enemy] = 0.3
		ram_timer = ram_grace
		get_tree().call_group("camera", "add_shake", 6.0)
		if enemy.knockback_resist >= 0.5:
			# big heavy shapes: you bounce off them
			velocity = velocity_before.bounce(hit.get_normal()) * 0.6
		else:
			# small fry: plow straight through
			velocity = velocity_before * 0.85


# ---------- Health ----------

func take_damage(amount: int, source = null) -> void:
	if invincible_timer > 0.0:
		return
	if source != null and is_instance_valid(source) and is_ramming_into(source):
		return   # you hit them, not the other way round
	health -= amount
	invincible_timer = invincible_time
	get_tree().call_group("camera", "add_shake", 8.0)
	stats_changed.emit()
	if health <= 0:
		died.emit()
