extends CanvasLayer
# A simple step-by-step tutorial. Each tip stays on screen until you do the thing.
# Enemies only show up once you've learned to drive, bounce and throw.
#
# It remembers how far you got (even if you die), so it only shows once.
# ENTER skips it, F1 replays it from the start.

const SAVE_PATH = "user://tutorial.cfg"

# "wait" = the step finishes by itself after that many seconds
var steps = [
	{"text": "Drive with W A S D"},
	{"text": "Drive into a wall and tap SPACE to bounce off it"},
	{"text": "Click to throw your disk - it bounces off walls and slices enemies"},
	{"text": "Drive over your disk to catch it when it flies back"},
	{"text": "Enemies incoming! The arrows on your ring point at the nearest ones", "wait": 5.0},
	{"text": "Go FAST - when your ring glows orange, smash into an enemy to dash-kill it"},
	{"text": "Kills give XP. Level up to pick upgrades - including new weapons!", "wait": 12.0},
	{"text": "A gold arrow means a big boss shape is coming. Good luck!", "wait": 5.0},
]
const ENEMY_STEP = 4   # from this step on, waves are running

var step: int = 0
var step_time: float = 0.0
var disk_was_thrown: bool = false
var did_bounce: bool = false
var finished: bool = false

var world
var player
var tip: Label
var hint: Label


func _ready() -> void:
	world = get_parent()
	player = world.get_node("player")
	player.bounced.connect(func(): did_bounce = true)

	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		step = cfg.get_value("tutorial", "step", 0)
	finished = step >= steps.size() or Game.is_speedrun()   # no tutorial in speedrun mode

	tip = make_label(26, -130.0)
	hint = make_label(14, -84.0)
	hint.text = "ENTER: skip tutorial"
	show_step()


func make_label(font_size: int, from_bottom: float) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)   # full width, text centred
	label.offset_top = from_bottom
	label.offset_bottom = from_bottom + font_size + 12
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 8)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	add_child(label)
	return label


func holding_waves() -> bool:
	# the world asks this on startup: don't send enemies until the basics are done
	return not finished and step < ENEMY_STEP


func _process(delta: float) -> void:
	if finished:
		return
	step_time += delta
	if step_done():
		next_step()


func step_done() -> bool:
	var info = steps[step]
	if info.has("wait"):
		return step_time >= info["wait"]
	match step:
		0:
			return player.velocity.length() > 200.0
		1:
			return did_bounce
		2:
			if player.disks_available < player.disk_count:
				disk_was_thrown = true
			return disk_was_thrown
		3:
			return player.disks_available >= player.disk_count
		5:
			return player.ram_timer > 0.0   # a ram just happened
	return false


func next_step() -> void:
	step += 1
	step_time = 0.0
	if step == 1:
		did_bounce = false
	if step >= steps.size():
		finished = true
	save_progress()
	if step == ENEMY_STEP and world.wave == 0:
		world.start_next_wave()
	show_step()


func show_step() -> void:
	tip.visible = not finished
	hint.visible = not finished
	if not finished:
		tip.text = steps[step]["text"]
		# flash yellow so you notice the new tip
		var tween := create_tween()
		tip.modulate = Color(1.0, 0.85, 0.3)
		tween.tween_property(tip, "modulate", Color.WHITE, 0.4)


func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("tutorial", "step", step)
	cfg.save(SAVE_PATH)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_ENTER and not finished:
		step = steps.size()
		finished = true
		save_progress()
		show_step()
		if world.wave == 0:
			world.start_next_wave()
	elif event.keycode == KEY_F1 and not Game.is_speedrun():
		step = 0
		save_progress()
		get_tree().paused = false
		Engine.time_scale = 1.0
		get_tree().reload_current_scene.call_deferred()
