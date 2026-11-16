extends Node2D
# ur ghost from ur best speedrun. see-thru u that does the exact same run
# writes down where u are every 1/30 sec, saves it when u get a new record

const SAVE_PATH = "user://ghost.dat"
const STEP = 1.0 / 30.0

var best := PackedVector2Array()   # the run ur racing against
var recording := PackedVector2Array()
var sprite: Sprite2D


func _ready() -> void:
	z_index = 4
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var data = f.get_var()
		if data is PackedVector2Array:
			best = data
	visible = false


func use_look_of(player_sprite: Sprite2D) -> void:
	sprite = player_sprite.duplicate()
	sprite.modulate = Color(0.55, 0.9, 1.0, 0.45)
	add_child(sprite)


func has_ghost() -> bool:
	return best.size() > 1


func record(race_time: float, pos: Vector2) -> void:
	while recording.size() <= int(race_time / STEP):
		recording.append(pos)


func update(race_time: float) -> void:
	# put the ghost where u were at this time in ur best run
	if not has_ghost():
		return
	var f := race_time / STEP
	var i := int(f)
	if i >= best.size() - 1:
		global_position = best[best.size() - 1]
		visible = true
		modulate.a = 0.5   # finished already: just sits on the line
		return
	global_position = best[i].lerp(best[i + 1], f - i)
	visible = true


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_var(recording)
