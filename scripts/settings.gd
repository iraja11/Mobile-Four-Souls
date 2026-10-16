extends Node
# Autoload "Settings": opções do jogador, persistidas em user://settings.cfg.
# Volumes lineares 0..1 nos buses Master / Music / SFX (Music e SFX são criados aqui se não existirem;
# sons futuros devem tocar com `bus = "Music"` ou `bus = "SFX"`). Tela cheia só onde há janela (desktop).

const PATH := "user://settings.cfg"
const BUSES := {"master": "Master", "music": "Music", "sfx": "SFX"}

var volume := {"master": 1.0, "music": 0.8, "sfx": 0.9}
var fullscreen := false

func _ready() -> void:
	for k in BUSES:
		if AudioServer.get_bus_index(BUSES[k]) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, BUSES[k])
			AudioServer.set_bus_send(i, "Master")
	load_cfg()
	apply()

func load_cfg() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK:
		return
	for k in volume:
		volume[k] = clampf(float(c.get_value("audio", k, volume[k])), 0.0, 1.0)
	fullscreen = bool(c.get_value("video", "fullscreen", fullscreen))

func save() -> void:
	var c := ConfigFile.new()
	for k in volume:
		c.set_value("audio", k, volume[k])
	c.set_value("video", "fullscreen", fullscreen)
	c.save(PATH)

func set_volume(k: String, v: float) -> void:
	volume[k] = clampf(v, 0.0, 1.0)
	_apply_bus(k)

func set_fullscreen(on: bool) -> void:
	fullscreen = on
	_apply_window()

func apply() -> void:
	for k in volume:
		_apply_bus(k)
	_apply_window()

static func can_fullscreen() -> bool:
	return not (OS.has_feature("mobile") or OS.has_feature("web") or DisplayServer.get_name() == "headless")

func _apply_bus(k: String) -> void:
	var i := AudioServer.get_bus_index(BUSES[k])
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(volume[k], 0.0001)))
	AudioServer.set_bus_mute(i, volume[k] <= 0.001)

func _apply_window() -> void:
	if not can_fullscreen():
		return
	var m := DisplayServer.window_get_mode()
	var is_fs := m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_fs != fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
