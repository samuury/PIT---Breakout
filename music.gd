extends Node
# Trilha sonora dinâmica: faixas em camadas (stems) tocadas em sincronia, com fade suave.
# Se os arquivos .ogg ainda não foram importados pelo Godot, simplesmente fica em silêncio.

const DIR := "res://music/"
const GAME_STEMS := ["base", "ritmo", "arp", "lead"]
const FADE_RATE := 60.0   # dB por segundo (fade completo em ~1 s)
const DUCK_DB := 14.0     # abaixa a música no pause

var volume := 0.7                 # 0..1
var current := ""                 # faixa que está tocando
var group: Array = []             # AudioStreamPlayer da faixa atual
var stash: Dictionary = {}        # faixa de jogo guardada enquanto o quiz está aberto
var dying: Array = []             # players saindo (fade out)
var duck_on := false
var layer_on: Array = [true, false, true, false]   # base, ritmo, arp, lead
var sting_player: AudioStreamPlayer
var after_sting := ""


func _ready() -> void:
	sting_player = AudioStreamPlayer.new()
	sting_player.finished.connect(_on_sting_finished)
	add_child(sting_player)


func available(track: String) -> bool:
	for p in stems_of(track):
		if not ResourceLoader.exists(p):
			return false
	return true


func stems_of(track: String) -> Array:
	var paths: Array = []
	if track.begins_with("jogo_"):
		for st in GAME_STEMS:
			paths.append("%s%s_%s.ogg" % [DIR, track, st])
	else:
		paths.append("%s%s.ogg" % [DIR, track])
	return paths


func load_stream(path: String, loop: bool) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var s = load(path)
	if s is AudioStreamOggVorbis:
		s.loop = loop
	return s


func play_track(track: String) -> void:
	if track == current and not group.is_empty():
		return
	after_sting = ""
	retire(group)
	group = []
	current = track
	var paths := stems_of(track)
	for i in paths.size():
		var s := load_stream(paths[i], true)
		if s == null:
			continue
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = -60.0
		p.set_meta("stem", i if track.begins_with("jogo_") else -1)
		p.set_meta("trim", -2.0 if track == "quiz" else 0.0)
		add_child(p)
		group.append(p)
	for p in group:
		p.play()   # todas começam no mesmo quadro: ficam sincronizadas


func retire(players: Array) -> void:
	for p in players:
		if is_instance_valid(p):
			dying.append(p)


func set_layers(ritmo: bool, lead: bool) -> void:
	layer_on[1] = ritmo
	layer_on[3] = lead


func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)


func duck(on: bool) -> void:
	duck_on = on


func pause_for_quiz() -> void:
	if current.begins_with("jogo_") and not group.is_empty():
		stash = {"track": current, "group": group}
		for p in group:
			p.set_meta("pausing", true)
	else:
		stash = {}
	group = []
	current = ""


func resume_game() -> void:
	retire(group)
	group = []
	current = ""
	if not stash.is_empty():
		group = stash.group
		current = stash.track
		for p in group:
			p.set_meta("pausing", false)
			p.stream_paused = false
		stash = {}


func stop_all() -> void:
	retire(group)
	if not stash.is_empty():
		retire(stash.group)
		stash = {}
	group = []
	current = ""


func sting(nome: String) -> void:
	var s := load_stream("%s%s.ogg" % [DIR, nome], false)
	if s == null:
		return
	sting_player.stream = s
	sting_player.volume_db = _base_db() + 3.0
	sting_player.play()


func stop_sting() -> void:
	sting_player.stop()
	after_sting = ""


func play_after_sting(track: String) -> void:
	if sting_player.playing:
		after_sting = track
	else:
		play_track(track)


func _on_sting_finished() -> void:
	if after_sting != "":
		var t := after_sting
		after_sting = ""
		play_track(t)


func _base_db() -> float:
	return linear_to_db(volume) if volume > 0.0 else -80.0


func target_db(p: AudioStreamPlayer) -> float:
	var stem: int = p.get_meta("stem", -1)
	if stem >= 0 and not bool(layer_on[stem]):
		return -60.0
	var db := _base_db()
	if duck_on:
		db -= DUCK_DB
	return db + float(p.get_meta("trim", 0.0))


func _process(delta: float) -> void:
	var step := FADE_RATE * delta
	for p in group:
		p.volume_db = move_toward(p.volume_db, target_db(p), step)
	for p in dying.duplicate():
		p.volume_db = move_toward(p.volume_db, -60.0, step)
		if p.volume_db <= -59.0:
			dying.erase(p)
			p.queue_free()
	if not stash.is_empty():
		for p in stash.group:
			if bool(p.get_meta("pausing", false)):
				p.volume_db = move_toward(p.volume_db, -60.0, step)
				if p.volume_db <= -59.0:
					p.stream_paused = true
					p.set_meta("pausing", false)
	if sting_player.playing:
		sting_player.volume_db = _base_db() + 3.0
