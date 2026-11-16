extends CharacterBody2D

signal died
signal stats_changed   # health or disk count changed -> HUD refreshes
signal bounced         # did a wall bounce (the tutorial listens for this)

const AllDaWeapons = preload("res://weapons/all_da_weapons.gd")

# oh yeah its mr driftin it
# NO top speed. u get to cruise speed (max_speed) quick, then holding forward
# keeps making u faster forever, just slower (overdrive)
@export var max_speed = 650.0       # cruise speed: where the quick acceleration stops
@export var speeeeee = 1700.0       # acceleration (px/s²) below cruise speed, n for steering/braking
@export var overdrive = 700.0       # forward acceleration past cruise speed (friction eats 400 of it)
@export var friction = 400.0

# ADAMS BOUNCING ON IT
@export var wall_bounce = 350.0
@export var wall_friction = 0.9
@export var cooldown = 0.12         # grace window after touching a wall (0.12 s ≈ 7 frames)
@export var into_wall_tolerance = 0.0  # 0 = any push into the wall blocks the bounce

# health
@export var max_health = 5
@export var invincible_time = 0.6

# ramming: drive into an enemy fast enough n IT takes the damage, not u
# damage grows w the SQUARE of ur speed: 2x as fast = 4x the damage
#   ram_speed 3 dmg-ish at cruise 650, ~9 at 1200, ~14 at 1500, ~26 at 2000...
@export var ram_speed = 560.0       # how fast u must be gonna dash-kill (cruise speed is 650)
@export var ram_damage = 2          # damage at exactly ram_speed
@export var ram_knockback = 450.0   # also grows w speed
@export var ram_grace = 0.3         # secs u stay safe right after a ram (u slow down on impact)
@export var sonic_speed = 1400.0    # SONIC RAM: above this a ram also blasts everything around the hit
@export var sonic_radius = 140.0

# disk
@export var disk_scene: PackedScene
@export var disk_damage = 1
@export var disk_bounces = 3
@export var disk_speed = 600.0
@export var disk_inherit = 0.5
@export var disk_count = 1          # how many disks u own
@export var throw_count = 1         # how many disks one click throws (spread)
@export var spread_angle = 12.0     # degrees between disks in one throw

var wall_normal: Vector2 = Vector2.ZERO
var wall_timer: float = 0.0
var health: int = 0
var invincible_timer: float = 0.0
var disks_available: int = 1
var weapons = {}       # extra weapons uve picked up: id -> weapon node (see weapons/)
var weapon_damage_bonus: int = 0   # from the overcharge upgrade, added to every extra weapon
var ram_timer: float = 0.0
var recently_rammed = {}           # enemy -> secs before u can ram it again

@onready var sprite: Sprite2D = $Sprite2D
var trail: Line2D
var engine: AudioStreamPlayer
var last_dir: Vector2 = Vector2.RIGHT


func _ready() -> void:
	health = max_health
	disks_available = disk_count
	add_to_group("player")

	# speed trail behind u (in world space, so it stays where u were)
	trail = Line2D.new()
	trail.top_level = true
	trail.z_index = -1
	trail.width = 14.0
	trail.width_curve = Curve.new()
	trail.width_curve.add_point(Vector2(0, 0))
	trail.width_curve.add_point(Vector2(1, 1))
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)

	# engine hum: pitch follows ur speed
	engine = AudioStreamPlayer.new()
	engine.stream = Noises.engine_stream()
	engine.volume_db = -30.0
	add_child(engine)
	if engine.stream:
		engine.play()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("democratic", "conservative", "were going up up up its our moment", "hell")

	# drift movement (no speed cap!)
	var thrust: Vector2 = direction * speeeeee
	var speed: float = velocity.length()
	if speed > max_speed:
		# past cruise speed, only the part of ur push thats straight ahead gets weaker -
		# steering n braking keep full strength, so u can still drift at any speed
		var heading: Vector2 = velocity / speed
		var forward: float = thrust.dot(heading)
		if forward > 0.0:
			thrust -= heading * forward * (1.0 - overdrive / speeeeee)
	velocity += thrust * delta
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if direction != Vector2.ZERO:
		last_dir = direction.normalized()

	# wall bounce (blocked if ur pushing into the wall)
	wall_timer -= delta
	if Input.is_action_just_pressed("bounce") and wall_timer > 0.0 and direction.dot(wall_normal) >= -into_wall_tolerance:
		if velocity.dot(wall_normal) < 0.0:
			velocity = velocity.bounce(wall_normal)
		velocity = velocity * wall_friction + wall_normal * wall_bounce
		wall_timer = 0.0
		bounced.emit()
		Noises.play("boing", 0.9 + randf() * 0.2)

	# invincibility flicker
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

	# aim n throw
	var dirs := throw_directions()
	if Input.is_action_just_pressed("throw") and dirs.size() > 0:
		throw_disks(dirs)

	update_trail_and_engine(delta)


func update_trail_and_engine(_delta: float) -> void:
	var speed := velocity.length()
	trail.add_point(global_position)
	while trail.get_point_count() > 16:
		trail.remove_point(0)
	var col := Color(0.3, 0.9, 1.0)
	if speed >= sonic_speed:
		col = Color(0.85, 0.4, 1.0)
	elif can_ram():
		col = Color(1.0, 0.55, 0.15)
	col.a = clamp((speed - 300.0) / 600.0, 0.0, 0.7)
	trail.default_color = col
	trail.width = 10.0 + min(speed, 3000.0) / 150.0
	if engine.stream:
		engine.pitch_scale = clamp(0.55 + speed / 750.0, 0.5, 4.0)
		engine.volume_db = lerp(-30.0, -14.0, clamp(speed / 1500.0, 0.0, 1.0))


func boost(amount: float) -> void:
	# boost pads: a kick in the direction ur going
	var dir: Vector2 = velocity.normalized() if velocity.length() > 60.0 else last_dir
	velocity += dir * amount


# ---------- disks ----------

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
	Noises.play("yeet")
	stats_changed.emit()


func _on_disk_caught() -> void:
	disks_available = min(disks_available + 1, disk_count)
	Noises.play("gotchu")
	stats_changed.emit()


func add_disk() -> void:
	disk_count += 1
	disks_available += 1
	stats_changed.emit()


# ---------- extra weapons ----------

func weapon_level(id: String) -> int:
	return weapons[id].level if weapons.has(id) else 0


func add_weapon(id: String) -> void:
	# first pick gives u the weapon, every pick after that levels it up
	if weapons.has(id):
		weapons[id].level_up()
	else:
		var weapon = AllDaWeapons.WEAPONS[id]["script"].new()
		weapon.name = id
		add_child(weapon)
		weapons[id] = weapon
	stats_changed.emit()


func weapon_summary() -> String:
	var parts := PackedStringArray()
	for id in weapons:
		parts.append("%s %d" % [AllDaWeapons.WEAPONS[id]["name"], weapons[id].level])
	return "    ".join(parts)


# ---------- ramming ----------

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
		var dmg := ram_power(speed)
		var power: float = speed / ram_speed
		var dir: Vector2 = velocity_before.normalized()
		enemy.take_damage(dmg, dir * ram_knockback * power)
		recently_rammed[enemy] = 0.3
		ram_timer = ram_grace
		var world = get_parent()
		var sonic: bool = speed >= sonic_speed
		if "fx" in world and world.fx:
			var col := Color(0.85, 0.45, 1.0) if sonic else Color(1.0, 0.6, 0.2)
			world.fx.number(enemy.global_position, str(dmg) + ("!" if sonic else ""), col, int(clamp(16 + dmg, 18, 56)))
		get_tree().call_group("camera", "add_shake", min(5.0 + power * 3.0, 22.0))
		Noises.play("crunch", clamp(1.3 - power * 0.12, 0.6, 1.3), min(-6.0 + power * 2.0, 2.0))
		if sonic:
			sonic_blast(enemy, dmg)
		if enemy.health > 0 and enemy.knockback_resist >= 0.5:
			# big heavy shapes u didnt kill: u bounce off them
			velocity = velocity_before.bounce(hit.get_normal()) * 0.6
		else:
			# small fry (or a dead boss): plow straight thru n keep ur speed
			velocity = velocity_before * 0.93


func ram_power(speed: float) -> int:
	return int(round(ram_damage * pow(speed / ram_speed, 2.0)))


func sonic_blast(center_enemy, dmg: int) -> void:
	# going fast enough turns a ram into a shockwave
	var at: Vector2 = center_enemy.global_position
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == center_enemy:
			continue
		var away: Vector2 = other.global_position - at
		if away.length() < sonic_radius + other.body_radius:
			other.take_damage(max(1, dmg / 2), away.normalized() * 700.0)
	var world = get_parent()
	if "fx" in world and world.fx:
		world.fx.ring(at, sonic_radius * 1.4, Color(0.85, 0.45, 1.0), 0.45)
		world.fx.flash(Color(0.85, 0.6, 1.0, 0.25), world.get_node("HUD"))
	Noises.play("kaboom")


# ---------- health ----------

func take_damage(amount: int, source = null) -> void:
	if invincible_timer > 0.0:
		return
	if source != null and is_instance_valid(source) and is_ramming_into(source):
		return   # u hit them, not the other way round
	health -= amount
	invincible_timer = invincible_time
	get_tree().call_group("camera", "add_shake", 8.0)
	Noises.play("ow")
	stats_changed.emit()
	if health <= 0:
		died.emit()
