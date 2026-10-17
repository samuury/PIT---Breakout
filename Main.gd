extends Node3D
@warning_ignore_start("integer_division")
# BREAKOUT GENIUS 3D — Godot 4.x  (port completo do código Pygame)
# Uso: nó raiz Node3D + este script. Tudo é criado por código. Rode com F5.
# Menus, modos (Padrão/Random), 3 dificuldades, blocos obstáculo e bomba,
# 8 boosts, 3 downgrades, 10 questionários de matemática, 4 matérias gerais,
# estatísticas por matéria, recorde salvo, sons gerados por código.

const HALF_W := 14.0
const TOP_Y := 10.0
const BOTTOM_Y := -11.5
const PADDLE_Y := -9.0
const PADDLE_H := 0.5
const PADDLE_BASE_W := 5.0
const BALL_R := 0.35
const COLS := 14
const ROWS := 8
const BR_W := 1.8
const BR_H := 0.7
const BR_GAP := 0.1
const DROP_CHANCE := 0.12
const DROP_COOLDOWN := 3.5
const MAX_BALLS := 6
const STALL_LIMIT := 8.0
const MAX_DROPS := 3
const SPEED_K := 1.875  # +25% sobre o valor anterior (1.5), vale para todas as dificuldades
const SIM_STEP := 1.0 / 60.0
const MAX_CATCH_UP := 0.25
var save_path := "user://recorde_breakout_matematico.txt"
const QUESTIONS_PATH := "res://data/perguntas.json"
const QuizBankScript := preload("res://quiz_bank.gd")
const LevelGenScript := preload("res://level_gen.gd")
const RecordStoreScript := preload("res://record_store.gd")
const ROW_PTS := [7, 7, 5, 5, 3, 3, 1, 1]
const MATERIAS := ["Matemática", "Geografia", "Ciências", "História", "Cultura"]
var ROW_COLORS: Array[Color] = [
	Color8(200, 72, 72), Color8(200, 72, 72), Color8(198, 108, 58), Color8(198, 108, 58),
	Color8(72, 160, 72), Color8(72, 160, 72), Color8(200, 190, 60), Color8(200, 190, 60)]

var BOOSTS := {
	"LARGA": {"nome": "Raquete Larga", "cor": Color8(80, 200, 255), "icone": "W", "dur": 15.0, "desc": "Raquete 50% maior"},
	"MULTI": {"nome": "Multibola", "cor": Color8(255, 210, 60), "icone": "M", "dur": 0.0, "desc": "+2 bolas em jogo"},
	"LENTA": {"nome": "Câmera Lenta", "cor": Color8(140, 240, 140), "icone": "S", "dur": 12.0, "desc": "Bola 35% mais lenta"},
	"VIDA": {"nome": "Vida Extra", "cor": Color8(255, 100, 140), "icone": "+", "dur": 0.0, "desc": "+1 vida"},
	"FOGO": {"nome": "Bola de Fogo", "cor": Color8(255, 130, 40), "icone": "F", "dur": 10.0, "desc": "Atravessa e destrói blocos"},
	"IMA": {"nome": "Ímã", "cor": Color8(190, 120, 255), "icone": "I", "dur": 15.0, "desc": "Bola gruda na raquete"},
	"LASER": {"nome": "Laser", "cor": Color8(255, 70, 70), "icone": "L", "dur": 12.0, "desc": "Segure ESPAÇO para atirar"},
	"X2": {"nome": "Pontos x2", "cor": Color8(235, 235, 235), "icone": "x2", "dur": 15.0, "desc": "Pontuação em dobro"},
}
var BOOST_WEIGHTS := {"LARGA": 3, "MULTI": 3, "LENTA": 2, "VIDA": 1, "FOGO": 2, "IMA": 2, "LASER": 2, "X2": 2}
var DOWNGRADES := {
	"ENCOLHE": {"nome": "Raquete Encolhida", "cor": Color8(150, 150, 150), "dur": 8.0},
	"RAQUETE_LENTA": {"nome": "Raquete Lenta", "cor": Color8(220, 150, 90), "dur": 8.0},
	"BOLA_RAPIDA": {"nome": "Bola Acelerada", "cor": Color8(240, 90, 90), "dur": 8.0},
}
var DIFS := {
	"facil": {"nome": "Fácil", "fator": 0.88, "cresc": 0.28, "limite": 8.0, "densidade": 0.62,
		"vida_extra": 0, "haz_obs": 3, "haz_bomba": 2, "tempo": 25, "desc": "Bola mais lenta, mais tempo"},
	"normal": {"nome": "Normal", "fator": 1.0, "cresc": 0.4, "limite": 9.0, "densidade": 0.74,
		"vida_extra": 0, "haz_obs": 4, "haz_bomba": 3, "tempo": 20, "desc": "Ritmo equilibrado"},
	"dificil": {"nome": "Difícil", "fator": 1.16, "cresc": 0.58, "limite": 10.0, "densidade": 0.86,
		"vida_extra": 1, "haz_obs": 5, "haz_bomba": 4, "tempo": 16, "desc": "Bola rápida, menos tempo"},
}

# ---------------------------------------------------------------- estado
var world: Node3D
var scenery: Node3D
var cam: Camera3D
var paddle: MeshInstance3D
var paddle_mat: StandardMaterial3D
var ball_light: OmniLight3D
var emit_nodes: Array = []

var bricks: Array = []
var balls: Array = []
var drops: Array = []
var lasers: Array = []
var fx: Array = []
var texts: Array = []
var active: Dictionary = {}
var sfx_players: Dictionary = {}

var score := 0
var lives := 3
var level := 1
var hi := 0
var state := "MENU"
var accel := 1.0
var freeze := 0.0
var cooldown_laser := 0.0
var level_timer := 0.0
var level_bonus := 0
var paddle_w := PADDLE_BASE_W
var use_mouse := false
var mouse_ratio := 0.5
var t_anim := 0.0
var sim_accumulator := 0.0
var novo_recorde := false
var bank
var record_store
var drop_cd := 0.0
var stall_t := 0.0
var shake := 0.0
var cam_base := Vector3.ZERO
var dim_rect: ColorRect

var modo_jogo := "padrao"
var dificuldade := "normal"
var materias_sel: Array = ["Matemática"]
var used: Dictionary = {}
var ultima_cat := ""
var stats: Dictionary = {}

var quiz: Dictionary = {}
var quiz_tipo := "LARGA"
var quiz_left := 0.0
var quiz_total := 15.0
var quiz_answered := false
var quiz_fb := 0.0

var hud_label: Label
var hud_status_label: Label
var hud_effects_label: Label
var msg_label: Label
var hint_label: Label
var quiz_box: CenterContainer
var quiz_cat: Label
var quiz_sub: Label
var quiz_text: Label
var quiz_bar: ProgressBar
var quiz_buttons: Array[Button] = []
var quiz_fb_label: Label
var menu_box: CenterContainer
var menu_vb: VBoxContainer
var quiz_checks: Dictionary = {}


func _ready() -> void:
	randomize()
	var win := get_window()
	win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size = Vector2i(1920, 1080)
	record_store = RecordStoreScript.new(save_path)
	hi = load_hi()
	bank = QuizBankScript.new()
	bank.load_json(QUESTIONS_PATH)
	setup_input()
	setup_sfx()
	setup_env()
	setup_world()
	build_ui()
	stats = {"total": 0, "acertos": 0, "por_cat": {}, "tempo": 0.0}
	set_state("MENU")


# ---------------------------------------------------------------- sons
func make_seq(notes: Array, vol := 0.22) -> AudioStreamWAV:
	var rate := 22050
	var total := 0
	for n in notes:
		total += int(rate * float(n[1]))
	var buf := PackedByteArray()
	buf.resize(total * 2)
	var idx := 0
	for n in notes:
		var f: float = n[0]
		var cnt := int(rate * float(n[1]))
		for i in cnt:
			var env := 1.0 - 0.85 * float(i) / cnt
			var v := vol if sin(TAU * f * i / rate) >= 0.0 else -vol
			buf.encode_s16(idx * 2, int(v * env * 32767.0))
			idx += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = buf
	return w


func sfx_add(nome: String, notes: Array, vol := 0.22) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = make_seq(notes, vol)
	add_child(p)
	sfx_players[nome] = p


func setup_sfx() -> void:
	sfx_add("raquete", [[440, 0.05]])
	sfx_add("parede", [[330, 0.03]], 0.12)
	sfx_add("bloco", [[660, 0.05]])
	sfx_add("duro", [[250, 0.05]], 0.2)
	sfx_add("drop", [[520, 0.06], [780, 0.08]])
	sfx_add("certo", [[523, 0.08], [659, 0.08], [784, 0.08], [1047, 0.16]])
	sfx_add("errado", [[300, 0.12], [200, 0.22]])
	sfx_add("vida", [[220, 0.15], [180, 0.15], [140, 0.3]])
	sfx_add("laser", [[900, 0.04]], 0.1)
	sfx_add("nivel", [[392, 0.1], [523, 0.1], [659, 0.1], [784, 0.25]])


func sfx_play(nome: String) -> void:
	if sfx_players.has(nome):
		var p: AudioStreamPlayer = sfx_players[nome]
		p.play()


# ---------------------------------------------------------------- cena
func mat(c: Color, emis := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.2
	m.roughness = 0.45
	if emis > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emis
	return m


func box(size: Vector3, c: Color, pos: Vector3, emis := 0.0, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c, emis)
	mi.position = pos
	if parent == null:
		parent = world
	parent.add_child(mi)
	return mi


func setup_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(10, 10, 26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color8(140, 140, 190)
	env.ambient_light_energy = 0.7
	env.glow_enabled = true
	we.environment = env
	add_child(we)

	cam = Camera3D.new()
	cam.fov = 48.0
	cam.position = Vector3(0, -11.5, 27)
	add_child(cam)
	cam.look_at(Vector3(0, -1.2, 0), Vector3.UP)
	cam_base = cam.position

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28, 18, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)

	ball_light = OmniLight3D.new()
	ball_light.omni_range = 10.0
	ball_light.light_energy = 1.2
	ball_light.position = Vector3(0, PADDLE_Y, 3)
	add_child(ball_light)


func setup_world() -> void:
	scenery = Node3D.new()
	add_child(scenery)
	world = Node3D.new()
	add_child(world)

	var floor_mesh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(HALF_W * 2.0 + 6.0, 28.0)
	floor_mesh.mesh = q
	floor_mesh.material_override = mat(Color8(22, 14, 44))
	floor_mesh.position = Vector3(0, -0.5, -0.6)
	scenery.add_child(floor_mesh)

	# grade do fundo
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-14, 15, 2):
		im.surface_add_vertex(Vector3(i, BOTTOM_Y, -0.55))
		im.surface_add_vertex(Vector3(i, TOP_Y, -0.55))
	for j in range(-10, 11, 2):
		im.surface_add_vertex(Vector3(-HALF_W, j, -0.55))
		im.surface_add_vertex(Vector3(HALF_W, j, -0.55))
	im.surface_end()
	var grid := MeshInstance3D.new()
	grid.mesh = im
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color8(45, 40, 90)
	grid.material_override = gm
	scenery.add_child(grid)

	var wall_c := Color8(70, 70, 140)
	box(Vector3(0.6, 22.0, 1.2), wall_c, Vector3(-HALF_W - 0.3, -0.75, 0), 0.4, scenery)
	box(Vector3(0.6, 22.0, 1.2), wall_c, Vector3(HALF_W + 0.3, -0.75, 0), 0.4, scenery)
	box(Vector3(HALF_W * 2.0 + 1.2, 0.6, 1.2), wall_c, Vector3(0, TOP_Y + 0.3, 0), 0.4, scenery)

	paddle = box(Vector3(PADDLE_BASE_W, PADDLE_H, 0.8), Color8(90, 200, 255), Vector3(0, PADDLE_Y, 0), 0.35)
	paddle_mat = paddle.material_override
	for i in 2:
		emit_nodes.append(box(Vector3(0.18, 0.3, 0.3), Color8(255, 70, 70), Vector3(0, PADDLE_Y + 0.35, 0), 1.5))
		(emit_nodes[i] as MeshInstance3D).visible = false


# ---------------------------------------------------------------- bolas
func new_ball(pos: Vector2, vel: Vector2, stuck: bool) -> Dictionary:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = BALL_R
	sm.height = BALL_R * 2.0
	mi.mesh = sm
	var bmat := mat(Color8(255, 240, 200), 1.2)
	mi.material_override = bmat
	world.add_child(mi)
	var tmat := mat(Color8(90, 130, 220), 1.0)
	var trail: Array = []
	for i in 8:
		var tn := MeshInstance3D.new()
		tn.mesh = sm
		tn.material_override = tmat
		tn.visible = false
		tn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(tn)
		trail.append(tn)
	return {"node": mi, "mat": bmat, "tmat": tmat, "trail": trail, "hist": [],
		"pos": pos, "vel": vel, "stuck": stuck, "off": 0.0}


func free_ball(b: Dictionary) -> void:
	b.node.queue_free()
	for tn in b.trail:
		tn.queue_free()


func reset_ball() -> void:
	for b in balls:
		free_ball(b)
	balls.clear()
	balls.append(new_ball(Vector2(paddle.position.x, PADDLE_Y + 1.0), Vector2.ZERO, true))
	accel = 1.0


func any_stuck() -> bool:
	for b in balls:
		if b.stuck:
			return true
	return false


func ball_speed() -> float:
	var dif: Dictionary = DIFS[dificuldade]
	var v: float = minf((4.8 + float(dif.cresc) * (level - 1)) * float(dif.fator), float(dif.limite)) * accel * SPEED_K
	if active.has("LENTA"):
		v *= 0.65
	if active.has("BOLA_RAPIDA"):
		v *= 1.35
	return v


func launch() -> void:
	var sp := ball_speed()
	for b in balls:
		if b.stuck:
			var half := maxf(1.0, paddle_w * 0.5)
			var off := float(b.off) / half
			var ang := deg_to_rad(off * 55.0 if float(b.off) != 0.0 else randf_range(-25.0, 25.0))
			b.vel = Vector2(sin(ang), cos(ang)) * sp
			b.stuck = false
			b.off = 0.0


func fix_speed(v: Vector2, sp: float) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2(0, sp)
	v = v.normalized() * sp
	var mn := sp * 0.3
	if absf(v.y) < mn:
		var sy := 1.0 if v.y >= 0.0 else -1.0
		var sx := 1.0 if v.x >= 0.0 else -1.0
		v = Vector2(sx * sqrt(sp * sp - mn * mn), sy * mn)
	return v


# ---------------------------------------------------------------- blocos
func add_brick(tipo: String, pos: Vector2, r: int, hp: int) -> void:
	var node: MeshInstance3D
	var col := ROW_COLORS[r]
	if tipo == "obstaculo":
		col = Color8(105, 112, 128)
		node = box(Vector3(BR_W, BR_H, 1.0), col, Vector3(pos.x, pos.y, 0), 0.1)
	elif tipo == "bomba":
		col = Color8(55, 43, 62)
		node = box(Vector3(BR_W, BR_H, 0.8), col, Vector3(pos.x, pos.y, 0), 0.7)
		var sm := SphereMesh.new()
		sm.radius = 0.25
		sm.height = 0.5
		var core := MeshInstance3D.new()
		core.mesh = sm
		core.material_override = mat(Color8(255, 205, 85), 2.0)
		core.position = Vector3(0, 0, 0.5)
		node.add_child(core)
	else:
		node = box(Vector3(BR_W, BR_H, 0.8), col, Vector3(pos.x, pos.y, 0), 0.15)
	var br := {"node": node, "pos": pos, "hp": hp, "max": hp, "pts": ROW_PTS[r] if tipo == "normal" else 0,
		"color": col, "tipo": tipo}
	bricks.append(br)
	tint(br)


func tint(br: Dictionary) -> void:
	if br.tipo != "normal":
		return
	var base: Color = br.color
	var m: StandardMaterial3D = br.node.material_override
	m.albedo_color = base.lerp(Color(0.85, 0.85, 0.9), 0.35 * (int(br.hp) - 1))


func build_bricks() -> void:
	for br in bricks:
		br.node.queue_free()
	bricks.clear()
	var total_w := COLS * BR_W + (COLS - 1) * BR_GAP
	var x0 := -total_w / 2.0 + BR_W / 2.0
	for cell in LevelGenScript.generate(level, modo_jogo, DIFS[dificuldade]):
		var pos := Vector2(x0 + int(cell.c) * (BR_W + BR_GAP), 8.0 - int(cell.r) * 0.9)
		add_brick(cell.tipo, pos, cell.r, cell.hp)


func clear_dynamic() -> void:
	for d in drops:
		d.node.queue_free()
	drops.clear()
	for l in lasers:
		l.node.queue_free()
	lasers.clear()


func load_level() -> void:
	build_bricks()
	clear_dynamic()
	active.clear()
	quiz = {}
	freeze = 0.0
	cooldown_laser = 0.0
	stall_t = 0.0
	reset_ball()


func start_game() -> void:
	score = 0
	lives = 3
	level = 1
	stats = {"total": 0, "acertos": 0, "por_cat": {}, "tempo": 0.0}
	ultima_cat = ""
	used.clear()
	bank.revisit.clear()
	drop_cd = 0.0
	paddle_w = PADDLE_BASE_W
	paddle.position.x = 0.0
	load_level()
	set_state("JOGANDO")


func lose_life() -> void:
	lives -= 1
	shake = 0.6
	sfx_play("vida")
	active.clear()
	clear_dynamic()
	if lives <= 0:
		finish_game()
	else:
		reset_ball()
		freeze = 0.5


func finish_game() -> void:
	novo_recorde = score > load_hi()
	hi = maxi(hi, score)
	save_hi()
	set_state("FIM")


func load_hi() -> int:
	return record_store.load_score()


func save_hi() -> void:
	record_store.save_score(hi)


# ---------------------------------------------------------------- acertos / bombas
func hit_brick(br: Dictionary, destroy := false) -> void:
	if not bricks.has(br):
		return
	if br.tipo == "obstaculo":
		return
	stall_t = 0.0
	if br.tipo == "bomba":
		explode_bomb(br)
		return
	br.hp = 0 if destroy else int(br.hp) - 1
	var node: MeshInstance3D = br.node
	if int(br.hp) > 0:
		sfx_play("duro")
		tint(br)
		burst(node.position, Color(0.9, 0.9, 0.95), 4)
		return
	bricks.erase(br)
	var p: Vector2 = br.pos
	var col: Color = br.color
	score += int(br.pts) * level * (2 if active.has("X2") else 1)
	sfx_play("bloco")
	burst(node.position, col, 12)
	node.queue_free()
	shake = maxf(shake, 0.08)
	if drop_cd <= 0.0 and randf() < DROP_CHANCE and drops.size() < MAX_DROPS:
		drop_cd = DROP_COOLDOWN
		spawn_drop(p)


func explode_bomb(b0: Dictionary) -> void:
	var queue: Array = [b0]
	var palette: Array[Color] = [Color8(255, 90, 40), Color8(255, 190, 50), Color8(230, 230, 210)]
	while not queue.is_empty():
		var cur: Dictionary = queue.pop_back()
		if not bricks.has(cur) or cur.tipo != "bomba":
			continue
		bricks.erase(cur)
		var cp: Vector2 = cur.pos
		cur.node.queue_free()
		sfx_play("bloco")
		for i in 3:
			burst(Vector3(cp.x, cp.y, 0), palette[i], 9)
		float_text("BOOM!", Vector3(cp.x, cp.y, 1.0), Color8(255, 150, 60))
		shake = maxf(shake, 0.5)
		for nb in bricks.duplicate():
			var np: Vector2 = nb.pos
			if cp.distance_to(np) > 2.3:
				continue
			if nb.tipo == "bomba":
				queue.append(nb)
			elif nb.tipo == "normal":
				hit_brick(nb, true)


func spawn_drop(p: Vector2) -> void:
	var total := 0
	for k in BOOST_WEIGHTS:
		total += int(BOOST_WEIGHTS[k])
	var roll := randi() % total
	var tipo := "LARGA"
	for k in BOOST_WEIGHTS:
		roll -= int(BOOST_WEIGHTS[k])
		if roll < 0:
			tipo = k
			break
	var info: Dictionary = BOOSTS[tipo]
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.8
	mi.mesh = cm
	mi.material_override = mat(info.cor, 1.0)
	mi.rotation_degrees.z = 90.0
	mi.position = Vector3(p.x, p.y, 0)
	world.add_child(mi)
	var lb := Label3D.new()
	lb.text = str(info.icone) + "?"
	lb.font_size = 64
	lb.pixel_size = 0.012
	lb.outline_size = 12
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = Vector3(0, 0, 0.6)
	mi.add_child(lb)
	drops.append({"node": mi, "pos": p, "tipo": tipo, "t": 0.0})


func burst(pos: Vector3, col: Color, n: int) -> void:
	var m := mat(col, 0.8)
	for i in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE * randf_range(0.12, 0.25)
		mi.mesh = bm
		mi.material_override = m
		mi.position = pos
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(mi)
		fx.append({"node": mi, "life": 0.7,
			"vel": Vector3(randf_range(-4, 4), randf_range(-3, 5), randf_range(1, 6))})


func float_text(txt: String, pos: Vector3, col: Color) -> void:
	var lb := Label3D.new()
	lb.text = txt
	lb.font_size = 56
	lb.pixel_size = 0.012
	lb.outline_size = 14
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.position = pos
	world.add_child(lb)
	texts.append({"node": lb, "life": 1.4})


func update_fx(delta: float) -> void:
	for f in fx.duplicate():
		var v: Vector3 = f.vel
		v.y -= 9.0 * delta
		f.vel = v
		f.life = float(f.life) - delta
		var n: MeshInstance3D = f.node
		n.position += v * delta
		n.scale = Vector3.ONE * clampf(float(f.life) / 0.7, 0.0, 1.0)
		if float(f.life) <= 0.0:
			n.queue_free()
			fx.erase(f)
	for t in texts.duplicate():
		var lb: Label3D = t.node
		lb.position.y += 0.9 * delta
		t.life = float(t.life) - delta
		lb.modulate.a = clampf(float(t.life), 0.0, 1.0)
		if float(t.life) <= 0.0:
			lb.queue_free()
			texts.erase(t)


# ---------------------------------------------------------------- física
func step_ball(b: Dictionary, dt: float) -> bool:
	var pos: Vector2 = b.pos
	var vel: Vector2 = b.vel
	var fire := active.has("FOGO")
	var steps := maxi(1, int(ceil(vel.length() * dt / 0.2)))
	var h := dt / steps
	for _i in steps:
		pos += vel * h
		if pos.x < -HALF_W + BALL_R:
			pos.x = -HALF_W + BALL_R
			vel.x = absf(vel.x)
			sfx_play("parede")
		elif pos.x > HALF_W - BALL_R:
			pos.x = HALF_W - BALL_R
			vel.x = -absf(vel.x)
			sfx_play("parede")
		if pos.y > TOP_Y - BALL_R:
			pos.y = TOP_Y - BALL_R
			vel.y = -absf(vel.y)
			sfx_play("parede")

		var hits: Array = []
		for br in bricks:
			var c: Vector2 = br.pos
			var cl := Vector2(
				clampf(pos.x, c.x - BR_W * 0.5, c.x + BR_W * 0.5),
				clampf(pos.y, c.y - BR_H * 0.5, c.y + BR_H * 0.5))
			var d := pos - cl
			if d.length_squared() < BALL_R * BALL_R:
				hits.append({"br": br, "d": d, "cl": cl})
		if not hits.is_empty():
			var chosen: Dictionary = {}
			for hh in hits:
				if hh.br.tipo == "obstaculo":
					chosen = hh
					break
			var is_obs := not chosen.is_empty()
			if not is_obs and fire:
				for hh in hits:
					hit_brick(hh.br, true)
			else:
				if not is_obs:
					chosen = hits[0]
				var dd: Vector2 = chosen.d
				var cc: Vector2 = chosen.cl
				if dd == Vector2.ZERO:
					vel.y = -vel.y
				elif absf(dd.x) > absf(dd.y):
					vel.x = signf(dd.x) * absf(vel.x)
					pos.x = cc.x + signf(dd.x) * BALL_R
				else:
					vel.y = signf(dd.y) * absf(vel.y)
					pos.y = cc.y + signf(dd.y) * BALL_R
				if is_obs:
					sfx_play("duro")
					vel = vel.rotated(deg_to_rad(randf_range(-3.0, 3.0)))
				else:
					hit_brick(chosen.br)

		# raquete
		if vel.y < 0.0 and pos.y - BALL_R <= PADDLE_Y + PADDLE_H * 0.5 and pos.y >= PADDLE_Y \
				and absf(pos.x - paddle.position.x) <= paddle_w * 0.5 + BALL_R:
			var off := clampf((pos.x - paddle.position.x) / (paddle_w * 0.5) + randf_range(-0.05, 0.05), -1.0, 1.0)
			var ang := deg_to_rad(off * 60.0)
			var sp := vel.length()
			vel = Vector2(sin(ang), cos(ang)) * sp
			pos.y = PADDLE_Y + PADDLE_H * 0.5 + BALL_R
			accel = minf(1.3, accel + 0.01)
			sfx_play("raquete")
			if active.has("IMA"):
				b.stuck = true
				b.off = pos.x - paddle.position.x
				b.pos = pos
				b.vel = Vector2.ZERO
				return true

		if pos.y < BOTTOM_Y:
			b.pos = pos
			b.vel = vel
			return false
	b.pos = pos
	b.vel = vel
	return true


func fire_laser() -> void:
	var half := paddle_w * 0.5 - 0.18
	for dx in [-half, half]:
		var px: float = paddle.position.x + dx
		var node := box(Vector3(0.09, 0.3, 0.09), Color8(255, 90, 90), Vector3(px, PADDLE_Y + 0.3, 0), 2.0)
		lasers.append({"node": node, "pos": Vector2(px, PADDLE_Y + 0.3)})
	cooldown_laser = 0.22
	sfx_play("laser")


func update_lasers(delta: float) -> void:
	for l in lasers.duplicate():
		var p: Vector2 = l.pos
		p.y += 15.0 * delta
		l.pos = p
		var n: MeshInstance3D = l.node
		n.position = Vector3(p.x, p.y, 0)
		var target = null
		for br in bricks:
			var bp: Vector2 = br.pos
			if absf(p.x - bp.x) < BR_W * 0.5 + 0.045 and absf(p.y - bp.y) < BR_H * 0.5 + 0.15:
				target = br
				break
		if target != null:
			hit_brick(target)
			n.queue_free()
			lasers.erase(l)
		elif p.y > TOP_Y:
			n.queue_free()
			lasers.erase(l)


func update_paddle(delta: float) -> void:
	var dir := 0.0
	dir = Input.get_axis("esq", "dir")
	var spd := 18.0 * (0.55 if active.has("RAQUETE_LENTA") else 1.0)
	var x := paddle.position.x
	if dir != 0.0:
		use_mouse = false
		x += dir * spd * delta
	elif use_mouse:
		x = (mouse_ratio - 0.5) * 2.0 * HALF_W * 1.05
	var target := PADDLE_BASE_W * (1.5 if active.has("LARGA") else 1.0) * (0.65 if active.has("ENCOLHE") else 1.0)
	paddle_w = lerpf(paddle_w, target, minf(1.0, delta * 10.0))
	paddle.scale.x = paddle_w / PADDLE_BASE_W
	paddle.position.x = clampf(x, -HALF_W + paddle_w * 0.5, HALF_W - paddle_w * 0.5)

	var cor := Color8(90, 200, 255)
	if active.has("ENCOLHE") or active.has("RAQUETE_LENTA"):
		cor = Color8(150, 150, 160)
	if active.has("IMA"):
		var ic: Color = BOOSTS["IMA"].cor
		cor = ic
	paddle_mat.albedo_color = cor
	paddle_mat.emission = cor
	var half := paddle_w * 0.5 - 0.18
	for i in 2:
		var en: MeshInstance3D = emit_nodes[i]
		en.visible = active.has("LASER")
		en.position = Vector3(paddle.position.x + (-half if i == 0 else half), PADDLE_Y + 0.35, 0)


func update_drops(delta: float) -> void:
	for d in drops.duplicate():
		var p: Vector2 = d.pos
		p.y -= 5.5 * delta
		d.pos = p
		d.t = float(d.t) + delta
		var n: MeshInstance3D = d.node
		n.position = Vector3(p.x, p.y, 0)
		var m: StandardMaterial3D = n.material_override
		m.emission_energy_multiplier = 1.0 + 0.8 * sin(float(d.t) * 8.0)
		if absf(p.x - paddle.position.x) <= paddle_w * 0.5 + 0.8 and absf(p.y - PADDLE_Y) <= 0.8:
			var tipo: String = d.tipo
			drops.erase(d)
			n.queue_free()
			open_quiz(tipo)
			return
		elif p.y < BOTTOM_Y - 1.0:
			drops.erase(d)
			n.queue_free()


# ---------------------------------------------------------------- perguntas
func pick_question() -> Dictionary:
	return bank.pick(materias_sel, ultima_cat, used, level)


# ---------------------------------------------------------------- quiz
func open_quiz(tipo: String) -> void:
	quiz = pick_question()
	ultima_cat = quiz.cat
	used["%s|%s|%s" % [quiz.cat, quiz.text, "/".join(quiz.opts)]] = true
	quiz_tipo = tipo
	var dif: Dictionary = DIFS[dificuldade]
	quiz_total = float(maxi(8, int(dif.tempo) - int((level - 1) * 0.8)))
	quiz_left = quiz_total
	quiz_answered = false
	quiz_fb = 0.0
	var info: Dictionary = BOOSTS[tipo]
	var tag := "REVISÃO" if quiz.get("revisao", false) else "QUESTIONÁRIO"
	quiz_cat.text = "%s  •  %s" % [tag, String(quiz.cat).to_upper()]
	quiz_sub.text = "Acerte e ganhe: %s — %s" % [info.nome, info.desc]
	quiz_sub.modulate = info.cor
	quiz_text.text = quiz.text
	for i in 4:
		quiz_buttons[i].text = "%d)  %s" % [i + 1, quiz.opts[i]]
		quiz_buttons[i].modulate = Color.WHITE
	quiz_buttons[0].grab_focus()
	quiz_fb_label.text = "Teclas 1-4 ou clique  •  Resposta rápida = mais pontos"
	quiz_fb_label.modulate = Color(0.7, 0.7, 0.8)
	set_state("QUIZ")
	sfx_play("drop")


func answer(i: int) -> void:
	if state != "QUIZ" or quiz_answered:
		return
	quiz_answered = true
	quiz_fb = 2.4
	var cat: String = quiz.cat
	var pc: Dictionary = stats.por_cat
	if not pc.has(cat):
		pc[cat] = [0, 0]
	pc[cat][1] += 1
	stats.total = int(stats.total) + 1
	stats.tempo = float(stats.tempo) + (quiz_total - quiz_left)
	quiz_buttons[int(quiz.correct)].modulate = Color8(90, 230, 130)
	if i == int(quiz.correct):
		pc[cat][0] += 1
		stats.acertos = int(stats.acertos) + 1
		var bonus := (50 + int(quiz_left * 10.0)) * level
		score += bonus
		active.erase("ENCOLHE")
		apply_boost(quiz_tipo)
		var info: Dictionary = BOOSTS[quiz_tipo]
		quiz_fb_label.text = "CORRETO!  +%d pts  •  %s ativado" % [bonus, info.nome]
		quiz_fb_label.modulate = Color8(90, 230, 130)
		sfx_play("certo")
	else:
		bank.note_wrong(quiz)
		if i >= 0:
			quiz_buttons[i].modulate = Color8(240, 90, 90)
		var keys := DOWNGRADES.keys()
		var key: String = keys.pick_random()
		var dg: Dictionary = DOWNGRADES[key]
		active[key] = float(dg.dur)
		float_text(str(dg.nome) + "!", Vector3(paddle.position.x, PADDLE_Y + 2.0, 1.0), dg.cor)
		if i < 0:
			quiz_fb_label.text = "TEMPO ESGOTADO!  Resposta: %s  •  %s" % [quiz.ans, dg.nome]
		else:
			quiz_fb_label.text = "ERROU!  Resposta: %s  •  %s por %ds" % [quiz.ans, dg.nome, int(dg.dur)]
		quiz_fb_label.modulate = Color8(240, 90, 90)
		sfx_play("errado")


func close_quiz() -> void:
	quiz = {}
	set_state("JOGANDO")
	freeze = 0.7


func apply_boost(tipo: String) -> void:
	var info: Dictionary = BOOSTS[tipo]
	match tipo:
		"MULTI":
			var src := Vector2(paddle.position.x, PADDLE_Y + 1.0)
			var loose: Array = []
			for b in balls:
				if not b.stuck:
					loose.append(b)
			if not loose.is_empty():
				src = loose[0].pos
			var sp := ball_speed()
			for deg in [-30.0, 30.0]:
				var a := deg_to_rad(deg)
				if balls.size() < MAX_BALLS:
					balls.append(new_ball(src, Vector2(sin(a), cos(a)) * sp, false))
		"VIDA":
			lives = mini(9, lives + 1)
		_:
			active[tipo] = minf(30.0, float(active.get(tipo, 0.0)) + float(info.dur))
	float_text(str(info.nome) + "!", Vector3(paddle.position.x, PADDLE_Y + 2.0, 1.0), info.cor)


# ---------------------------------------------------------------- loop
func set_state(s: String) -> void:
	state = s
	world.visible = s in ["JOGANDO", "QUIZ", "PAUSA", "NIVEL"]
	menu_box.visible = s in ["MENU", "AJUDA", "SELECAO_MODO", "SELECAO_DIFICULDADE", "SELECAO_QUIZ"]
	var a := 0.0
	match s:
		"QUIZ":
			a = 0.7
		"PAUSA", "NIVEL":
			a = 0.55
		"FIM":
			a = 0.7
		"MENU", "AJUDA", "SELECAO_MODO", "SELECAO_DIFICULDADE", "SELECAO_QUIZ":
			a = 0.55
	dim_rect.color.a = a
	quiz_box.visible = s == "QUIZ"
	if menu_box.visible:
		call_deferred("rebuild_menu")


func _process(delta: float) -> void:
	var visual_delta := minf(delta, 0.1)
	t_anim += visual_delta
	update_shake(visual_delta)
	update_fx(visual_delta)
	sim_accumulator = minf(sim_accumulator + maxf(delta, 0.0), MAX_CATCH_UP)
	while sim_accumulator >= SIM_STEP:
		process_game_step(SIM_STEP)
		sim_accumulator -= SIM_STEP
	update_hud()


func process_game_step(delta: float) -> void:
	match state:
		"QUIZ":
			if not quiz_answered:
				quiz_left -= delta
				quiz_bar.value = maxf(0.0, quiz_left) / quiz_total * 100.0
				quiz_bar.modulate = Color8(220, 70, 70).lerp(Color8(70, 200, 110), maxf(0.0, quiz_left) / quiz_total)
				if quiz_left <= 0.0:
					quiz_left = 0.0
					answer(-1)
			else:
				quiz_fb -= delta
				if quiz_fb <= 0.0:
					close_quiz()
		"NIVEL":
			level_timer -= delta
			if level_timer <= 0.0:
				level += 1
				load_level()
				set_state("JOGANDO")
		"JOGANDO":
			update_game(delta)


func update_game(delta: float) -> void:
	drop_cd -= delta
	if freeze <= 0.0 and not any_stuck():
		stall_t += delta
		if stall_t > STALL_LIMIT:
			stall_t = STALL_LIMIT - 3.0
			for sb in balls:
				if not sb.stuck:
					var sv: Vector2 = sb.vel
					sb.vel = sv.rotated(deg_to_rad(randf_range(-30.0, 30.0)))
	for k in active.keys():
		active[k] = float(active[k]) - delta
		if float(active[k]) <= 0.0:
			active.erase(k)
			if k == "IMA":
				launch()

	update_paddle(delta)

	cooldown_laser -= delta
	if active.has("LASER") and Input.is_action_pressed("lancar") and cooldown_laser <= 0.0 and not any_stuck():
		fire_laser()
	update_lasers(delta)

	if freeze > 0.0:
		freeze -= delta
	var sp := ball_speed()
	var fire := active.has("FOGO")
	for b in balls.duplicate():
		if b.stuck:
			b.pos = Vector2(paddle.position.x + float(b.off), PADDLE_Y + PADDLE_H * 0.5 + BALL_R + 0.02)
			b.hist.clear()
		elif freeze <= 0.0:
			b.vel = fix_speed(b.vel, sp)
			var alive := step_ball(b, delta)
			b.hist.append(b.pos)
			while b.hist.size() > 8:
				b.hist.pop_front()
			if not alive:
				free_ball(b)
				balls.erase(b)
				continue
		var p: Vector2 = b.pos
		var bn: MeshInstance3D = b.node
		bn.position = Vector3(p.x, p.y, 0)
		var bm: StandardMaterial3D = b.mat
		bm.albedo_color = Color8(255, 150, 40) if fire else Color8(255, 240, 200)
		bm.emission = bm.albedo_color
		var tm: StandardMaterial3D = b.tmat
		tm.albedo_color = Color8(255, 130, 40) if fire else Color8(90, 130, 220)
		tm.emission = tm.albedo_color
		var n: int = b.hist.size()
		for i in 8:
			var tn: MeshInstance3D = b.trail[i]
			if i < n:
				var hp: Vector2 = b.hist[i]
				tn.visible = true
				tn.position = Vector3(hp.x, hp.y, 0)
				tn.scale = Vector3.ONE * (float(i + 1) / n * 0.8)
			else:
				tn.visible = false

	if balls.is_empty():
		lose_life()
		return
	var first: Vector2 = balls[0].pos
	ball_light.position = Vector3(first.x, first.y, 3)

	update_drops(delta)
	if state != "JOGANDO":
		return

	if score > hi:
		hi = score

	var remaining := false
	for br in bricks:
		if br.tipo == "normal":
			remaining = true
			break
	if not remaining:
		for br in bricks:
			br.node.queue_free()
		bricks.clear()
		level_bonus = lives * 100 * level
		score += level_bonus
		hi = maxi(hi, score)
		save_hi()
		level_timer = 2.5
		sfx_play("nivel")
		set_state("NIVEL")


# ---------------------------------------------------------------- HUD
func update_hud() -> void:
	var show_hud := state in ["JOGANDO", "QUIZ", "PAUSA", "NIVEL"]
	hud_label.visible = show_hud
	hud_status_label.visible = show_hud
	hud_effects_label.visible = show_hud
	var boost_items: Array[String] = []
	for k in active:
		var info: Dictionary = BOOSTS[k] if BOOSTS.has(k) else DOWNGRADES[k]
		boost_items.append("%s %ds" % [info.nome, int(ceil(float(active[k])))])
	hud_label.text = "PONTOS %06d    RECORDE %06d    NÍVEL %d" % [score, maxi(hi, score), level]
	hud_status_label.text = "VIDAS %d    QUIZ %d/%d" % [lives, int(stats.get("acertos", 0)), int(stats.get("total", 0))]
	hud_effects_label.text = "  •  ".join(boost_items)

	var hint := ""
	if state == "JOGANDO":
		if any_stuck():
			if int(t_anim * 2.0) % 2 == 0:
				hint = "ESPAÇO ou clique para lançar"
		elif freeze > 0.0:
			hint = "Prepare-se!"
	hint_label.text = hint

	var msg := ""
	match state:
		"PAUSA":
			msg = "PAUSADO\nP / ESC: continuar   •   Q: encerrar partida"
		"NIVEL":
			msg = "NÍVEL %d CONCLUÍDO!\nBônus de vidas: +%d" % [level, level_bonus]
		"FIM":
			msg = fim_text()
	msg_label.text = msg


func fim_text() -> String:
	var total := int(stats.total)
	var ok := int(stats.acertos)
	var pct := (100.0 * ok / total) if total > 0 else 0.0
	var medio := (float(stats.tempo) / total) if total > 0 else 0.0
	var s := "FIM DE JOGO\n"
	s += "Pontuação: %d   •   Nível: %d\n" % [score, level]
	if novo_recorde:
		s += "NOVO RECORDE!\n"
	else:
		s += "Recorde: %d\n" % hi
	s += "\nDESEMPENHO NOS QUESTIONÁRIOS\n"
	s += "Respondidas: %d   •   Acertos: %d (%.0f%%)   •   Tempo médio: %.1fs\n\n" % [total, ok, pct, medio]
	var pc: Dictionary = stats.por_cat
	if pc.is_empty():
		s += "Nenhuma cápsula coletada nesta partida.\n"
	var names := pc.keys()
	names.sort_custom(func(a, b): return int(pc[a][1]) > int(pc[b][1]))
	for nm in names:
		var ac: int = pc[nm][0]
		var tt: int = pc[nm][1]
		var filled := int(round(10.0 * ac / tt)) if tt > 0 else 0
		s += "%s  [%s%s]  %d/%d\n" % [nm, "#".repeat(filled), "-".repeat(10 - filled), ac, tt]
	s += "\nENTER: jogar de novo   •   M: menu   •   ESC: sair"
	return s


# ---------------------------------------------------------------- UI
func make_label(size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 6)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


func build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)

	dim_rect = ColorRect.new()
	dim_rect.color = Color(0, 0, 0, 0.0)
	dim_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(dim_rect)
	dim_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	hud_label = make_label(22)
	hud_label.position = Vector2(20, 12)
	hud_label.add_theme_color_override("font_color", Color8(255, 220, 135))
	cl.add_child(hud_label)

	hud_status_label = make_label(18)
	hud_status_label.position = Vector2(20, 46)
	hud_status_label.add_theme_color_override("font_color", Color8(155, 220, 235))
	cl.add_child(hud_status_label)

	hud_effects_label = make_label(17)
	hud_effects_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud_effects_label.offset_left = -760
	hud_effects_label.offset_right = -24
	hud_effects_label.offset_top = 18
	hud_effects_label.offset_bottom = 72
	hud_effects_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_effects_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud_effects_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud_effects_label.add_theme_color_override("font_color", Color8(185, 225, 190))
	cl.add_child(hud_effects_label)

	msg_label = make_label(30)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(msg_label)
	msg_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	hint_label = make_label(24)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(hint_label)
	hint_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint_label.offset_top = -120
	hint_label.offset_bottom = -80

	# quiz
	quiz_box = CenterContainer.new()
	quiz_box.visible = false
	cl.add_child(quiz_box)
	quiz_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(800, 0)
	panel.add_theme_stylebox_override("panel", panel_style())
	quiz_box.add_child(panel)
	var mg := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		mg.add_theme_constant_override("margin_" + s, 24)
	panel.add_child(mg)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	mg.add_child(vb)

	quiz_cat = Label.new()
	quiz_cat.add_theme_font_size_override("font_size", 22)
	quiz_cat.modulate = Color8(150, 210, 255)
	vb.add_child(quiz_cat)
	quiz_sub = Label.new()
	quiz_sub.add_theme_font_size_override("font_size", 18)
	vb.add_child(quiz_sub)
	quiz_text = Label.new()
	quiz_text.add_theme_font_size_override("font_size", 30)
	quiz_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_text.custom_minimum_size = Vector2(740, 80)
	vb.add_child(quiz_text)
	quiz_bar = ProgressBar.new()
	quiz_bar.max_value = 100.0
	quiz_bar.value = 100.0
	quiz_bar.show_percentage = false
	quiz_bar.custom_minimum_size = Vector2(0, 14)
	vb.add_child(quiz_bar)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	vb.add_child(grid)
	for i in 4:
		var b := Button.new()
		b.custom_minimum_size = Vector2(360, 60)
		b.focus_mode = Control.FOCUS_ALL
		b.add_theme_font_size_override("font_size", 22)
		style_button(b)
		b.pressed.connect(answer.bind(i))
		grid.add_child(b)
		quiz_buttons.append(b)
	quiz_fb_label = Label.new()
	quiz_fb_label.add_theme_font_size_override("font_size", 22)
	quiz_fb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quiz_fb_label.custom_minimum_size = Vector2(740, 60)
	vb.add_child(quiz_fb_label)

	# menus
	menu_box = CenterContainer.new()
	cl.add_child(menu_box)
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mpanel := PanelContainer.new()
	mpanel.add_theme_stylebox_override("panel", panel_style())
	menu_box.add_child(mpanel)
	var mmg := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		mmg.add_theme_constant_override("margin_" + s, 22)
	mpanel.add_child(mmg)
	menu_vb = VBoxContainer.new()
	menu_vb.add_theme_constant_override("separation", 7)
	mmg.add_child(menu_vb)


func mlabel(text: String, size := 18, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.modulate = color
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_vb.add_child(l)
	return l


func mbutton(text: String, cb: Callable, w := 380.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 46)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 21)
	style_button(b)
	b.pressed.connect(cb)
	menu_vb.add_child(b)
	return b


func button_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	return style


func style_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", button_style(Color8(31, 39, 57), Color8(68, 91, 122)))
	button.add_theme_stylebox_override("hover", button_style(Color8(44, 60, 78), Color8(100, 190, 220)))
	button.add_theme_stylebox_override("pressed", button_style(Color8(24, 34, 48), Color8(255, 205, 110)))
	button.add_theme_stylebox_override("focus", button_style(Color(0, 0, 0, 0), Color8(255, 220, 135)))


func materias_text() -> String:
	var parts: Array = []
	for m in MATERIAS:
		if materias_sel.has(m):
			parts.append("[x] " + m)
	return "   •   ".join(parts)


func rebuild_menu() -> void:
	for ch in menu_vb.get_children():
		menu_vb.remove_child(ch)
		ch.queue_free()
	quiz_checks.clear()
	var cyan := Color8(150, 210, 255)
	var gold := Color8(255, 220, 120)
	var grey := Color8(150, 150, 170)
	match state:
		"MENU":
			mlabel("BREAKOUT GENIUS", 46, gold)
			mlabel("MATEMÁTICA + CONHECIMENTOS GERAIS", 24, cyan)
			mlabel("Quebre os blocos, pegue as cápsulas e resolva a questão para ganhar o boost!", 17)
			mlabel("", 8)
			mlabel("MODO: %s   •   DIFICULDADE: %s" % [("Padrão" if modo_jogo == "padrao" else "Random"), DIFS[dificuldade].nome], 18, cyan)
			mlabel("QUIZ: " + materias_text(), 16)
			mlabel("RECORDE: %d" % hi, 20, gold)
			mlabel("", 8)
			var jb := mbutton("JOGAR", func(): set_state("SELECAO_MODO"), 280.0)
			mbutton("COMO JOGAR", func(): set_state("AJUDA"), 280.0)
			mlabel("← → / A D / mouse: mover  •  ESPAÇO: lançar / laser  •  P: pausa", 15, grey)
			jb.grab_focus()
		"AJUDA":
			mlabel("COMO JOGAR", 36, gold)
			mlabel("Pegue as cápsulas que caem dos blocos e responda ao quiz para ganhar o boost.", 16)
			mlabel("BOOSTS", 20, gold)
			var grid := GridContainer.new()
			grid.columns = 2
			grid.add_theme_constant_override("h_separation", 36)
			menu_vb.add_child(grid)
			for k in BOOSTS:
				var info: Dictionary = BOOSTS[k]
				var l := Label.new()
				l.text = "%s — %s" % [info.nome, info.desc]
				l.add_theme_font_size_override("font_size", 15)
				l.modulate = info.cor
				grid.add_child(l)
			mlabel("QUESTIONÁRIOS", 20, gold)
			mlabel("Aritmética • Tabuada • Divisão • Porcentagem • Equações\nPotências e Raízes • Frações • Expressões • Sequências • Problemas", 15)
			mlabel("Conhecimentos gerais: Geografia • Ciências • História • Cultura", 15)
			mlabel("Errou ou o tempo acabou? Downgrade por 8 s, e a matéria volta depois como REVISÃO.", 15, Color8(240, 90, 90))
			mlabel("Blocos cinza = obstáculos indestrutíveis  •  Blocos vermelhos = bombas (explosão em cadeia)", 15, grey)
			mlabel("Mover: ← → / A D / mouse / direcional  •  Lançar e atirar: ESPAÇO / botão A  •  Responder: 1-4  •  Pausa: P", 15, grey)
			mbutton("VOLTAR", func(): set_state("MENU"), 240.0).grab_focus()
		"SELECAO_MODO":
			mlabel("ESCOLHA O MODO DE JOGO", 30)
			var b1 := mbutton("1)  Padrão — fases clássicas em sequência", func(): choose_modo("padrao"))
			var b2 := mbutton("2)  Random — fases procedurais aleatórias", func(): choose_modo("random"))
			mlabel("Clique ou pressione 1/2; setas + ENTER; ESC volta", 15, grey)
			(b1 if modo_jogo == "padrao" else b2).grab_focus()
		"SELECAO_DIFICULDADE":
			mlabel("ESCOLHA A DIFICULDADE", 30)
			var btns := {}
			var i := 1
			for k in DIFS:
				var dif: Dictionary = DIFS[k]
				btns[k] = mbutton("%d)  %s — %s" % [i, dif.nome, dif.desc], choose_dificuldade.bind(k))
				i += 1
			mlabel("Clique ou pressione 1/2/3; setas + ENTER; ESC volta", 15, grey)
			(btns[dificuldade] as Button).grab_focus()
		"SELECAO_QUIZ":
			mlabel("ESCOLHA AS MATÉRIAS", 30)
			var gridq := GridContainer.new()
			gridq.columns = 2
			gridq.add_theme_constant_override("h_separation", 14)
			gridq.add_theme_constant_override("v_separation", 10)
			menu_vb.add_child(gridq)
			var idx := 1
			for m in MATERIAS:
				var cb := CheckBox.new()
				cb.text = "%d)  %s" % [idx, m]
				cb.custom_minimum_size = Vector2(300, 46)
				cb.add_theme_font_size_override("font_size", 21)
				cb.button_pressed = materias_sel.has(m)
				cb.toggled.connect(on_materia_toggled.bind(m))
				gridq.add_child(cb)
				quiz_checks[m] = cb
				idx += 1
			var start := mbutton("COMEÇAR", start_game, 260.0)
			mlabel("1-5 marcam/desmarcam; setas navegam; ENTER/ESPAÇO marca; ESC volta", 15, grey)
			(quiz_checks[MATERIAS[0]] as CheckBox).grab_focus()
			start.focus_mode = Control.FOCUS_ALL


func choose_modo(m: String) -> void:
	modo_jogo = m
	set_state("SELECAO_DIFICULDADE")


func choose_dificuldade(d: String) -> void:
	dificuldade = d
	set_state("SELECAO_QUIZ")


func on_materia_toggled(pressed: bool, m: String) -> void:
	if pressed:
		if not materias_sel.has(m):
			materias_sel.append(m)
	else:
		if materias_sel.size() > 1:
			materias_sel.erase(m)
		else:
			(quiz_checks[m] as CheckBox).set_pressed_no_signal(true)


# ---------------------------------------------------------------- entrada
func digit_of(k: int) -> int:
	if k >= KEY_1 and k <= KEY_9:
		return k - KEY_1 + 1
	if k >= KEY_KP_1 and k <= KEY_KP_9:
		return k - KEY_KP_1 + 1
	return 0


func on_primary() -> void:
	match state:
		"JOGANDO":
			if any_stuck():
				launch()
			elif active.has("LASER") and cooldown_laser <= 0.0:
				fire_laser()
		"QUIZ":
			if quiz_answered and quiz_fb < 2.0:
				close_quiz()


func _input(event: InputEvent) -> void:
	if state == "JOGANDO" and event.is_action_pressed("lancar"):
		on_primary()
		return
	if event is InputEventMouseMotion:
		mouse_ratio = (event as InputEventMouseMotion).position.x / get_viewport().get_visible_rect().size.x
		use_mouse = true
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on_primary()
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return
	var k: int = ke.keycode
	var dg := digit_of(k)
	match state:
		"MENU":
			if k == KEY_ESCAPE:
				get_tree().quit()
		"AJUDA":
			if k == KEY_ESCAPE:
				set_state("MENU")
		"SELECAO_MODO":
			if dg == 1:
				choose_modo("padrao")
			elif dg == 2:
				choose_modo("random")
			elif k == KEY_ESCAPE:
				set_state("MENU")
		"SELECAO_DIFICULDADE":
			var keys := DIFS.keys()
			if dg >= 1 and dg <= keys.size():
				choose_dificuldade(keys[dg - 1])
			elif k == KEY_ESCAPE:
				set_state("SELECAO_MODO")
		"SELECAO_QUIZ":
			if dg >= 1 and dg <= MATERIAS.size():
				var cb: CheckBox = quiz_checks[MATERIAS[dg - 1]]
				cb.button_pressed = not cb.button_pressed
			elif k == KEY_ESCAPE:
				set_state("SELECAO_DIFICULDADE")
		"JOGANDO":
			if k == KEY_P or k == KEY_ESCAPE:
				set_state("PAUSA")
		"QUIZ":
			if not quiz_answered:
				if dg >= 1 and dg <= 4:
					answer(dg - 1)
			elif quiz_fb < 2.0 and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
				close_quiz()
		"PAUSA":
			if k == KEY_P or k == KEY_ESCAPE:
				set_state("JOGANDO")
			elif k == KEY_Q:
				finish_game()
				set_state("MENU")
		"FIM":
			if k == KEY_ENTER or k == KEY_KP_ENTER:
				start_game()
			elif k == KEY_M:
				set_state("MENU")
			elif k == KEY_ESCAPE:
				get_tree().quit()



# ---------------------------------------------------------------- extras
func setup_input() -> void:
	add_input("esq", [KEY_LEFT, KEY_A], JOY_AXIS_LEFT_X, -1.0)
	add_input("dir", [KEY_RIGHT, KEY_D], JOY_AXIS_LEFT_X, 1.0)
	add_input("lancar", [KEY_SPACE], -1, 0.0, JOY_BUTTON_A)


func add_input(nome: String, keys: Array, axis := -1, axis_val := 0.0, btn := -1) -> void:
	if not InputMap.has_action(nome):
		InputMap.add_action(nome, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = int(k) as Key
		InputMap.action_add_event(nome, e)
	if axis >= 0:
		var j := InputEventJoypadMotion.new()
		j.axis = axis as JoyAxis
		j.axis_value = axis_val
		InputMap.action_add_event(nome, j)
	if btn >= 0:
		var jb := InputEventJoypadButton.new()
		jb.button_index = btn as JoyButton
		InputMap.action_add_event(nome, jb)


func update_shake(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	cam.position = cam_base + Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * shake * 0.35


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		hi = maxi(hi, score)
		save_hi()


func panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color8(22, 22, 44, 250)
	sb.border_color = Color8(75, 130, 160)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	return sb
