extends Control
# Title screen: pick Endless Survival or Speedrun.
# The enemy shapes bounce around behind the menu (bounce back theme).

const SHAPES = [
	"res://pentagon_enemy.png", "res://hexagon_enemy.png", "res://star_enemy.png",
	"res://fast_enemy.png", "res://enemie (1).png",
]

@export var shape_count = 10
@export var shape_alpha = 0.28

@onready var bouncers: Node2D = $Bouncers
@onready var endless_button: Button = $Menu/EndlessButton
@onready var speedrun_button: Button = $Menu/SpeedrunButton
@onready var quit_button: Button = $Menu/QuitButton
@onready var records_label: Label = $Menu/RecordsLabel
@onready var version_label: Label = $VersionLabel

var movers = []   # {"sprite": Sprite2D, "vel": Vector2, "spin": float, "r": float}


func _ready() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	endless_button.pressed.connect(start.bind("endless"))
	speedrun_button.pressed.connect(start.bind("speedrun"))
	quit_button.pressed.connect(get_tree().quit)
	endless_button.grab_focus()
	version_label.text = ProjectSettings.get_setting("application/config/name")
	show_records()
	spawn_shapes()


func show_records() -> void:
	var lines = []
	var best_survive = Game.get_record("endless_time")
	if best_survive != null:
		lines.append("Best survival: %s  (wave %d)" % [Game.format_time(best_survive), Game.get_record("endless_wave", 0)])
	var best_run = Game.get_record("speedrun_time")
	if best_run != null:
		lines.append("Best speedrun: " + Game.format_time(best_run, true))
	records_label.text = "\n".join(lines) if lines.size() > 0 else "no records yet - go set some"


func spawn_shapes() -> void:
	var screen := get_viewport_rect().size
	for i in shape_count:
		var tex: Texture2D = load(SHAPES[i % SHAPES.size()])
		var sprite := Sprite2D.new()
		sprite.texture = tex
		var px: float = randf_range(50.0, 110.0)   # on-screen size
		sprite.scale = Vector2.ONE * px / max(tex.get_width(), tex.get_height())
		sprite.modulate.a = shape_alpha
		sprite.position = Vector2(randf_range(px, screen.x - px), randf_range(px, screen.y - px))
		bouncers.add_child(sprite)
		var vel := Vector2.from_angle(randf() * TAU) * randf_range(70.0, 200.0)
		movers.append({"sprite": sprite, "vel": vel, "spin": randf_range(-1.5, 1.5), "r": px / 2.0})


func _process(delta: float) -> void:
	var screen := get_viewport_rect().size
	for m in movers:
		var s: Sprite2D = m["sprite"]
		s.position += m["vel"] * delta
		s.rotation += m["spin"] * delta
		# bounce off the screen edges
		if (s.position.x < m["r"] and m["vel"].x < 0.0) or (s.position.x > screen.x - m["r"] and m["vel"].x > 0.0):
			m["vel"].x = -m["vel"].x
		if (s.position.y < m["r"] and m["vel"].y < 0.0) or (s.position.y > screen.y - m["r"] and m["vel"].y > 0.0):
			m["vel"].y = -m["vel"].y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			start("endless")
		elif event.keycode == KEY_2:
			start("speedrun")


func start(mode: String) -> void:
	Game.mode = mode
	get_tree().change_scene_to_file("res://main.tscn")
