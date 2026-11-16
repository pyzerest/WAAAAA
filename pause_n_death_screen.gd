extends CanvasLayer
# pause screen (ESC), u died screen, n the speedrun finish screen
# world makes it in code n calls show_screen()
# speedrun: R = instant restart whenever

var world
var title: Label
var info: Label
var button_box: VBoxContainer
var state: String = ""   # "" = hidden, "pause", "dead", "finish"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while the game is paused
	layer = 5
	world = get_parent()

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(400, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_constant_override("outline_size", 10)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	vbox.add_child(title)
	info = Label.new()
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 18)
	vbox.add_child(info)
	button_box = VBoxContainer.new()
	button_box.add_theme_constant_override("separation", 8)
	vbox.add_child(button_box)
	visible = false


func show_screen(new_state: String, title_text: String, info_text: String, color: Color = Color.WHITE) -> void:
	state = new_state
	title.text = title_text
	title.add_theme_color_override("font_color", color)
	info.text = info_text
	info.visible = info_text != ""
	for b in button_box.get_children():
		button_box.remove_child(b)
		b.queue_free()
	if state == "pause":
		add_button("Resume  (ESC)", resume)
	add_button("Restart  (R)" if state == "pause" else "Retry  (R)", retry)
	add_button("Title screen", to_title)
	Engine.time_scale = 1.0
	get_tree().paused = true
	visible = true
	button_box.get_child(0).grab_focus.call_deferred()


func add_button(text: String, action: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 46)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(action)
	button_box.add_child(b)


func resume() -> void:
	state = ""
	visible = false
	get_tree().paused = false


func retry() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene.call_deferred()


func to_title() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file.call_deferred("res://title_screen.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_R and (state != "" or Game.is_speedrun()):
		retry()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE:
		if state == "pause":
			resume()
		elif state == "" and not world.upgrade_menu.visible:
			show_screen("pause", "PAUSED", world.run_summary())
		get_viewport().set_input_as_handled()
