extends Node2D

@export var enemy_scene: PackedScene
@export var fast_enemy_scene: PackedScene   # the quick white guy
@export var fast_chance = 0.15              # share of spawns that are fast ones (goes up over time)
@export var min_spawn_distance = 300.0
@export var max_spawn_distance = 1300.0     # the map is big now; don't spawn enemies miles away
@export var wave_delay = 0.8      # seconds between clearing a wave and the next one
@export var wave_timeout = 20.0   # next wave comes anyway if this one isn't cleared in time
@export var xp_base = 3           # XP needed for level L = xp_base + xp_growth * L ...
@export var xp_growth = 2         # ...but early levels are cheaper (see xp_needed)
@export var threat_per_minute = 1.0   # how fast enemies get stronger (see enemy.gd power_up)
@export var max_enemy_speed = 450.0   # enemies never get faster than this (player cruise speed is 650)

# The big shapes. One (or more, later on) joins every boss_every-th wave once unlocked.
@export var pentagon_scene: PackedScene
@export var hexagon_scene: PackedScene
@export var star_scene: PackedScene
@export var boss_every = 3
@export var pentagon_unlock = 60.0    # seconds survived before each shape can show up
@export var hexagon_unlock = 150.0
@export var star_unlock = 240.0

# Speedrun mode (picked on the title screen): clear Game.SPEEDRUN_WAVES waves as fast as you can.
# Enemies get stronger per wave instead of per minute, so a fast run doesn't make it easier.
@export var speedrun_wave_delay = 0.4
@export var speedrun_wave_timeout = 40.0
@export var speedrun_threat_per_wave = 0.35

const DIRS = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
const RunOverlay = preload("res://run_overlay.gd")

var wave: int = 0
var enemies_alive: int = 0
var wave_clearing: bool = false
var wave_time: float = 0.0
var game_time: float = 0.0    # seconds survived (stops while the upgrade menu is open)

var level: int = 1
var xp: int = 0
var pending_levels: int = 0   # level-ups waiting for an upgrade pick

var walkable = {}        # every open floor cell you can reach from the start
var spawn_cells = []     # open cells with no walls around them (room for an enemy)
var flow = {}            # cell -> how many steps away from the player it is
var flow_timer: float = 0.0
var bosses_seen = {}     # boss scene -> true once it has spawned at least once
var announce_label: Label

var speedrun: bool = false
var run_over: bool = false
var splits = []          # speedrun: time each wave ended
var best_splits = []     # splits from your best speedrun, to compare against
var timer_label: Label   # speedrun: big clock in the corner
var split_label: Label   # speedrun: "-1.32" ahead / "+0.80" behind your best
var overlay              # pause / death / finish screen
var hud_timer: float = 0.0

@onready var player = $player
@onready var tilemap: TileMapLayer = $TileMapLayer
@onready var hud_label: Label = $HUD/Label
@onready var weapons_label: Label = $HUD/WeaponsLabel
@onready var xp_bar: ProgressBar = $HUD/XPBar
@onready var upgrade_menu = $UpgradeMenu
@onready var tutorial = $Tutorial


func _ready() -> void:
	find_walkable_cells()
	build_flow()
	player.died.connect(_on_player_died)
	player.stats_changed.connect(update_hud)
	upgrade_menu.upgrade_chosen.connect(_on_upgrade_chosen)
	weapons_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # lots of weapons = wrap onto a 2nd line
	overlay = RunOverlay.new()
	add_child(overlay)

	speedrun = Game.is_speedrun()
	if speedrun:
		wave_delay = speedrun_wave_delay
		wave_timeout = speedrun_wave_timeout
		best_splits = Game.get_record("speedrun_splits", [])
		make_speedrun_labels()
		announce("SPEEDRUN - move to start the clock", Color(1.0, 0.85, 0.3))
	elif not tutorial.holding_waves():
		start_next_wave()   # otherwise the tutorial starts wave 1 once you've learned the basics
	update_hud()


func _physics_process(delta: float) -> void:
	# refresh the enemy pathfinding 4 times per second
	# safety net: never let a stuck enemy stall the game
	hud_timer -= delta
	if hud_timer <= 0.0:
		hud_timer = 0.1
		update_hud()   # keep the clock + speedometer ticking
	if wave == 0:
		# speedrun: the clock starts the moment you move or throw
		if speedrun and (Input.get_vector("democratic", "conservative", "were going up up up its our moment", "hell") != Vector2.ZERO or Input.is_action_pressed("throw")):
			start_next_wave()
		return   # (endless: the tutorial hasn't let the enemies in yet)
	if run_over:
		return
	wave_time += delta
	game_time += delta
	if speedrun:
		timer_label.text = Game.format_time(game_time, true)
	if wave_time >= wave_timeout and not wave_clearing:
		start_next_wave()

	flow_timer -= delta
	if flow_timer <= 0.0:
		flow_timer = 0.25
		build_flow()


# ---------- XP ----------

func xp_needed() -> int:
	# early levels come about twice as fast (2, 3, 4, 6, 8, 10, 12...), then it settles
	# into the old xp_base + xp_growth * level curve from about level 14 on
	var early: int = int(1.0 + level + level * level / 12.0)
	return min(early, xp_base + xp_growth * level)


func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_levels += 1
	update_hud()
	if pending_levels > 0 and not upgrade_menu.visible:
		upgrade_menu.open()


func _on_upgrade_chosen() -> void:
	pending_levels -= 1
	update_hud()
	if pending_levels > 0:
		upgrade_menu.open.call_deferred()   # leveled more than once: pick again


# ---------- Maze helpers ----------

func cell_of(world_pos: Vector2) -> Vector2i:
	return tilemap.local_to_map(tilemap.to_local(world_pos))


func cell_center(cell: Vector2i) -> Vector2:
	return tilemap.to_global(tilemap.map_to_local(cell))


func find_walkable_cells() -> void:
	# flood fill from the player through empty cells
	var start := cell_of(player.global_position)
	var bounds := tilemap.get_used_rect().grow(1)
	walkable = {start: true}
	var queue = [start]
	while queue.size() > 0:
		var cell: Vector2i = queue.pop_front()
		for dir in DIRS:
			var next: Vector2i = cell + dir
			if bounds.has_point(next) and not walkable.has(next) and tilemap.get_cell_source_id(next) == -1:
				walkable[next] = true
				queue.append(next)

	# cells where all 8 neighbours are also open, so an enemy fits without touching a wall
	spawn_cells = []
	for cell in walkable:
		var roomy := true
		for x in range(-1, 2):
			for y in range(-1, 2):
				if not walkable.has(cell + Vector2i(x, y)):
					roomy = false
		if roomy:
			spawn_cells.append(cell)
	if spawn_cells.is_empty():
		spawn_cells = walkable.keys()


func build_flow() -> void:
	# breadth-first search outward from the player: each cell stores its step count
	var start := cell_of(player.global_position)
	if not walkable.has(start):
		return
	flow = {start: 0}
	var queue = [start]
	while queue.size() > 0:
		var cell: Vector2i = queue.pop_front()
		for dir in DIRS:
			var next: Vector2i = cell + dir
			if walkable.has(next) and not flow.has(next):
				flow[next] = flow[cell] + 1
				queue.append(next)


func chase_direction(from: Vector2) -> Vector2:
	# enemies call this: head for the neighbouring cell that is closest to the player
	var cell := cell_of(from)
	var target: Vector2 = player.global_position
	if flow.has(cell) and flow[cell] > 1:
		var best := cell
		var best_steps: int = flow[cell]
		for dir in DIRS:
			var next: Vector2i = cell + dir
			if flow.has(next) and flow[next] < best_steps:
				best = next
				best_steps = flow[next]
		target = cell_center(best)
	return (target - from).normalized()


# ---------- Waves ----------

func start_next_wave() -> void:
	if run_over:
		return
	if speedrun:
		if wave >= Game.SPEEDRUN_WAVES:
			return   # final wave is running - you have to clear it
		if wave > 0:
			record_split()
	wave += 1
	wave_time = 0.0
	var count = 2 + wave * 2
	for i in count:
		spawn_enemy()
	if speedrun:
		# fixed boss waves so every run is the same race
		var boss_waves = {3: [pentagon_scene], 6: [hexagon_scene], 9: [star_scene],
			Game.SPEEDRUN_WAVES: [pentagon_scene, hexagon_scene, star_scene]}
		if wave == Game.SPEEDRUN_WAVES:
			announce("FINAL WAVE", Color(1.0, 0.85, 0.3))
		for boss in boss_waves.get(wave, []):
			if boss:
				spawn_enemy(boss)
	elif wave % boss_every == 0:
		for i in 1 + int(threat_level() / 5.0):   # more big shapes the longer you last
			var boss := pick_boss()
			if boss:
				spawn_enemy(boss)
	update_hud()


func pick_boss() -> PackedScene:
	# which shapes are unlocked, and how often each one gets picked (the star is rarest)
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


func announce(text: String, color: Color = Color(1.0, 0.35, 0.3)) -> void:
	# big text in the middle of the screen that fades away
	if announce_label == null:
		announce_label = Label.new()
		announce_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)   # full width, text centred
		announce_label.offset_top = 110.0
		announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		announce_label.add_theme_font_size_override("font_size", 40)
		announce_label.add_theme_constant_override("outline_size", 8)
		announce_label.add_theme_color_override("font_outline_color", Color.BLACK)
		$HUD.add_child(announce_label)
	announce_label.text = text
	announce_label.add_theme_color_override("font_color", color)
	announce_label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(announce_label, "modulate:a", 0.0, 1.0)


func spawn_enemy(boss_scene: PackedScene = null) -> void:
	if enemy_scene == null:
		push_warning("Drag enemy.tscn into the World's Enemy Scene slot!")
		return
	var scene: PackedScene = enemy_scene
	var fast_odds: float = min(0.4, fast_chance + 0.05 * threat_level())
	if boss_scene:
		scene = boss_scene
	elif fast_enemy_scene and randf() < fast_odds:
		scene = fast_enemy_scene
	var enemy = scene.instantiate()

	# pick a random open cell that isn't right next to the player, but not too far either
	var pos: Vector2 = player.global_position
	for attempt in 40:
		pos = cell_center(spawn_cells.pick_random())
		var d := pos.distance_to(player.global_position)
		if d >= min_spawn_distance and d <= max_spawn_distance:
			break

	enemy.position = pos
	if not enemy.is_boss:
		enemy.speed += wave * 10   # enemies get faster each wave
	# ...and stronger the longer you survive, with the odd elite mixed in later on
	var threat := threat_level()
	var elite_chance: float = clamp((threat - 1.0) * 0.06, 0.0, 0.3)
	enemy.power_up(threat, not enemy.is_boss and randf() < elite_chance)
	if enemy.is_boss:
		bosses_seen[scene] = true
		announce(enemy.boss_name + " HAS APPEARED")
		get_tree().call_group("camera", "add_shake", 10.0)
	enemy.speed = min(enemy.speed, max_enemy_speed)
	enemy.died.connect(_on_enemy_died.bind(enemy.xp_value))
	add_child(enemy)
	enemies_alive += 1


func threat_level() -> float:
	if speedrun:
		return max(0, wave - 1) * speedrun_threat_per_wave
	return game_time / 60.0 * threat_per_minute


func _on_enemy_died(xp_value: int) -> void:
	hit_stop(0.06)
	enemies_alive -= 1
	add_xp(xp_value)
	if speedrun and wave >= Game.SPEEDRUN_WAVES and enemies_alive <= 0:
		finish_speedrun()
		return
	if enemies_alive <= 0 and not wave_clearing:
		# short breather, then the next wave (the timer pauses while the upgrade menu is open)
		wave_clearing = true
		get_tree().create_timer(wave_delay, false).timeout.connect(_on_wave_delay_done)


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
	if speedrun:
		overlay.show_screen("dead", "DEAD", "wave %d / %d   %s" % [wave, Game.SPEEDRUN_WAVES, Game.format_time(game_time, true)], Color(1.0, 0.35, 0.3))
		return
	var lines = ["survived %s   wave %d   level %d" % [Game.format_time(game_time), wave, level]]
	var best = Game.get_record("endless_time")
	if best == null or game_time > best:
		Game.set_record("endless_time", game_time)
		Game.set_record("endless_wave", wave)
		if best != null:
			lines.append("NEW BEST!  (old: %s)" % Game.format_time(best))
	else:
		lines.append("best: %s" % Game.format_time(best))
	overlay.show_screen("dead", "YOU DIED", "\n".join(lines), Color(1.0, 0.35, 0.3))


# ---------- Speedrun ----------

func make_speedrun_labels() -> void:
	timer_label = Label.new()
	timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	timer_label.offset_left = -260.0
	timer_label.offset_right = -16.0
	timer_label.offset_top = 10.0
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.add_theme_font_size_override("font_size", 40)
	timer_label.add_theme_constant_override("outline_size", 8)
	timer_label.add_theme_color_override("font_outline_color", Color.BLACK)
	timer_label.text = Game.format_time(0.0, true)
	$HUD.add_child(timer_label)
	split_label = timer_label.duplicate()
	split_label.offset_top = 60.0
	split_label.add_theme_font_size_override("font_size", 22)
	split_label.text = ""
	$HUD.add_child(split_label)


func record_split() -> void:
	# called when a wave ends (cleared, or the next one came anyway)
	splits.append(game_time)
	var i := splits.size() - 1
	if i < best_splits.size():
		var d: float = game_time - best_splits[i]
		split_label.text = "wave %d  %s" % [i + 1, Game.format_delta(d)]
		split_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4) if d < 0.0 else Color(1.0, 0.45, 0.4))
	else:
		split_label.text = "wave %d  %s" % [i + 1, Game.format_time(game_time, true)]
		split_label.add_theme_color_override("font_color", Color.WHITE)


func finish_speedrun() -> void:
	if run_over:
		return
	run_over = true
	record_split()
	timer_label.text = Game.format_time(game_time, true)
	var best = Game.get_record("speedrun_time")
	var lines = ["time  " + Game.format_time(game_time, true)]
	if best == null or game_time < best:
		Game.set_record("speedrun_time", game_time)
		Game.set_record("speedrun_splits", splits)
		lines.append("NEW RECORD!" + ("  (%s)" % Game.format_delta(game_time - best) if best != null else ""))
	else:
		lines.append("best  %s   (%s)" % [Game.format_time(best, true), Game.format_delta(game_time - best)])
	# short pause so you see the last kill, then the results
	get_tree().create_timer(0.6, true, false, true).timeout.connect(
		overlay.show_screen.bind("finish", "FINISHED!", "\n".join(lines), Color(1.0, 0.85, 0.3)))


func run_summary() -> String:
	# shown on the pause screen
	if speedrun:
		return "wave %d / %d   %s" % [wave, Game.SPEEDRUN_WAVES, Game.format_time(game_time, true)]
	return "%s   wave %d   level %d" % [Game.format_time(game_time), wave, level]


func update_hud() -> void:
	var wave_text := ("Wave %d/%d" % [wave, Game.SPEEDRUN_WAVES]) if speedrun else ("Wave %d" % wave)
	hud_label.text = "%s    Lv %d    HP %d/%d    Disks %d/%d    Speed %d" % [
		wave_text, level, player.health, player.max_health, player.disks_available, player.disk_count,
		int(player.velocity.length())]
	if not speedrun:
		hud_label.text += "    " + Game.format_time(game_time)
	weapons_label.text = player.weapon_summary()
	xp_bar.max_value = xp_needed()
	xp_bar.value = xp
