extends Camera2D

@export var shake_decay = 40.0   # pixels of shake removed per second

var shake: float = 0.0


func _ready() -> void:
	add_to_group("camera")


func add_shake(amount: float) -> void:
	shake = max(shake, amount)


func _process(delta: float) -> void:
	shake = move_toward(shake, 0.0, shake_decay * delta)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
