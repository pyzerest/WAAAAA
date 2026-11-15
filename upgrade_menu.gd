extends CanvasLayer

signal upgrade_chosen

const WeaponList = preload("res://weapons/weapon_list.gd")

var upgrades = [
	{"id": "extradisk", "name": "Extra Disk",   "desc": "+1 disk to throw"},
	{"id": "multishot", "name": "Split Shot",   "desc": "Throw +1 disk per click (+1 disk)"},
	{"id": "bounces",   "name": "Ricochet",     "desc": "+1 disk bounce"},
	{"id": "damage",    "name": "Sharp Edge",   "desc": "+1 disk damage"},
	{"id": "dspeed",    "name": "Fastball",     "desc": "+120 disk speed"},
	{"id": "inherit",   "name": "Momentum",     "desc": "Throws carry more of your speed"},
	{"id": "speed",     "name": "Zoomies",      "desc": "+40 max speed"},
	{"id": "wall",      "name": "Bouncier",     "desc": "+75 wall bounce"},
	{"id": "health",    "name": "Thick Skin",   "desc": "+1 max HP, full heal"},
	{"id": "ram",       "name": "Battering Ram", "desc": "+1 ram damage, ram at lower speed"},
]

# only offered once you own at least one extra weapon
var overcharge = {"id": "overcharge", "name": "Overcharge", "desc": "+1 damage to ALL extra weapons"}

var choices = []

@onready var panel: Panel = $Panel
@onready var vbox: VBoxContainer = $Panel/VBoxContainer
@onready var buttons = [
	$Panel/VBoxContainer/Button1,
	$Panel/VBoxContainer/Button2,
	$Panel/VBoxContainer/Button3,
]


func _ready() -> void:
	hide()
	get_viewport().size_changed.connect(fit_to_screen)
	for i in buttons.size():
		buttons[i].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long descriptions wrap instead of spilling out
		buttons[i].pressed.connect(_on_button_pressed.bind(i))


func open() -> void:
	# weapon picks: new weapons you don't have yet, or a level-up for ones you do
	var p = get_tree().get_first_node_in_group("player")
	var weapon_choices = []
	for id in WeaponList.WEAPONS:
		var info = WeaponList.WEAPONS[id]
		var lvl: int = p.weapon_level(id)
		if lvl == 0:
			weapon_choices.append({"id": "weapon:" + id, "name": "NEW: " + info["name"], "desc": info["new"]})
		elif lvl < info["max_level"]:
			weapon_choices.append({"id": "weapon:" + id, "name": "%s Lv %d" % [info["name"], lvl + 1], "desc": info["up"]})
	weapon_choices.shuffle()

	# always offer at least one weapon (while there are any left), then fill up randomly
	choices = []
	if weapon_choices.size() > 0:
		choices.append(weapon_choices.pop_front())
	var rest = upgrades + weapon_choices
	if not p.weapons.is_empty():
		rest.append(overcharge)
	rest.shuffle()
	choices += rest.slice(0, 3 - choices.size())
	choices.shuffle()
	for i in 3:
		buttons[i].text = choices[i]["name"] + "\n" + choices[i]["desc"]
	fit_to_screen()
	show()
	get_tree().paused = true


func fit_to_screen() -> void:
	# always keep the menu centred and fully on screen, whatever the window size
	# (this overrides wherever the Panel was dragged to in the editor)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var menu_size := Vector2(min(440.0, screen.x - 32.0), min(380.0, screen.y - 32.0))
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.size = menu_size
	panel.position = (screen - menu_size) / 2.0
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 12)


func _on_button_pressed(index: int) -> void:
	apply_upgrade(choices[index]["id"])
	hide()
	get_tree().paused = false
	upgrade_chosen.emit()


func apply_upgrade(id: String) -> void:
	var p = get_tree().get_first_node_in_group("player")
	if id.begins_with("weapon:"):
		p.add_weapon(id.trim_prefix("weapon:"))
		return
	match id:
		"extradisk":
			p.add_disk()
		"multishot":
			p.throw_count += 1
			p.add_disk()
		"bounces":
			p.disk_bounces += 1
		"damage":
			p.disk_damage += 1
		"dspeed":
			p.disk_speed += 120
		"inherit":
			p.disk_inherit += 0.25
		"speed":
			p.max_speed += 40
		"wall":
			p.wall_bounce += 75
		"health":
			p.max_health += 1
			p.health = p.max_health
		"ram":
			p.ram_damage += 1
			p.ram_speed = max(300.0, p.ram_speed - 30.0)
		"overcharge":
			p.weapon_damage_bonus += 1
	p.stats_changed.emit()  # refresh the HUD
