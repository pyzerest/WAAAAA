extends Node
# all the noises (autoload called Noises). the sounds r in res://sounds/
#   Noises.play("pop")      Noises.play("crunch", 1.3, -4.0)   <- pitch, volume
# N = mute

const NAMES = ["boing", "yeet", "gotchu", "bonk", "pop", "crunch", "kaboom", "ow", "ding", "zoom", "uh_oh", "yippee", "click", "huh"]
const MIN_GAP = 0.035   # the same sound cant stack up more often than this (weapons hit a LOT)

var streams = {}
var players = []
var last_played = {}
var muted: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in NAMES:
		var path := "res://sounds/%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for i in 16:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not streams.has(sound):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_played.get(sound, -1.0) < MIN_GAP:
		return
	last_played[sound] = now
	for p in players:
		if not p.playing:
			p.stream = streams[sound]
			p.pitch_scale = clamp(pitch, 0.1, 4.0)
			p.volume_db = volume_db
			p.play()
			return


func engine_stream() -> AudioStream:
	# the engine hum, set to loop forever
	var path := "res://sounds/vroom.wav"
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	return s


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_N:
		muted = not muted
		AudioServer.set_bus_mute(0, muted)
