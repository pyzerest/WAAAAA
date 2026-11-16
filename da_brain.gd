extends Node
# da brain (its an autoload called Game)
# remembers what mode u picked on the title screen + ur records

const RECORDS_PATH = "user://records.cfg"

var mode: String = "endless"   # "endless" or "speedrun"
var records := ConfigFile.new()


func _ready() -> void:
	records.load(RECORDS_PATH)   # fine if it doesnt exist yet


func is_speedrun() -> bool:
	return mode == "speedrun"


func get_record(key: String, default = null):
	# (ConfigFile treats a null default as "no default" n errors, so check first)
	if not records.has_section_key("records", key):
		return default
	return records.get_value("records", key)


func set_record(key: String, value) -> void:
	records.set_value("records", key, value)
	records.save(RECORDS_PATH)


static func format_time(t: float, hundredths: bool = false) -> String:
	var s := int(t)
	if hundredths:
		return "%d:%02d.%02d" % [s / 60, s % 60, int((t - s) * 100.0)]
	return "%d:%02d" % [s / 60, s % 60]


static func format_delta(d: float) -> String:
	# split difference vs ur best: "-1.32" = ahead, "+0.80" = behind
	return ("-" if d < 0.0 else "+") + "%.2f" % abs(d)
