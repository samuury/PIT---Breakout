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
const DROP_CHANCE := 0.22
const MAX_DROPS := 3
const SPEED_K := 1.5
const SAVE_PATH := "user://recorde_breakout_matematico.txt"
const ROW_PTS := [7, 7, 5, 5, 3, 3, 1, 1]
const MATERIAS := ["Matemática", "Geografia", "Ciências", "História", "Cultura"]
const MATH_GENS := [
	["Aritmética", "q_aritmetica"], ["Tabuada", "q_tabuada"], ["Divisão", "q_divisao"],
	["Porcentagem", "q_porcentagem"], ["Equações", "q_equacao"],
	["Potências e Raízes", "q_potencia"], ["Frações", "q_fracao"],
	["Expressões", "q_expressao"], ["Sequências", "q_sequencia"], ["Problemas", "q_problema"]]

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

# Perguntas de conhecimentos gerais: [enunciado, correta, [erradas]]
var GERAIS := {
	"Geografia": [
		["Qual é a capital da Austrália?", "Canberra", ["Sydney", "Melbourne", "Perth"]],
		["Qual é o maior estado brasileiro em área?", "Amazonas", ["Pará", "Mato Grosso", "Minas Gerais"]],
		["Qual é o maior oceano da Terra?", "Oceano Pacífico", ["Oceano Atlântico", "Oceano Índico", "Oceano Ártico"]],
		["Qual rio é tradicionalmente associado ao Egito?", "Rio Nilo", ["Rio Amazonas", "Rio Danúbio", "Rio Ganges"]],
		["Qual é a capital do Japão?", "Tóquio", ["Osaka", "Quioto", "Hiroshima"]],
		["Qual é o maior deserto do mundo?", "Antártida", ["Saara", "Gobi", "Atacama"]],
		["Em qual cordilheira fica o Monte Everest?", "Himalaia", ["Andes", "Alpes", "Montanhas Rochosas"]],
		["Qual país tem formato de uma bota e fica no sul da Europa?", "Itália", ["Grécia", "Portugal", "Croácia"]],
		["Qual é a capital da França?", "Paris", ["Marselha", "Lyon", "Nantes"]],
		["Qual é o menor país do mundo?", "Vaticano", ["Mônaco", "São Marino", "Liechtenstein"]],
		["Em qual continente fica o deserto do Saara?", "África", ["Ásia", "Europa", "América"]],
		["Qual país é conhecido como a Terra do Sol Nascente?", "Japão", ["China", "Coreia do Sul", "Tailândia"]],
		["Qual é a capital da Argentina?", "Buenos Aires", ["Rosário", "Córdoba", "Montevidéu"]],
		["Qual é a capital do Canadá?", "Ottawa", ["Toronto", "Montreal", "Vancouver"]],
		["Qual é a capital do Uruguai?", "Montevidéu", ["Assunção", "Santiago", "Lima"]],
		["Qual é o rio mais longo do mundo?", "Rio Amazonas", ["Rio Nilo", "Rio Yangtzé", "Rio Mississipi"]],
		["Qual é a capital da Noruega?", "Oslo", ["Estocolmo", "Copenhague", "Helsinque"]],
		["Qual país tem a maior extensão territorial da América do Sul?", "Brasil", ["Argentina", "Peru", "Colômbia"]],
		["Em qual país fica a cidade de Lisboa?", "Portugal", ["Espanha", "Itália", "França"]],
		["Qual é a capital do México?", "Cidade do México", ["Guadalajara", "Monterrei", "Cancún"]],
		["Qual é o ponto mais alto do Brasil?", "Pico da Neblina", ["Pico Paraná", "Monte Roraima", "Pico dos Órgãos"]],
		["Qual estado brasileiro fica na região Nordeste?", "Bahia", ["Acre", "Rio Grande do Sul", "Pará"]],
		["Qual é a maior ilha do mundo?", "Groenlândia", ["Madagáscar", "Bornéu", "Nova Guiné"]],
		["Qual cidade fica na margem do Rio Tâmisa?", "Londres", ["Paris", "Berlim", "Madri"]],
		["Qual é a capital do Chile?", "Santiago", ["Valparaíso", "Lima", "Bogotá"]],
	],
	"Ciências": [
		["Qual é a fórmula química da água?", "H₂O", ["CO₂", "O₂", "NaCl"]],
		["Qual planeta é conhecido como planeta vermelho?", "Marte", ["Vênus", "Júpiter", "Mercúrio"]],
		["Qual gás as plantas absorvem principalmente na fotossíntese?", "Dióxido de carbono", ["Oxigênio", "Hidrogênio", "Hélio"]],
		["Qual é a unidade de medida da corrente elétrica?", "Ampere", ["Volt", "Watt", "Ohm"]],
		["Qual é o símbolo químico do ouro?", "Au", ["Ag", "Fe", "O"]],
		["Qual gás é mais abundante na atmosfera terrestre?", "Nitrogênio", ["Oxigênio", "Dióxido de carbono", "Hidrogênio"]],
		["Quantas câmaras tem o coração humano?", "Quatro", ["Duas", "Três", "Cinco"]],
		["A que temperatura a água congela ao nível do mar?", "0 °C", ["-10 °C", "10 °C", "32 °C"]],
		["Qual é a unidade de medida de força no Sistema Internacional?", "Newton", ["Joule", "Pascal", "Watt"]],
		["Qual destes animais é um mamífero?", "Golfinho", ["Tubarão", "Polvo", "Truta"]],
		["Qual é o órgão responsável pela circulação sanguínea?", "Coração", ["Pulmão", "Fígado", "Rim"]],
		["Qual é o processo pelo qual a água passa do estado líquido para o gasoso?", "Evaporação", ["Condensação", "Solidificação", "Liquefação"]],
		["Qual é a camada mais externa da Terra?", "Crosta", ["Manto", "Núcleo", "Mesosfera"]],
		["Qual parte da célula contém o material genético?", "Núcleo", ["Membrana", "Mitocôndria", "Ribossomo"]],
		["Qual é o gás liberado pelos seres vivos na respiração?", "Dióxido de carbono", ["Oxigênio", "Nitrogênio", "Hidrogênio"]],
		["Qual elemento químico possui o símbolo Na?", "Sódio", ["Nióbio", "Níquel", "Neônio"]],
		["Qual é a menor unidade viva?", "Célula", ["Átomo", "Molécula", "Tecido"]],
		["Qual tipo de energia é armazenada em um objeto elevado?", "Energia potencial gravitacional", ["Energia térmica", "Energia cinética", "Energia química"]],
		["Qual é a unidade de medida de pressão?", "Pascal", ["Volt", "Ohm", "Ampere"]],
		["Qual é o nome do processo de formação das plantas a partir de sementes?", "Germinação", ["Fotossíntese", "Respiração", "Polinização"]],
		["Qual é o maior órgão do corpo humano?", "Pele", ["Fígado", "Pulmão", "Coração"]],
		["Qual gás é usado em muitos extintores de incêndio?", "Dióxido de carbono", ["Hélio", "Hidrogênio", "Oxigênio"]],
		["Qual é a causa da formação das marés?", "A atração da Lua", ["O movimento das estrelas", "A temperatura do oceano", "O vento"]],
		["Qual é o nome da molécula que transporta energia na célula?", "ATP", ["DNA", "RNA", "ADP"]],
		["Qual tipo de ondas os celulares usam para transmitir sinais?", "Ondas eletromagnéticas", ["Ondas sonoras", "Ondas térmicas", "Ondas gravitacionais"]],
	],
	"História": [
		["Em que ano foi proclamada a Independência do Brasil?", "1822", ["1500", "1889", "1922"]],
		["Em que ano foi abolida a escravidão no Brasil?", "1888", ["1822", "1850", "1889"]],
		["Em que ano terminou a Segunda Guerra Mundial?", "1945", ["1918", "1939", "1950"]],
		["Qual cidade-estado grega é associada ao nascimento da democracia?", "Atenas", ["Esparta", "Corinto", "Tebas"]],
		["Em que ano os portugueses chegaram ao território que hoje é o Brasil?", "1500", ["1492", "1530", "1600"]],
		["Em que ano começou a Revolução Francesa?", "1789", ["1689", "1815", "1848"]],
		["Qual civilização construiu Machu Picchu?", "Inca", ["Maia", "Asteca", "Olmeca"]],
		["Quem foi o primeiro ser humano a pisar na Lua?", "Neil Armstrong", ["Yuri Gagarin", "Buzz Aldrin", "Alan Shepard"]],
		["Quem foi o presidente dos Estados Unidos durante a Guerra de Secessão?", "Abraham Lincoln", ["George Washington", "Ulysses S. Grant", "Thomas Jefferson"]],
		["Em que ano ocorreu a Proclamação da República no Brasil?", "1889", ["1879", "1900", "1892"]],
		["Qual foi a primeira vila fundada pelos portugueses no Brasil, em 1532?", "São Vicente", ["Salvador", "Rio de Janeiro", "Recife"]],
		["Quem assinou a Lei Áurea, que aboliu a escravidão no Brasil?", "Princesa Isabel", ["Dom Pedro II", "Dom Pedro I", "Getúlio Vargas"]],
		["Qual povo construiu o Coliseu?", "Romanos", ["Gregos", "Vikings", "Francos"]],
		["Em que ano caiu o Muro de Berlim?", "1989", ["1961", "1975", "1991"]],
		["Quem liderou a independência do Haiti?", "Toussaint Louverture", ["Simón Bolívar", "José Bonifácio", "Pedro I"]],
		["Qual foi o primeiro presidente do Brasil?", "Deodoro da Fonseca", ["Floriano Peixoto", "Prudente de Morais", "Campos Sales"]],
		["Em que ano começou a Primeira Guerra Mundial?", "1914", ["1898", "1904", "1918"]],
		["Qual civilização construiu os zigurates?", "Mesopotâmica", ["Egípcia", "Inca", "Romana"]],
		["Quem foi o líder da Revolução Cubana?", "Fidel Castro", ["Che Guevara", "Raúl Castro", "Fulgencio Batista"]],
		["Qual foi o período em que o Brasil foi governado por uma monarquia?", "Império", ["Colônia", "República Velha", "Ditadura"]],
		["Quem foi o autor da Declaração de Independência dos Estados Unidos?", "Thomas Jefferson", ["Benjamin Franklin", "John Adams", "George Washington"]],
		["Quem comandou o exército aliado que derrotou Napoleão em Waterloo?", "Duque de Wellington", ["Napoleão Bonaparte", "Júlio César", "Nelson"]],
		["Qual civilização antiga construiu as pirâmides de Gizé?", "Egípcia", ["Romana", "Grega", "Persa"]],
		["Em que ano foi proclamada a Independência dos Estados Unidos?", "1776", ["1789", "1804", "1750"]],
	],
	"Cultura": [
		["Quem pintou a Mona Lisa?", "Leonardo da Vinci", ["Michelangelo", "Vincent van Gogh", "Pablo Picasso"]],
		["Quem escreveu o romance Dom Casmurro?", "Machado de Assis", ["José de Alencar", "Clarice Lispector", "Carlos Drummond de Andrade"]],
		["Qual é o idioma oficial do Brasil?", "Português", ["Espanhol", "Francês", "Italiano"]],
		["Qual instrumento musical tem teclas, cordas e martelos?", "Piano", ["Flauta", "Trompete", "Violino"]],
		["Quem criou a personagem Harry Potter?", "J. K. Rowling", ["Suzanne Collins", "C. S. Lewis", "Agatha Christie"]],
		["Qual estilo musical brasileiro está ligado ao desfile de escolas no Carnaval?", "Samba", ["Fado", "Tango", "Flamenco"]],
		["Quantos anéis aparecem no símbolo dos Jogos Olímpicos?", "Cinco", ["Quatro", "Seis", "Sete"]],
		["Qual destes instrumentos pertence à família das cordas?", "Violão", ["Clarinete", "Trombone", "Tímpano"]],
		["Quem escreveu o livro O Pequeno Príncipe?", "Antoine de Saint-Exupéry", ["Jules Verne", "Luís de Camões", "George Orwell"]],
		["Qual festa popular brasileira tem desfile de escolas de samba?", "Carnaval", ["Festa Junina", "Oktoberfest", "Círio de Nazaré"]],
		["Quem compôs o Hino Nacional Brasileiro?", "Francisco Manuel da Silva", ["Heitor Villa-Lobos", "Tom Jobim", "Carlos Gomes"]],
		["Qual festival de música acontece no Rio de Janeiro desde 1985?", "Rock in Rio", ["Lollapalooza", "Tomorrowland", "Coachella"]],
		["Quem foi o escritor de A Divina Comédia?", "Dante Alighieri", ["William Shakespeare", "Miguel de Cervantes", "Friedrich Nietzsche"]],
		["Qual destes artistas pintou Guernica?", "Pablo Picasso", ["Vincent van Gogh", "Claude Monet", "Leonardo da Vinci"]],
		["Qual instrumento de cordas é o mais agudo da orquestra?", "Violino", ["Viola", "Violoncelo", "Contrabaixo"]],
		["A qual movimento literário pertence Dom Casmurro?", "Realismo", ["Romantismo", "Modernismo", "Barroco"]],
		["Quem escreveu a obra O Alienista?", "Machado de Assis", ["Érico Veríssimo", "Clarice Lispector", "Graciliano Ramos"]],
		["Qual teatro de Manaus é famoso por sua cúpula colorida?", "Teatro Amazonas", ["Teatro Municipal do Rio de Janeiro", "Teatro da Paz", "Teatro Nacional"]],
		["Quem criou a personagem Capitão América?", "Joe Simon e Jack Kirby", ["Stan Lee", "Steve Ditko", "Alan Moore"]],
		["Qual gênero musical é associado à dança do tango?", "Tango", ["Samba", "Baião", "Frevo"]],
		["Qual é o nome do personagem principal de O Rei Leão?", "Simba", ["Mufasa", "Timon", "Pumba"]],
		["Quem conduz uma orquestra com uma batuta?", "Maestro", ["Pianista", "Violinista", "Cantor"]],
		["Quem escreveu a peça O Avarento?", "Molière", ["Victor Hugo", "Albert Camus", "Émile Zola"]],
		["Quem escreveu O Diário de Anne Frank?", "Anne Frank", ["J. K. Rowling", "Agatha Christie", "Virginia Woolf"]],
	],
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
var novo_recorde := false

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
	win.content_scale_size = Vector2i(1280, 720)
	hi = load_hi()
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
	cam.fov = 60.0
	cam.position = Vector3(0, -13, 21)
	add_child(cam)
	cam.look_at(Vector3(0, -1, 0), Vector3.UP)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(15, 15, 0)
	sun.light_energy = 0.8
	add_child(sun)

	ball_light = OmniLight3D.new()
	ball_light.omni_range = 14.0
	ball_light.light_energy = 2.0
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
		col = Color8(155, 45, 42)
		node = box(Vector3(BR_W, BR_H, 0.8), col, Vector3(pos.x, pos.y, 0), 0.5)
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
	var dif: Dictionary = DIFS[dificuldade]
	var total_w := COLS * BR_W + (COLS - 1) * BR_GAP
	var x0 := -total_w / 2.0 + BR_W / 2.0
	var padrao := (level - 1) % 5
	var proc := -1
	if modo_jogo == "random":
		proc = randi() % 5
	var chance: float = dif.densidade
	var any_normal := false
	for r in ROWS:
		for c in COLS:
			var on := true
			if proc >= 0:
				var xn := (c - (COLS - 1) / 2.0) / (COLS / 2.0)
				var yn := float(r) / (ROWS - 1)
				match proc:
					0:
						on = randf() < chance
					1:
						on = (xn * xn + (yn - 0.45) * (yn - 0.45) < 0.95) and randf() < minf(1.0, chance + 0.12)
					2:
						on = ((r + c + randi_range(0, 1)) % 3 != 0) and randf() < chance + 0.15
					3:
						on = ((r + randi_range(0, 2)) % 4 != 0) and randf() < minf(1.0, chance + 0.1)
					_:
						on = (absf(c - randi_range(2, COLS - 3)) <= (ROWS - r) * 0.9) and randf() < minf(1.0, chance + 0.2)
			else:
				match padrao:
					0:
						on = true
					1:
						on = (r + c) % 2 == 0 or r < 2
					2:
						on = absf(c - (COLS - 1) / 2.0) <= (ROWS - r) * 0.9
					3:
						on = not (c >= 3 and c <= 10 and r >= 2 and r <= 5)
					_:
						on = randf() < 0.75
			var pos := Vector2(x0 + c * (BR_W + BR_GAP), 8.0 - r * 0.9)
			if not on:
				if proc >= 0:
					var wo: int = dif.haz_obs
					var wb: int = dif.haz_bomba
					var tipo := "obstaculo" if randi() % (wo + wb) < wo else "bomba"
					add_brick(tipo, pos, r, 1)
				continue
			var hp := 1
			if level >= 2 and r < 2:
				hp = 2
			if level >= 4:
				hp = 3 if r < 2 else (2 if r < 4 else 1)
			var bonus_hp := 1 if (modo_jogo == "random" and level >= 3 and r < 2) else 0
			hp = mini(4, hp + int(dif.vida_extra) + bonus_hp)
			add_brick("normal", pos, r, hp)
			any_normal = true
	if not any_normal:
		add_brick("normal", Vector2(0, 8.0), 0, 1 + int(dif.vida_extra))


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
	reset_ball()


func start_game() -> void:
	score = 0
	lives = 3
	level = 1
	stats = {"total": 0, "acertos": 0, "por_cat": {}, "tempo": 0.0}
	ultima_cat = ""
	used.clear()
	paddle_w = PADDLE_BASE_W
	paddle.position.x = 0.0
	load_level()
	set_state("JOGANDO")


func lose_life() -> void:
	lives -= 1
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
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		return int(f.get_as_text().strip_edges())
	return 0


func save_hi() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(str(hi))


# ---------------------------------------------------------------- acertos / bombas
func hit_brick(br: Dictionary, destroy := false) -> void:
	if not bricks.has(br):
		return
	if br.tipo == "obstaculo":
		return
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
	if randf() < DROP_CHANCE and drops.size() < MAX_DROPS:
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
				else:
					hit_brick(chosen.br)

		# raquete
		if vel.y < 0.0 and pos.y - BALL_R <= PADDLE_Y + PADDLE_H * 0.5 and pos.y >= PADDLE_Y \
				and absf(pos.x - paddle.position.x) <= paddle_w * 0.5 + BALL_R:
			var off := clampf((pos.x - paddle.position.x) / (paddle_w * 0.5), -1.0, 1.0)
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
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir += 1.0
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
func mk(cat: String, text: String, correct: String, wrongs: Array) -> Dictionary:
	var opts: Array = [correct]
	for w in wrongs:
		if not opts.has(w) and opts.size() < 4:
			opts.append(w)
	var k := 1
	while opts.size() < 4:
		var alt := "Outra resposta %d" % k
		if not opts.has(alt):
			opts.append(alt)
		k += 1
	opts.shuffle()
	return {"cat": cat, "text": text, "opts": opts, "correct": opts.find(correct), "ans": correct}


func dist_int(c: int, minimo := -999999, extras: Array = []) -> Array:
	var base := [1, -1, 2, -2, 10, -10, 3, -3, 5, -5]
	base.shuffle()
	var cands: Array = extras.duplicate()
	for d in base:
		cands.append(c + d)
	var out: Array = []
	for d in cands:
		if d != c and not out.has(d) and d >= minimo:
			out.append(d)
		if out.size() == 3:
			break
	var k := 11
	while out.size() < 3:
		if not out.has(c + k):
			out.append(c + k)
		k += 1
	return out


func mk_int(cat: String, text: String, c: int, dist: Array, pre := "", suf := "") -> Dictionary:
	var w: Array = []
	for d in dist:
		w.append(pre + str(d) + suf)
	return mk(cat, text, pre + str(c) + suf, w)


func q_aritmetica(n: int) -> Dictionary:
	var lim := 20 + 30 * n
	if randf() < 0.5:
		var a := randi_range(5, lim)
		var b := randi_range(5, lim)
		return mk_int("Aritmética", "Quanto é %d + %d?" % [a, b], a + b, dist_int(a + b))
	var a2 := randi_range(10, lim)
	var b2 := randi_range(1, a2)
	return mk_int("Aritmética", "Quanto é %d - %d?" % [a2, b2], a2 - b2, dist_int(a2 - b2, 0, [a2 + b2]))


func q_tabuada(n: int) -> Dictionary:
	var a := randi_range(2, mini(9 + n, 15))
	var b := randi_range(2, 10)
	var c := a * b
	return mk_int("Tabuada", "Quanto é %d × %d?" % [a, b], c, dist_int(c, 0, [a * (b + 1), a * (b - 1), (a + 1) * b]))


func q_divisao(n: int) -> Dictionary:
	var b := randi_range(2, 9 + n / 2)
	var q := randi_range(2, 12)
	return mk_int("Divisão", "Quanto é %d ÷ %d?" % [b * q, b], q, dist_int(q, 1, [q + 1, q - 1, b]))


func q_porcentagem(n: int) -> Dictionary:
	var ps := [5, 10, 15, 20, 25, 50, 75]
	var p: int = ps.pick_random()
	var base := randi_range(1, 10 + n * 2) * 20
	var c := base * p / 100
	return mk_int("Porcentagem", "Quanto é %d%% de %d?" % [p, base], c, dist_int(c, 0, [c * 2, base - c, c + 10]))


func q_equacao(n: int) -> Dictionary:
	var x := randi_range(1 if n < 3 else -5, 10 + n)
	if x == 0:
		x = 2
	var a := randi_range(2, 4 + n)
	var b := randi_range(-10, 20)
	var c := a * x + b
	var sinal := "+" if b >= 0 else "-"
	return mk_int("Equações", "Resolva: %dx %s %d = %d. Quanto vale x?" % [a, sinal, absi(b), c],
		x, dist_int(x, -999999, [c - b, -x, x + 1]))


func q_potencia(n: int) -> Dictionary:
	var t := randi() % 3
	if t == 0:
		var a := randi_range(2, 10 + n)
		return mk_int("Potências e Raízes", "Quanto é %d²?" % a, a * a, dist_int(a * a, 0, [2 * a, (a + 1) * (a + 1), a * a + a]))
	if t == 1:
		var a2 := randi_range(2, 5 + n / 2)
		return mk_int("Potências e Raízes", "Quanto é %d³?" % a2, a2 * a2 * a2, dist_int(a2 * a2 * a2, 0, [3 * a2, a2 * a2, a2 * a2 * a2 + a2]))
	var k := randi_range(2, 12 + n)
	return mk_int("Potências e Raízes", "Qual é a raiz quadrada de %d?" % (k * k), k, dist_int(k, 1, [k * k / 2, k + 1, k - 1]))


func gcd_i(a: int, b: int) -> int:
	a = absi(a)
	b = absi(b)
	while b != 0:
		var t := b
		b = a % b
		a = t
	return maxi(1, a)


func fr(n: int, d: int) -> Vector2i:
	var g := gcd_i(n, d)
	return Vector2i(n / g, d / g)


func fr_str(f: Vector2i) -> String:
	return str(f.x) if f.y == 1 else "%d/%d" % [f.x, f.y]


func q_fracao(n: int) -> Dictionary:
	var dens := [2, 3, 4, 5, 6, 8, 10]
	var ops := ["+", "-"]
	if n >= 3:
		ops.append("×")
	var a := 1
	var b := 2
	var c := 1
	var d := 2
	var op := "+"
	var res := Vector2i(1, 1)
	var wrong := Vector2i(1, 1)
	while true:
		b = dens.pick_random()
		a = mini(randi_range(1, 9), b - 1)
		d = dens.pick_random()
		c = mini(randi_range(1, 9), d - 1)
		op = ops.pick_random()
		if op == "-" and a * d < c * b:
			var ta := a
			var tb := b
			a = c
			b = d
			c = ta
			d = tb
		if op == "+":
			res = fr(a * d + c * b, b * d)
			wrong = fr(a + c, b + d)
		elif op == "-":
			res = fr(a * d - c * b, b * d)
			wrong = fr(maxi(1, absi(a - c)), maxi(1, absi(b - d)))
		else:
			res = fr(a * c, b * d)
			wrong = fr(a * d, b * c)
		if res.x > 0:
			break
	var cands: Array = [wrong, fr(res.x + 1, res.y), fr(res.x * 2, res.y), fr(res.y, res.x)]
	if res.x - 1 > 0:
		cands.append(fr(res.x - 1, res.y))
	for k in [1, 2, 3]:
		cands.append(fr(res.x + 7 * k * res.y, res.y))
	var w: Array = []
	for f in cands:
		var s := fr_str(f)
		if f != res and not w.has(s):
			w.append(s)
	return mk("Frações", "Quanto é %d/%d %s %d/%d? (forma simplificada)" % [a, b, op, c, d], fr_str(res), w)


func q_expressao(n: int) -> Dictionary:
	var a := randi_range(2, 10 + n)
	var b := randi_range(2, 9)
	var c := randi_range(2, 9)
	var t := randi() % 3
	if t == 0:
		return mk_int("Expressões", "Quanto é %d + %d × %d?" % [a, b, c], a + b * c, dist_int(a + b * c, 0, [(a + b) * c]))
	if t == 1:
		return mk_int("Expressões", "Quanto é (%d + %d) × %d?" % [a, b, c], (a + b) * c, dist_int((a + b) * c, 0, [a + b * c]))
	return mk_int("Expressões", "Quanto é %d × %d - %d?" % [a, b, c], a * b - c, dist_int(a * b - c, -999999, [a * (b - c)]))


func q_sequencia(n: int) -> Dictionary:
	var termos: Array = []
	var prox := 0
	var extras: Array = []
	if n < 2 or randf() < 0.6:
		var s := randi_range(1, 20)
		var r := randi_range(2, 5 + n)
		for i in 4:
			termos.append(s + i * r)
		prox = s + 4 * r
		extras = [prox + r, prox - 1, prox + 1]
	else:
		var s2 := randi_range(1, 5)
		var r2: int = [2, 3].pick_random()
		for i in 4:
			termos.append(s2 * int(pow(r2, i)))
		prox = s2 * int(pow(r2, 4))
		var last: int = termos[3]
		var prev: int = termos[2]
		extras = [last + (last - prev), prox + r2, prox * r2]
	var seq := ", ".join(termos.map(func(v): return str(v)))
	return mk_int("Sequências", "Qual é o próximo número da sequência: %s, ...?" % seq, prox, dist_int(prox, 0, extras))


func q_problema(n: int) -> Dictionary:
	var t := randi() % 7
	match t:
		0:
			var a := randi_range(3, 9 + n)
			var b := randi_range(4, 12)
			return mk_int("Problemas", "Uma farmácia recebeu %d caixas com %d remédios cada. Quantos remédios ao todo?" % [a, b],
				a * b, dist_int(a * b, 0, [a + b, a * b + b]))
		1:
			var a := randi_range(20, 60 + 10 * n)
			var b := randi_range(5, a - 1)
			return mk_int("Problemas", "Ana tinha %d figurinhas e deu %d ao irmão. Com quantas ela ficou?" % [a, b],
				a - b, dist_int(a - b, 0, [a + b]))
		2:
			var ds := [10, 20, 25, 50]
			var p := randi_range(2, 15) * 20
			var d: int = ds.pick_random()
			var novo := p - p * d / 100
			return mk_int("Problemas", "Um tênis custa R$ %d e está com %d%% de desconto. Qual é o novo preço?" % [p, d],
				novo, dist_int(novo, 0, [p * d / 100, p - d]), "R$ ")
		3:
			var k := randi_range(2, 8)
			var q := randi_range(3, 12)
			return mk_int("Problemas", "%d amigos dividiram %d balas igualmente. Quantas balas cada um recebeu?" % [k, k * q],
				q, dist_int(q, 1, [k * q - k, q + k]))
		4:
			var vs := [40, 50, 60, 80, 90, 100]
			var v: int = vs.pick_random()
			var h := randi_range(2, 5)
			return mk_int("Problemas", "Um carro anda a %d km/h. Quantos km ele percorre em %d horas?" % [v, h],
				v * h, dist_int(v * h, 0, [v + h, v * (h - 1)]), "", " km")
		_:
			var l := randi_range(3, 12)
			var c := randi_range(3, 15)
			if t == 5:
				return mk_int("Problemas", "Um retângulo mede %d m por %d m. Qual é a sua área?" % [l, c],
					l * c, dist_int(l * c, 0, [2 * (l + c), l + c]), "", " m²")
			return mk_int("Problemas", "Um retângulo mede %d m por %d m. Qual é o seu perímetro?" % [l, c],
				2 * (l + c), dist_int(2 * (l + c), 0, [l * c, l + c]), "", " m")


func gen_from(entry: Array) -> Dictionary:
	if str(entry[1]) != "":
		return call(str(entry[1]), level)
	var cat: String = entry[0]
	var e: Array = (GERAIS[cat] as Array).pick_random()
	return mk(cat, e[0], e[1], e[2])


func pick_question() -> Dictionary:
	var opts: Array = []
	for m in MATERIAS:
		if not materias_sel.has(m):
			continue
		if m == "Matemática":
			for g in MATH_GENS:
				opts.append([g[0], g[1]])
		else:
			opts.append([m, ""])
	if opts.is_empty():
		for g in MATH_GENS:
			opts.append([g[0], g[1]])
	var cats: Array = []
	for o in opts:
		if o[0] != ultima_cat:
			cats.append(o)
	if cats.is_empty():
		cats = opts
	for _i in 20:
		var q := gen_from(cats.pick_random())
		var qid := "%s|%s|%s" % [q.cat, q.text, "/".join(q.opts)]
		if not used.has(qid):
			return q
	return gen_from(cats.pick_random())


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
	quiz_cat.text = "QUESTIONÁRIO  •  %s" % String(quiz.cat).to_upper()
	quiz_sub.text = "Acerte e ganhe: %s — %s" % [info.nome, info.desc]
	quiz_sub.modulate = info.cor
	quiz_text.text = quiz.text
	for i in 4:
		quiz_buttons[i].text = "%d)  %s" % [i + 1, quiz.opts[i]]
		quiz_buttons[i].modulate = Color.WHITE
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
	menu_box.visible = s in ["MENU", "SELECAO_MODO", "SELECAO_DIFICULDADE", "SELECAO_QUIZ"]
	quiz_box.visible = s == "QUIZ"
	if menu_box.visible:
		call_deferred("rebuild_menu")


func _process(delta: float) -> void:
	t_anim += delta
	update_fx(delta)
	update_hud()
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
	for k in active.keys():
		active[k] = float(active[k]) - delta
		if float(active[k]) <= 0.0:
			active.erase(k)
			if k == "IMA":
				launch()

	update_paddle(delta)

	cooldown_laser -= delta
	if active.has("LASER") and Input.is_key_pressed(KEY_SPACE) and cooldown_laser <= 0.0 and not any_stuck():
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
		level_timer = 2.5
		sfx_play("nivel")
		set_state("NIVEL")


# ---------------------------------------------------------------- HUD
func update_hud() -> void:
	var show_hud := state in ["JOGANDO", "QUIZ", "PAUSA", "NIVEL"]
	hud_label.visible = show_hud
	var boosts := ""
	for k in active:
		var info: Dictionary = BOOSTS[k] if BOOSTS.has(k) else DOWNGRADES[k]
		boosts += "   [%s %ds]" % [info.nome, int(ceil(float(active[k])))]
	hud_label.text = "PONTOS %06d   RECORDE %06d   NÍVEL %d\nVIDAS %d   QUIZ %d/%d%s" % [
		score, maxi(hi, score), level, lives, int(stats.get("acertos", 0)), int(stats.get("total", 0)), boosts]

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

	hud_label = make_label(22)
	hud_label.position = Vector2(20, 12)
	cl.add_child(hud_label)

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
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 22)
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
	b.pressed.connect(cb)
	menu_vb.add_child(b)
	return b


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
			mlabel("Quebre os blocos, pegue as cápsulas e resolva a questão sorteada para ganhar o boost!", 16)
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
			mlabel("Errou ou o tempo acabou? Recebe um downgrade por 8 segundos.", 15, Color8(240, 90, 90))
			mlabel("Blocos cinza = obstáculos indestrutíveis  •  Blocos vermelhos = bombas (explosão em cadeia)", 15, grey)
			mlabel("MODO: %s   •   DIFICULDADE: %s" % [("Padrão" if modo_jogo == "padrao" else "Random"), DIFS[dificuldade].nome], 17, cyan)
			mlabel("QUIZ: " + materias_text(), 15)
			mlabel("← → / A D / mouse: mover  •  ESPAÇO: lançar / laser  •  1-4: responder  •  P: pausa", 15, grey)
			mlabel("RECORDE: %d" % hi, 18, cyan)
			var jb := mbutton("JOGAR", func(): set_state("SELECAO_MODO"), 260.0)
			jb.grab_focus()
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
			if k == KEY_SPACE:
				on_primary()
			elif k == KEY_P or k == KEY_ESCAPE:
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
