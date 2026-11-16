extends Node2D

@export var enemy_scene: PackedScene
@export var fast_enemy_scene: PackedScene   # the quick white guy
@export var fast_chance = 0.18              # share of spawns that are fast ones (goes up over time)
@export var min_spawn_distance = 350.0
@export var max_spawn_distance = 1200.0
@export var wave_delay = 0.8      # secs between clearing a wave n the next one
@export var wave_timeout = 20.0   # next wave comes anyway if this one isnt cleared in time
@export var max_enemies = 120     # never more than this many alive at once (keeps it smooth)
@export var xp_base = 3           # XP needed for level L = xp_base + xp_growth * L ...
@export var xp_growth = 2         # ...but early levels are cheaper (see xp_needed)
@export var threat_per_minute = 1.25  # how fast enemies get stronger (see enemy.gd power_up)
@export var max_enemy_speed = 560.0   # enemies never get faster than this (player cruise speed is 650)

# the big shapes, one (or more, later on) joins every boss_every-th wave once unlocked
@export var pentagon_scene: PackedScene
@export var hexagon_scene: PackedScene
@export var star_scene: PackedScene
@export var boss_every = 3
@export var pentagon_unlock = 45.0    # secs survived before each shape can show up
@export var hexagon_unlock = 120.0
@export var star_unlock = 200.0

# boost pads (both modes): drive over one for a burst of speed
@export var pad_count = 80
@export var boost_strength = 450.0
@export var map_seed = 8          # where the pads n the speedrun enemies go (same every run = fair races)

# speedrun: race from the middle of the map to the FINISH on the far edge
@export var wake_range = 650.0    # speedrun enemies sleep until u get this close
@export var combo_time = 2.5      # kills closer together than this build ur combo

const DaMaze = preload("res://da_maze.gd")
const PauseScreen = preload("res://pause_n_death_screen.gd")
const Juice = preload("res://juice.gd")
const ZoomPads = preload("res://zoom_pads_n_finish.gd")
const GhostOfU = preload("res://ghost_of_u.gd")
const LilMap = preload("res://lil_map.gd")
const HowFast = preload("res://how_fast.gd")
const FLOW_RADIUS = 46            # enemies path-find inside this many cells of u
# speedrun enemies per ring (centre -> edge), n how strong each ring's enemies are
const RACE_ENEMIES = [0, 10, 16, 22, 26, 28]
const RACE_THREAT = [0.0, 0.6, 1.3, 2.2, 3.2, 4.5]

var wave: int = 0
var enemies_alive: int = 0
var wave_clearing: bool = false
var wave_time: float = 0.0
var game_time: float = 0.0    # secs survived / race time (stops while menus are open)

var level: int = 1
var xp: int = 0
var pending_levels: int = 0   # level-ups waiting for an upgrade pick

var grid                 # DaMaze: walls, floor, rings, enemy pathfinding
var flow_timer: float = 0.0
var bosses_seen = {}     # boss scene -> true once it has spawned at least once
var announce_label: Label
var zone_label: Label
var combo_label: Label
var current_zone: int = -1
var combo: int = 0
var combo_timer: float = 0.0
var best_combo: int = 0

var speedrun: bool = false
var race_started: bool = false
var run_over: bool = false
var timer_label: Label   # speedrun: big clock in the corner
var best_label: Label    # speedrun: ur record under it
var overlay              # pause / death / finish screen
var fx
var course
var ghost
var minimap
var hud_timer: float = 0.0
var start_pos: Vector2

@onready var player = $player
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var hud_label: Label = $HUD/Label
@onready var weapons_label: Label = $HUD/WeaponsLabel
@onready var xp_bar: ProgressBar = $HUD/XPBar
@onready var upgrade_menu = $UpgradeMenu
@onready var tutorial = $Tutorial


func _ready() -> void:
	speedrun = Game.is_speedrun()
	start_pos = player.global_position
	grid = DaMaze.new()
	grid.setup(tilemap, tilemap.local_to_map(tilemap.to_local(player.global_position)))
	grid.build_flow(grid.cell_of(player.global_position), FLOW_RADIUS)

	make_floor()
	fx = Juice.new()
	add_child(fx)
	course = ZoomPads.new()
	add_child(course)
	place_pads()

	player.died.connect(_on_player_died)
	player.stats_changed.connect(update_hud)
	upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)
	weapons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # lots of weapons = wrap onto a 2nd line
	overlay = PauseScreen.new()
	add_child(overlay)
	make_hud()

	if speedrun:
		setup_race()
	elif not tutorial.holding_waves():
		start_next_wave()   # otherwise the tutorial starts wave 1 once uve learned the basics
	update_hud()


func _physics_process(delta: float) -> void:
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.1
		update_hud()   # keep the clock ticking
		check_zone()

	flow_timer -= delta
	if flow_timer <= 0.0:
		flow_timer = 0.25   # refresh enemy pathfinding 4 times a sec
		grid.build_flow(grid.cell_of(player.global_position), FLOW_RADIUS)

	check_pads(delta)
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			end_combo()

	if run_over:
		return
	if speedrun:
		race_tick(delta)
		return
	if wave == 0:
		return   # the tutorial hasnt let the enemies in yet
	wave_time += delta
	game_time += delta
	# safety net: never let a stuck enemy stall the game
	if wave_time >= wave_timeout and not wave_clearing:
		start_next_wave()


# ---------- XP ----------

func xp_needed() -> int:
	# early levels come about twice as fast (2, 3, 4, 6, 8, 10, 12...), then it settles
	# into the old xp_base + xp_growth * level curve from about level 14 on
	var early: int = int(1.0 + level + level * level / 12.0)
	return min(early, xp_base + xp_growth * level)


func add_xp(amount: int) -> void:
	if speedrun:
		return   # races are pure driving: no level-ups popping up mid-race
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_levels += 1
	update_hud()
	if pending_levels > 0 and not upgrade_menu.visible:
		Noises.play("ding")
		upgrade_menu.open()


func _on_upgrade_chosen() -> void:
	pending_levels -= 1
	update_hud()
	if pending_levels > 0:
		upgrade_menu.open.call_deferred()   # leveled more than once: pick again


# ---------- maze helpers ----------

func cell_of(world_pos: Vector2) -> Vector2i:
	return grid.cell_of(world_pos)


func cell_center(cell: Vector2i) -> Vector2:
	return grid.center_of(cell)


func chase_direction(from: Vector2) -> Vector2:
	# enemies call this: head for the neighbouring cell that is closest to u
	var step: int = grid.next_step(grid.index_of(from))
	var target: Vector2 = player.global_position
	if step >= 0:
		target = grid.center_of(grid.cell_at(step))
	return (target - from).normalized()


func make_floor() -> void:
	# one big picture under the walls, tinted per ring (1 pixel per cell, blown up)
	var floor_sprite := Sprite2D.new()
	floor_sprite.texture = ImageTexture.create_from_image(grid.make_image(false))
	floor_sprite.centered = false
	floor_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	floor_sprite.scale = Vector2(32, 32)
	floor_sprite.position = grid.center_of(grid.rect.position) - Vector2(16, 16)
	floor_sprite.z_index = -10
	add_child(floor_sprite)
	move_child(floor_sprite, 0)


func check_zone() -> void:
	var i: int = grid.index_of(player.global_position)
	if i < 0:
		return
	var z: int = grid.zone_of_index(i)
	if z != current_zone:
		var first := current_zone == -1
		current_zone = z
		if not first:
			show_zone_name(z)


func show_zone_name(z: int) -> void:
	zone_label.text = DaMaze.ZONE_NAMES[z]
	zone_label.add_theme_color_override("font_color", DaMaze.ZONE_WALL[z].lightened(0.3))
	zone_label.modulate.a = 1.0
	var tween := zone_label.create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(zone_label, "modulate:a", 0.0, 0.8)


# ---------- boost pads ----------

func place_pads() -> void:
	# spread out along the wider rings, same spots every run
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed
	var candidates = []
	for z in range(2, DaMaze.ZONE_RADII.size()):
		candidates.append_array(grid.zone_cells[z])
	for attempt in pad_count * 30:
		if course.pads.size() >= pad_count or candidates.is_empty():
			break
		var i: int = candidates[rng.randi() % candidates.size()]
		if not grid.has_room(i, 1):
			continue
		var p: Vector2 = grid.center_of(grid.cell_at(i))
		var ok := p.distance_to(start_pos) > 400.0
		for q in course.pads:
			if q.distance_to(p) < 420.0:
				ok = false
				break
		if ok:
			course.pads.append(p)
			course.pad_cooldown.append(0.0)


func check_pads(delta: float) -> void:
	var me: Vector2 = player.global_position
	for i in course.pads.size():
		if course.pad_cooldown[i] > 0.0:
			course.pad_cooldown[i] -= delta
			continue
		if me.distance_to(course.pads[i]) < 30.0:
			course.pad_cooldown[i] = 1.0
			player.boost(boost_strength)
			fx.ring(course.pads[i], 70.0, Color(0.3, 0.95, 1.0))
			Noises.play("zoom", 1.0 + min(player.velocity.length(), 3000.0) / 6000.0)
			get_tree().call_group("camera", "add_shake", 4.0)


# ---------- waves (endless) ----------

func start_next_wave() -> void:
	if run_over or speedrun:
		return
	wave += 1
	wave_time = 0.0
	var count = 3 + wave * 3
	for i in count:
		spawn_enemy()
	if wave % boss_every == 0:
		for i in 1 + int(threat_level() / 4.0):   # more big shapes the longer u last
			var boss := pick_boss()
			if boss:
				spawn_enemy(boss)
	update_hud()


func pick_boss() -> PackedScene:
	# which shapes are unlocked, n how often each one gets picked (the star is rarest)
	var options = []
	var weights = []
	for entry in [[pentagon_scene, pentagon_unlock, 3.0], [hexagon_scene, hexagon_unlock, 2.0], [star_scene, star_unlock, 1.0]]:
		if entry[0] and game_time >= entry[1]:
			# a shape that just unlocked always gets its debut first
			if not bosses_seen.has(entry[0]):
				return entry[0]
			options.append(entry[0])
			weights.append(entry[2])
	if options.is_empty():
		return null
	var roll: float = randf() * weights.reduce(func(a, b): return a + b)
	for i in options.size():
		roll -= weights[i]
		if roll <= 0.0:
			return options[i]
	return options[-1]


func spawn_point(room: int) -> Vector2:
	# a random cell u can reach, not too close n not too far (from the pathfinding pass)
	var me: Vector2 = player.global_position
	for attempt in 60:
		var i: int = grid.reached[randi() % max(1, grid.reached_count)]
		var p: Vector2 = grid.center_of(grid.cell_at(i))
		var d := p.distance_to(me)
		if d >= min_spawn_distance and d <= max_spawn_distance and grid.has_room(i, room):
			return p
	# fall back to anywhere reachable a bit away
	for attempt in 60:
		var i: int = grid.reached[randi() % max(1, grid.reached_count)]
		var p: Vector2 = grid.center_of(grid.cell_at(i))
		if p.distance_to(me) >= min_spawn_distance * 0.6:
			return p
	return me + Vector2(min_spawn_distance, 0)


func spawn_enemy(boss_scene: PackedScene = null) -> void:
	if enemy_scene == null:
		push_warning("Drag enemy.tscn into the World's Enemy Scene slot!")
		return
	if enemies_alive >= max_enemies and boss_scene == null:
		return
	var scene: PackedScene = enemy_scene
	var fast_odds: float = min(0.45, fast_chance + 0.05 * threat_level())
	if boss_scene:
		scene = boss_scene
	elif fast_enemy_scene and randf() < fast_odds:
		scene = fast_enemy_scene
	var enemy = scene.instantiate()
	enemy.position = spawn_point(1 if enemy.is_boss else 0)
	if not enemy.is_boss:
		enemy.speed += wave * 10   # enemies get faster each wave
	# ...n stronger the longer u survive, w more elites mixed in later on
	var threat := threat_level()
	var elite_chance: float = clamp((threat - 0.5) * 0.08, 0.0, 0.35)
	enemy.power_up(threat, not enemy.is_boss and randf() < elite_chance)
	if enemy.is_boss:
		bosses_seen[scene] = true
		announce(enemy.boss_name + " HAS APPEARED")
		Noises.play("uh_oh")
		get_tree().call_group("camera", "add_shake", 10.0)
	add_enemy(enemy)


func add_enemy(enemy) -> void:
	enemy.speed = min(enemy.speed, max_enemy_speed)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	add_child(enemy)
	enemies_alive += 1


func threat_level() -> float:
	return game_time / 60.0 * threat_per_minute


func _on_enemy_died(enemy) -> void:
	hit_stop(0.06)
	enemies_alive -= 1
	# combo: kills in quick succession
	combo += 1
	combo_timer = combo_time
	best_combo = max(best_combo, combo)
	Noises.play("pop", 1.0 + min(combo, 20) * 0.04)
	if combo >= 3:
		combo_label.text = "x%d COMBO" % combo
		combo_label.modulate.a = 1.0
		combo_label.scale = Vector2(1.3, 1.3)
		combo_label.create_tween().tween_property(combo_label, "scale", Vector2.ONE, 0.15)
	add_xp(enemy.xp_value + combo / 5)   # +1 XP per kill for every 5 in ur combo
	if not speedrun and enemies_alive <= 0 and not wave_clearing:
		# short breather, then the next wave (the timer pauses while the upgrade menu is open)
		wave_clearing = true
		get_tree().create_timer(wave_delay, false).timeout.connect(_on_wave_delay_done)


func end_combo() -> void:
	if combo >= 3:
		var tween := combo_label.create_tween()
		tween.tween_property(combo_label, "modulate:a", 0.0, 0.4)
	combo = 0


func _on_wave_delay_done() -> void:
	wave_clearing = false
	start_next_wave()


func hit_stop(duration: float) -> void:
	Engine.time_scale = 0.05
	get_tree().create_timer(duration, true, false, true).timeout.connect(_end_hit_stop)


func _end_hit_stop() -> void:
	Engine.time_scale = 1.0


func _on_player_died() -> void:
	if run_over:
		return
	run_over = true
	Noises.play("ow", 0.6)
	if speedrun:
		var left: float = player.global_position.distance_to(course.finish) / 32.0
		overlay.show_screen("dead", "WRECKED", "%s   %d m from the finish" % [Game.format_time(game_time, true), int(left)], Color(1.0, 0.35, 0.3))
		return
	var lines = ["survived %s   wave %d   level %d   best combo x%d" % [Game.format_time(game_time), wave, level, best_combo]]
	var best = Game.get_record("endless_time")
	if best == null or game_time > best:
		Game.set_record("endless_time", game_time)
		Game.set_record("endless_wave", wave)
		if best != null:
			lines.append("NEW BEST!  (old: %s)" % Game.format_time(best))
	else:
		lines.append("best: %s" % Game.format_time(best))
	overlay.show_screen("dead", "YOU DIED", "\n".join(lines), Color(1.0, 0.35, 0.3))


# ---------- speedrun: point-to-point race ----------

func setup_race() -> void:
	# the finish is the floor cell in the outer ring thats the LONGEST drive from the start
	var dist: PackedInt32Array = grid.path_distances(grid.cell_of(start_pos))
	var outer: int = DaMaze.ZONE_RADII.size() - 1
	var best_i := -1
	for i in grid.zone_cells[outer]:
		if dist[i] > (dist[best_i] if best_i >= 0 else -1) and grid.has_room(i, 2):
			best_i = i
	course.start = start_pos
	course.finish = grid.center_of(grid.cell_at(best_i))
	player.get_node("EnemyArrows").goal = course.finish

	# sleeping enemies all over the map (the same ones every run), tougher the further out
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed * 7 + 1
	for z in range(1, RACE_ENEMIES.size()):
		var cells: Array = grid.zone_cells[z]
		var placed := 0
		for attempt in RACE_ENEMIES[z] * 20:
			if placed >= RACE_ENEMIES[z]:
				break
			var i: int = cells[rng.randi() % cells.size()]
			var p: Vector2 = grid.center_of(grid.cell_at(i))
			if p.distance_to(start_pos) < 500.0 or p.distance_to(course.finish) < 200.0:
				continue
			var scene: PackedScene = fast_enemy_scene if rng.randf() < 0.3 else enemy_scene
			spawn_sleeper(scene, p, RACE_THREAT[z], rng.randf() < 0.08 * z)
			placed += 1
	# a boss guarding each of the outer rings, n the star right before the finish
	var guards = [[pentagon_scene, 3], [hexagon_scene, 4]]
	for g in guards:
		var cells: Array = grid.zone_cells[g[1]]
		for attempt in 200:
			var i: int = cells[rng.randi() % cells.size()]
			if grid.has_room(i, 1):
				spawn_sleeper(g[0], grid.center_of(grid.cell_at(i)), RACE_THREAT[g[1]], false)
				break
	# the star: somewhere on the way to the finish, a good chunk before it
	var finish_i: int = grid.index_of(course.finish)
	var fdist: PackedInt32Array = grid.path_distances(grid.cell_at(finish_i))
	for i in grid.zone_cells[outer]:
		if fdist[i] >= 25 and fdist[i] <= 30 and grid.has_room(i, 1):
			spawn_sleeper(star_scene, grid.center_of(grid.cell_at(i)), RACE_THREAT[outer], false)
			break

	ghost = GhostOfU.new()
	add_child(ghost)
	ghost.use_look_of(player.get_node("Sprite2D"))
	make_race_labels()
	announce("RACE TO THE FINISH - go when ready", Color(1.0, 0.85, 0.3))


func spawn_sleeper(scene: PackedScene, pos: Vector2, threat: float, elite: bool) -> void:
	if scene == null:
		return
	var enemy = scene.instantiate()
	enemy.position = pos
	enemy.power_up(threat, elite and not enemy.is_boss)
	enemy.dormant = true
	enemy.wake_range = wake_range * (1.3 if enemy.is_boss else 1.0)
	add_enemy(enemy)


func race_tick(delta: float) -> void:
	if not race_started:
		# the clock starts the moment u move or throw
		if Input.get_vector("democratic", "conservative", "were going up up up its our moment", "hell") != Vector2.ZERO or Input.is_action_pressed("throw"):
			race_started = true
		else:
			return
	game_time += delta
	timer_label.text = Game.format_time(game_time, true)
	ghost.record(game_time, player.global_position)
	ghost.update(game_time)
	if player.global_position.distance_to(course.finish) < course.finish_radius:
		finish_race()


func make_race_labels() -> void:
	timer_label = Label.new()
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	timer_label.offset_left = -300.0
	timer_label.offset_right = -16.0
	timer_label.offset_top = 10.0
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 44)
	timer_label.add_theme_constant_override("outline_size", 8)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.text = Game.format_time(0.0, true)
	$HUD.add_child(timer_label)
	best_label = timer_label.duplicate()
	best_label.offset_top = 64.0
	best_label.add_theme_font_size_override("font_size", 20)
	best_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	var best = Game.get_record("speedrun_time")
	best_label.text = ("best  " + Game.format_time(best, true) + "   (ghost = your best run)") if best != null else "no record yet"
	$HUD.add_child(best_label)


func finish_race() -> void:
	if run_over:
		return
	run_over = true
	Noises.play("yippee")
	fx.ring(course.finish, 300.0, Color(1.0, 0.85, 0.2), 0.8)
	fx.flash(Color(1.0, 0.9, 0.5, 0.35), $HUD)
	timer_label.text = Game.format_time(game_time, true)
	var best = Game.get_record("speedrun_time")
	var lines = ["time  " + Game.format_time(game_time, true)]
	if best == null or game_time < best:
		Game.set_record("speedrun_time", game_time)
		ghost.save()
		lines.append("NEW RECORD!" + ("  (%s)" % Game.format_delta(game_time - best) if best != null else "") + "  - your ghost is saved")
	else:
		lines.append("best  %s   (%s)" % [Game.format_time(best, true), Game.format_delta(game_time - best)])
	# short pause so u see urself cross the line, then the results
	get_tree().create_timer(0.8, true, false, true).timeout.connect(
		overlay.show_screen.bind("finish", "FINISHED!", "\n".join(lines), Color(1.0, 0.85, 0.2)))


func run_summary() -> String:
	# shown on the pause screen
	if speedrun:
		return "%s   %d m to go" % [Game.format_time(game_time, true), int(player.global_position.distance_to(course.finish) / 32.0)]
	return "%s   wave %d   level %d" % [Game.format_time(game_time), wave, level]


# ---------- HUD ----------

func announce(text: String, color: Color = Color(1.0, 0.35, 0.3)) -> void:
	# big text in the middle of the screen that fades away
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", color)
	announce_label.modulate.a = 1.0
	var tween := announce_label.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(announce_label, "modulate:a", 0.0, 1.0)


func make_hud() -> void:
	announce_label = centred_label(40, 110.0)
	zone_label = centred_label(26, 160.0)
	zone_label.modulate.a = 0.0
	combo_label = Label.new()
	combo_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	combo_label.offset_top = 200.0
	combo_label.offset_left = -150.0
	combo_label.offset_right = 150.0
	combo_label.pivot_offset = Vector2(150, 20)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.add_theme_font_size_override("font_size", 30)
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	combo_label.add_theme_constant_override("outline_size", 8)
	combo_label.add_theme_color_override("font_outline_color", Color.BLACK)
	combo_label.modulate.a = 0.0
	$HUD.add_child(combo_label)

	var gauge := HowFast.new()
	gauge.player = player
	$HUD.add_child(gauge)
	minimap = LilMap.new()
	$HUD.add_child(minimap)
	minimap.setup(self, grid.make_image(true))
	xp_bar.visible = not speedrun


func centred_label(font_size: int, top: float) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)   # full width, text centred
	label.offset_top = top
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD.add_child(label)
	return label


func update_hud() -> void:
	if speedrun:
		var left: float = player.global_position.distance_to(course.finish) / 32.0 if course.finish != null else 0.0
		hud_label.text = "HP %d/%d    Disks %d/%d    Finish %d m" % [
			player.health, player.max_health, player.disks_available, player.disk_count, int(left)]
		weapons_label.text = ""
		return
	hud_label.text = "Wave %d    Lv %d    HP %d/%d    Disks %d/%d    %s" % [
		wave, level, player.health, player.max_health, player.disks_available, player.disk_count,
		Game.format_time(game_time)]
	weapons_label.text = player.weapon_summary()
	xp_bar.max_value = xp_needed()
	xp_bar.value = xp
