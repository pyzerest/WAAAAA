extends Camera2D

@export var shake_decay = 40.0   # pixels of shake removed per second
# There's no top speed, so the camera pulls back the faster you go (so you can see what's coming)
@export var zoom_out_from = 700.0    # speed where the camera starts pulling back
@export var zoom_out_rate = 2200.0   # every this-many px/s above that, the view gets 2x wider
@export var min_zoom_ratio = 0.5     # never zoom out more than this (fraction of the normal zoom)

var shake: float = 0.0
var base_zoom: Vector2
var base_smoothing: float


func _ready() -> void:
	add_to_group("camera")
	base_zoom = zoom
	base_smoothing = position_smoothing_speed


func add_shake(amount: float) -> void:
	shake = max(shake, amount)


func _process(delta: float) -> void:
	shake = move_toward(shake, 0.0, shake_decay * delta)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake

	var speed: float = get_parent().velocity.length() if "velocity" in get_parent() else 0.0
	var ratio: float = 1.0 / (1.0 + max(0.0, speed - zoom_out_from) / zoom_out_rate)
	ratio = max(ratio, min_zoom_ratio)
	zoom = zoom.lerp(base_zoom * ratio, min(1.0, 2.5 * delta))
	# follow tighter when fast, otherwise the car runs off the edge of the screen
	position_smoothing_speed = base_smoothing + speed / 120.0
