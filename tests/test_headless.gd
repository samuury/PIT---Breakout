extends SceneTree
func _init() -> void:
	run()

func run() -> void:
	var m = load("res://Main.gd").new()
	root.add_child(m)
	await process_frame
	await process_frame
	print("== gerando perguntas")
	m.materias_sel = ["Matemática","Geografia","Ciências","História","Cultura"]
	var bad := 0
	for lv in [1,3,6,10]:
		m.level = lv
		for i in 1500:
			var q = m.pick_question()
			var s := {}
			for o in q.opts: s[o] = true
			if q.opts.size() != 4 or s.size() != 4 or q.correct < 0 or q.opts[q.correct] != q.ans:
				bad += 1
				if bad < 6: print("RUIM: ", q)
			m.used.clear()
	print("perguntas ruins: ", bad)
	print("== gerando fases")
	var semn := 0
	for modo in ["padrao","random"]:
		for dif in ["facil","normal","dificil"]:
			m.modo_jogo = modo; m.dificuldade = dif
			for lv in range(1, 13):
				m.level = lv
				m.build_bricks()
				var n := 0
				for b in m.bricks:
					if b.tipo == "normal": n += 1
				if n == 0: semn += 1
	print("fases sem bloco normal: ", semn)
	print("== simulando partida")
	m.modo_jogo = OS.get_environment("MODO"); m.dificuldade = OS.get_environment("DIF")
	m.materias_sel = ["Matemática","Geografia","Ciências","História","Cultura"]
	m.start_game()
	m.launch()
	var quizzes := 0
	for f in 60 * 900:
		var bx: float = m.balls[0].pos.x if not m.balls.is_empty() else 0.0
		m.paddle.position.x = clampf(bx + sin(f * 0.013) * 2.0, -11, 11)
		m.use_mouse = false
		m._process(1.0/60.0)
		if m.state == "QUIZ":
			quizzes += 1
			m.answer(m.quiz.correct if randf() < 0.6 else 0)
			m.quiz_fb = 0.0
			m.close_quiz()
		elif m.state == "NIVEL":
			m.level_timer = 0.0
		elif m.state == "FIM":
			print("fim no frame ", f)
			break
		if m.state == "JOGANDO" and m.any_stuck():
			m.launch()
	print("estado final: ", m.state, " nivel ", m.level, " pontos ", m.score, " quizzes ", quizzes, " bolas ", m.balls.size())
	print(m.fim_text() if m.state == "FIM" else "")
	print("== testando game over")
	m.start_game()
	m.score = 1234
	for i in 3:
		m.lose_life()
	print("estado: ", m.state, " | recorde salvo: ", m.load_hi())
	print(m.fim_text())
	quit()
