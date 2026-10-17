extends SceneTree
var falhas := 0
func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALHA ") + msg)
	if not ok: falhas += 1
func _init() -> void:
	run()
func run() -> void:
	var m = load("res://Main.gd").new()
	root.add_child(m)
	await process_frame
	await process_frame
	var todas := ["Matemática","Geografia","Ciências","História","Cultura"]
	print("== banco de perguntas")
	var g: Dictionary = m.bank.gerais
	check(g.size() == 4 and g["Geografia"].size() >= 24, "JSON carregado: 4 matérias gerais")
	m.materias_sel = todas
	var ruins := 0
	for lv in [1, 3, 6, 10]:
		for i in 1500:
			var q = m.bank.pick(todas, "", {}, lv)
			var s := {}
			for o in q.opts: s[o] = true
			if q.opts.size() != 4 or s.size() != 4 or q.correct < 0 or q.opts[q.correct] != q.ans: ruins += 1
	check(ruins == 0, "6000 perguntas válidas (4 opções distintas, correta presente) — ruins: %d" % ruins)
	# revisão: pergunta errada volta depois de 3 perguntas
	m.bank.revisit.clear()
	var qq = m.bank.pick(["Geografia"], "", {}, 1)
	var cat: String = qq.cat
	m.bank.note_wrong(qq)
	var vol := -1
	for i in 6:
		var n = m.bank.pick(["Geografia"], "", {}, 1)
		if n.get("revisao", false):
			vol = i
			break
	check(vol >= 0 and vol <= 3, "pergunta errada volta como REVISÃO (após %d perguntas)" % vol)
	print("== geração de fases")
	var LG = load("res://level_gen.gd")
	var sem := 0
	for modo in ["padrao","random"]:
		for dif in ["facil","normal","dificil"]:
			for lv in range(1, 16):
				for k in 20:
					var cells = LG.generate(lv, modo, m.DIFS[dif])
					var n := 0
					for c in cells:
						if c.tipo == "normal": n += 1
					if n == 0: sem += 1
	check(sem == 0, "1800 fases geradas, todas com bloco normal")
	print("== multibola limitada")
	m.modo_jogo = "padrao"; m.dificuldade = "normal"
	m.start_game(); m.launch()
	for i in 8: m.apply_boost("MULTI")
	check(m.balls.size() <= m.MAX_BALLS, "bolas após 8 Multibolas: %d (limite %d)" % [m.balls.size(), m.MAX_BALLS])
	print("== loop vertical (bot sempre no centro)")
	m.start_game(); m.launch()
	var last: int = m.bricks.size(); var parado := 0.0; var pior := 0.0
	for f in 60 * 300:
		var bx: float = m.balls[0].pos.x if not m.balls.is_empty() else 0.0
		m.paddle.position.x = clampf(bx, -11, 11)
		m._process(1.0 / 60.0)
		if m.state == "QUIZ": m.answer(0); m.quiz_fb = 0.0; m.close_quiz()
		if m.state == "NIVEL": m.level_timer = 0.0
		if m.state == "FIM": break
		if m.bricks.size() != last: last = m.bricks.size(); parado = 0.0
		else: parado += 1.0 / 60.0
		pior = maxf(pior, parado)
	check(pior < 45.0, "maior tempo sem quebrar bloco: %.1f s (antes: 252 s) | nível %d" % [pior, m.level])
	print("== cápsulas / quizzes")
	m.start_game()
	for br in m.bricks.duplicate(): m.hit_brick(br, true)
	check(m.drops.size() <= 1, "destruir uma fase inteira de uma vez gera %d cápsula(s) (cooldown)" % m.drops.size())
	print("== delta grande não quebra a física")
	m.start_game(); m.launch()
	var fora := 0
	for f in 600:
		m.paddle.position.x = clampf(m.balls[0].pos.x if not m.balls.is_empty() else 0.0, -11, 11)
		m._process(0.5 if f % 50 == 0 else 1.0 / 60.0)
		for b in m.balls:
			if absf(b.pos.x) > 14.5 or b.pos.y > 10.5: fora += 1
		if m.state == "QUIZ": m.answer(0); m.quiz_fb = 0.0; m.close_quiz()
	check(fora == 0, "bola nunca sai do campo com picos de lag")
	print("== recorde salvo ao fechar a janela")
	m.start_game(); m.score = 987654
	m._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	check(m.load_hi() >= 987654, "recorde gravado no fechamento: %d" % m.load_hi())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.SAVE_PATH))
	print("== partida completa + game over")
	m.modo_jogo = "random"; m.dificuldade = "dificil"; m.materias_sel = todas
	m.start_game(); m.launch()
	for i in 3: m.lose_life()
	check(m.state == "FIM", "game over alcançado")
	m.hi = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.SAVE_PATH))
	print("RESULTADO: ", "TUDO OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(0 if falhas == 0 else 1)
