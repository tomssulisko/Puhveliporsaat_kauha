extends Node

## Lightweight AudioManager inspired by ldjam59, cleaned up for kauhapeli.
## Storyline expects: masterVolume, fxVolume, volume_changed.

signal volume_changed

const SFX_POOL_SIZE := 8
const SETTINGS_PATH := "user://settings.cfg"

## Ambient "breathing": random target gain, slide there, hold, repeat.
const AMBIENT_GAIN_MIN := 0.35
const AMBIENT_GAIN_MAX := 1.0
const AMBIENT_SLIDE_MIN_SEC := 1.8
const AMBIENT_SLIDE_MAX_SEC := 5.0
const AMBIENT_HOLD_MIN_SEC := 1.2
const AMBIENT_HOLD_MAX_SEC := 5.5

## id -> list of stream paths (random pick). Add new WAVs here as they land.
const SFX_LIBRARY := {
	"luuranko": [
		"res://Audio/luuranko1.wav",
		"res://Audio/luuranko2.wav",
		"res://Audio/luuranko3.wav",
	],
	"lepakko": [
		"res://Audio/lepakko1.wav",
		"res://Audio/lepakko2.wav",
		"res://Audio/lepakko3.wav",
	],
	"lepakko_lento": [
		"res://Audio/lepakko_lentää.wav",
	],

	"silmat": [
		"res://Audio/silmät1.wav",
		"res://Audio/silmät2.wav",
		"res://Audio/silmät3.wav",
	],
	"nonii": [
		"res://Audio/pelaaja_no_niin.wav",
	],
}

const AMBIENT_LIBRARY := {
	"sirkat": "res://Audio/sirkatsoittaa.wav",
	"tuuli": "res://Audio/tuuli.wav",
	# "naakat": "res://Audio/naakat.wav",
	# "narina": "res://Audio/narina.wav",
	# "auto_ajo": "res://Audio/auto_ajo.wav",
}

var masterVolume: float = 100.0
var musicVolume: float = 100.0
var fxVolume: float = 100.0
var masterDB: float = 0.0
var musicDB: float = 0.0
var fxDB: float = 0.0

var _ambient_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx2d_players: Array[AudioStreamPlayer2D] = []
var _sfx_index: int = 0
var _sfx2d_index: int = 0
var _current_ambient: String = ""
var _stream_cache: Dictionary = {}
var _ambient_gain: float = 1.0
var _ambient_modulating: bool = false
var _ambient_mod_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_players()
	_load_volumes()
	volume_change(masterVolume, musicVolume, fxVolume)


func _build_players() -> void:
	_ambient_player = AudioStreamPlayer.new()
	# Master for reliability; bus layout Ambience can be used later once verified.
	_ambient_player.bus = "Master"
	_ambient_player.process_mode = Node.PROCESS_MODE_ALWAYS
	_ambient_player.finished.connect(_on_ambient_finished)
	add_child(_ambient_player)

	var sfx_bus := _bus_or_master("SFX")
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = sfx_bus
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)

		var p2 := AudioStreamPlayer2D.new()
		p2.bus = sfx_bus
		p2.process_mode = Node.PROCESS_MODE_ALWAYS
		p2.max_distance = 2000.0
		add_child(p2)
		_sfx2d_players.append(p2)


func _bus_or_master(bus_name: String) -> String:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return bus_name
	push_warning("AudioManager: bus '%s' missing, using Master" % bus_name)
	return "Master"


func _load_volumes() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	masterVolume = float(cfg.get_value("audio", "master_volume", 100))
	musicVolume = float(cfg.get_value("audio", "music_volume", 100))
	fxVolume = float(cfg.get_value("audio", "fx_volume", 100))


func save_volumes() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master_volume", int(masterVolume))
	cfg.set_value("audio", "music_volume", int(musicVolume))
	cfg.set_value("audio", "fx_volume", int(fxVolume))
	cfg.save(SETTINGS_PATH)


func volume_change(master, music, fx) -> void:
	masterVolume = float(master)
	musicVolume = float(music)
	fxVolume = float(fx)

	var master_m := masterVolume / 100.0
	var music_m := musicVolume / 100.0
	var fx_m := fxVolume / 100.0
	musicDB = -60.0 + (60.0 * music_m * master_m)
	fxDB = -60.0 + (60.0 * fx_m * master_m)

	_apply_ambient_volume()
	for p in _sfx_players:
		p.volume_db = fxDB
	for p in _sfx2d_players:
		p.volume_db = fxDB

	volume_changed.emit()


func play_sfx(id: String) -> void:
	var stream := _pick_sfx_stream(id)
	if stream == null:
		return
	var player := _sfx_players[_sfx_index]
	_sfx_index = (_sfx_index + 1) % _sfx_players.size()
	player.stream = stream
	player.volume_db = fxDB
	player.play()


func play_sfx_at(id: String, global_pos: Vector2) -> void:
	var stream := _pick_sfx_stream(id)
	if stream == null:
		return
	var player := _sfx2d_players[_sfx2d_index]
	_sfx2d_index = (_sfx2d_index + 1) % _sfx2d_players.size()
	player.stream = stream
	player.global_position = global_pos
	player.volume_db = fxDB
	player.play()


## ldjam59-compatible alias
func audio_at_location(pos: Vector2, request: String) -> void:
	play_sfx_at(request, pos)


func play_ambient(id: String, fade_out_sec: float = 0.35, force: bool = false) -> void:
	if not force and id == _current_ambient and _ambient_player.playing:
		return
	if not AMBIENT_LIBRARY.has(id):
		push_warning("AudioManager: unknown ambient '%s'" % id)
		return

	_stop_ambient_modulation()
	if _ambient_player.playing and fade_out_sec > 0.0 and not force:
		var tween := create_tween()
		tween.tween_property(_ambient_player, "volume_db", -60.0, fade_out_sec)
		await tween.finished

	var path: String = AMBIENT_LIBRARY[id]
	var stream := _load_stream(path)
	if stream == null:
		push_warning("AudioManager: ambient stream null for '%s' (%s)" % [id, path])
		return

	# Same simple path as play_sfx. Loop via finished→replay (WAV import loop is flaky).
	_ambient_player.stream = stream
	_ambient_gain = 1.0
	_apply_ambient_volume()
	_ambient_player.play()
	_current_ambient = id
	if not _ambient_player.playing:
		push_warning("AudioManager: ambient '%s' failed to play (%s)" % [id, path])
		return

	# Breathing starts after playback is confirmed; keeps start path identical to SFX.
	await get_tree().create_timer(0.5).timeout
	if _current_ambient == id and _ambient_player.playing:
		_start_ambient_modulation()


## ldjam59-compatible alias for ambient/music tracks
func backgroundmusic(request: String) -> void:
	play_ambient(request)


func stop_ambient(fade_out_sec: float = 0.35) -> void:
	_stop_ambient_modulation()
	# Clear id first so finished→replay does not restart after stop.
	_current_ambient = ""
	if not _ambient_player.playing:
		return
	if fade_out_sec <= 0.0:
		_ambient_player.stop()
		return
	var tween := create_tween()
	tween.tween_property(_ambient_player, "volume_db", -60.0, fade_out_sec)
	await tween.finished
	if _current_ambient.is_empty():
		_ambient_player.stop()


func _on_ambient_finished() -> void:
	if _current_ambient.is_empty() or _ambient_player.stream == null:
		return
	_ambient_player.play()


func _apply_ambient_volume() -> void:
	if _ambient_player == null:
		return
	var linear := db_to_linear(musicDB) * clampf(_ambient_gain, 0.0, 1.0)
	_ambient_player.volume_db = linear_to_db(maxf(linear, 0.0001))


func _set_ambient_gain(gain: float) -> void:
	_ambient_gain = gain
	_apply_ambient_volume()


func _start_ambient_modulation() -> void:
	_ambient_modulating = true
	_ambient_mod_loop()


func _stop_ambient_modulation() -> void:
	_ambient_modulating = false
	if _ambient_mod_tween != null and is_instance_valid(_ambient_mod_tween):
		_ambient_mod_tween.kill()
	_ambient_mod_tween = null


func _ambient_mod_loop() -> void:
	while _ambient_modulating:
		if not _ambient_player.playing:
			await get_tree().create_timer(0.1).timeout
			continue
		var target := randf_range(AMBIENT_GAIN_MIN, AMBIENT_GAIN_MAX)
		var slide := randf_range(AMBIENT_SLIDE_MIN_SEC, AMBIENT_SLIDE_MAX_SEC)
		_ambient_mod_tween = create_tween()
		_ambient_mod_tween.tween_method(
			_set_ambient_gain, _ambient_gain, target, slide
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await _ambient_mod_tween.finished
		if not _ambient_modulating:
			break
		await get_tree().create_timer(randf_range(AMBIENT_HOLD_MIN_SEC, AMBIENT_HOLD_MAX_SEC)).timeout


func _pick_sfx_stream(id: String) -> AudioStream:
	if not SFX_LIBRARY.has(id):
		push_warning("AudioManager: unknown sfx '%s'" % id)
		return null
	var paths: Array = SFX_LIBRARY[id]
	if paths.is_empty():
		return null
	return _load_stream(paths[randi() % paths.size()])


func _load_stream(path: String) -> AudioStream:
	if _stream_cache.has(path):
		return _stream_cache[path]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: missing stream '%s'" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("AudioManager: failed to load '%s'" % path)
		return null
	_stream_cache[path] = stream
	return stream

