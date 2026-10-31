extends SceneTree
var falhas := 0
func check(ok: bool, msg: String) -> void:
	print(("  OK   " if ok else "  FALHA ") + msg)
	if not ok: falhas += 1
func _init() -> void:
	run()
func run() -> void:
	var m = load("res://Main.gd").new()
	m.save_path = "user://teste_recorde.txt"   # testes nunca tocam nos arquivos reais
	m.config_path = "user://teste_config.cfg"
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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.save_path))
	print("== dificuldade adaptativa")
	m.start_game()
	m.stats.por_cat = {"Aritmética": [5, 5], "Frações": [0, 4], "Tabuada": [2, 2]}
	var ad: Dictionary = m.adapt_offsets()
	check(ad.get("Aritmética", 0) == 2 and ad.get("Frações", 0) == -2 and not ad.has("Tabuada"), "ajustes por matéria: %s" % str(ad))
	m.bank.adapt = ad
	m.bank.level = 1
	check(m.bank.eff_level("Aritmética") == 3 and m.bank.eff_level("Frações") == 1, "nível efetivo sobe com acerto e nunca fica abaixo de 1")
	m.stats.por_cat = {}
	m.bank.adapt = {}
	print("== configurações salvas")
	m.modo_jogo = "random"; m.dificuldade = "dificil"; m.materias_sel = ["Matemática", "Ciências"]; m.sound_on = false
	m.save_config()
	var m2 = load("res://Main.gd").new()
	m2.save_path = "user://teste_recorde.txt"
	m2.config_path = "user://teste_config.cfg"
	root.add_child(m2)
	await process_frame
	await process_frame
	check(m2.modo_jogo == "random" and m2.dificuldade == "dificil" and m2.materias_sel == ["Matemática", "Ciências"] and not m2.sound_on, "modo, dificuldade, matérias e som restaurados ao reabrir")
	m2.sound_on = true; m2.apply_sound(); m2.queue_free()
	m.sound_on = true; m.apply_sound()
	print("== áudio e controle")
	check(m.sfx_players["bloco"].max_polyphony >= 2, "efeitos sonoros podem sobrepor (polifonia %d)" % m.sfx_players["bloco"].max_polyphony)
	m.start_game()
	m.open_quiz("MULTI")
	m.handle_pad(2)
	check(m.quiz_answered, "botão X do controle responde o quiz")
	m.quiz_fb = 0.5
	m.handle_pad(0)
	check(m.state == "JOGANDO", "botão A continua após a resposta")
	m.handle_pad(JOY_BUTTON_START)
	check(m.state == "PAUSA", "Start pausa")
	m.handle_pad(JOY_BUTTON_START)
	check(m.state == "JOGANDO", "Start despausa")
	print("== animações de bloco")
	var alvo = null
	for b in m.bricks:
		if b.tipo == "normal": alvo = b; break
	var nodo = alvo.node
	m.hit_brick(alvo, true)
	await create_timer(0.5).timeout
	check(not is_instance_valid(nodo), "bloco destruído some depois da animação de saída")
	print("== gráficos")
	var shaders_ok := true
	for sp in ["sky", "floor", "brick", "neon", "paddle", "post"]:
		if not (load("res://shaders/%s.gdshader" % sp) is Shader): shaders_ok = false
	check(shaders_ok, "6 shaders carregam (céu, chão, bloco, neon, raquete, pós-processamento)")
	m.gfx.quality = 0; m.apply_gfx()
	check(not m.gfx.env.glow_enabled and not m.gfx.env.ssao_enabled and not m.gfx.sun.shadow_enabled, "BAIXA: sem bloom, SSAO nem sombras")
	m.gfx.quality = 3; m.apply_gfx()
	check(m.gfx.env.ssr_enabled and m.gfx.env.ssao_enabled and m.gfx.env.fog_enabled and m.gfx.sun.shadow_enabled, "ULTRA: SSR, SSAO, névoa e sombras")
	m.gfx.scale_idx = 4; m.apply_gfx()
	check(is_equal_approx(m.get_viewport().scaling_3d_scale, 2.0), "escala 3D 200% (supersampling) aplicada")
	m.gfx.scale_idx = 0; m.apply_gfx()
	check(is_equal_approx(m.get_viewport().scaling_3d_scale, 0.5), "escala 3D 50% aplicada (FSR)")
	m.gfx.quality = 2; m.gfx.scale_idx = 2; m.apply_gfx()
	m.gfx.quality = 3; m.gfx.res_idx = 3; m.gfx.scale_idx = 3; m.gfx.post = false; m.save_config()
	var m3 = load("res://Main.gd").new()
	m3.save_path = "user://teste_recorde.txt"
	m3.config_path = "user://teste_config.cfg"
	root.add_child(m3)
	await process_frame
	await process_frame
	check(m3.gfx.quality == 3 and m3.gfx.res_idx == 3 and m3.gfx.scale_idx == 3 and not m3.gfx.post, "qualidade, resolução, escala e efeitos restaurados ao reabrir")
	m3.queue_free()
	m.gfx.quality = 2; m.gfx.res_idx = 2; m.gfx.scale_idx = 2; m.gfx.post = true; m.apply_gfx()
	print("== HUD")
	m.start_game()
	m.lives = 2
	m.active["LASER"] = 5.0
	m.update_hud(0.016)
	var vis := 0
	for h in m.hearts:
		if h.visible: vis += 1
	check(vis == 2 and m.pills.has("LASER"), "HUD: %d corações visíveis e indicador do boost Laser" % vis)
	m.active.erase("LASER")
	m.update_hud(0.016)
	check(not m.pills.has("LASER"), "indicador some quando o boost acaba")
	m.lives = 3
	print("== trilha sonora")
	if not m.music.available("jogo_1") or not m.music.available("menu"):
		print("  (músicas ainda não importadas pelo Godot: rode `godot --headless --import` uma vez; pulando)")
	else:
		m.start_game()
		check(m.music.current == "jogo_1" and m.music.group.size() == 4, "início do jogo toca jogo_1 com 4 camadas")
		check(m.music.layer_on[0] and m.music.layer_on[2] and not m.music.layer_on[1], "bola presa: só base e arpejo (sem bateria)")
		m.launch()
		m.music_t = 0.0
		m.update_game(0.016)
		check(m.music.layer_on[1], "bola lançada: entra a bateria")
		m.open_quiz("MULTI")
		check(m.music.current == "quiz" and not m.music.stash.is_empty(), "quiz troca para a música de tensão e guarda a do jogo")
		m.answer(m.quiz.correct)
		m.quiz_fb = 0.5
		m.close_quiz()
		check(m.music.current == "jogo_1" and m.music.stash.is_empty() and m.music.group.size() == 4, "após o quiz a música do jogo retoma")
		var tocando := true
		for pl in m.music.group:
			if pl.stream_paused: tocando = false
		check(tocando, "camadas retomadas sem ficar pausadas")
		m.set_state("PAUSA")
		check(m.music.duck_on, "pausa abaixa a música")
		m.set_state("JOGANDO")
		check(not m.music.duck_on, "sair da pausa restaura o volume")
		m.set_state("NIVEL")
		check(m.music.current == "" and m.music.sting_player.playing, "fim de fase para a faixa e toca a vinheta de vitória")
		m.level = 2
		m.set_state("JOGANDO")
		check(m.music.current == "jogo_2", "fase 2 usa outra faixa (jogo_2)")
		m.level = 4
		check(m.track_for_level() == "jogo_1", "as faixas se repetem em ciclo de 3")
		m.level = 1
		m.set_state("FIM")
		check(m.music.sting_player.playing and m.music.after_sting == "menu", "game over toca a vinheta e depois volta ao menu")
		m.set_state("MENU")
		check(m.music.current == "menu", "menu toca o tema do menu")
	m.music_idx = 1; m.music.set_volume(0.35); m.save_config()
	var m4 = load("res://Main.gd").new()
	m4.save_path = "user://teste_recorde.txt"
	m4.config_path = "user://teste_config.cfg"
	root.add_child(m4)
	await process_frame
	await process_frame
	check(m4.music_idx == 1 and is_equal_approx(m4.music.volume, 0.35), "volume da música restaurado ao reabrir")
	m4.queue_free()
	m.music_idx = 2; m.music.set_volume(0.7)
	if m.music.available("jogo_1"):
		print("== fades da música (tempo real)")
		m.start_game()
		await create_timer(1.6).timeout
		var base_p = m.music.group[0]
		var ritmo_p = m.music.group[1]
		var alvo_db := linear_to_db(0.7)
		check(absf(base_p.volume_db - alvo_db) < 1.0 and ritmo_p.volume_db < -50.0, "fade-in: base audível (%.1f dB) e bateria ainda muda (%.1f dB)" % [base_p.volume_db, ritmo_p.volume_db])
		m.launch()
		await create_timer(1.8).timeout
		check(absf(ritmo_p.volume_db - alvo_db) < 1.0, "bateria entra com fade depois do lançamento (%.1f dB)" % ritmo_p.volume_db)
		m.set_state("PAUSA")
		await create_timer(1.0).timeout
		check(base_p.volume_db < alvo_db - 10.0, "pausa abaixa o volume com fade (%.1f dB)" % base_p.volume_db)
		m.set_state("JOGANDO")
	print("== partida completa + game over")
	m.modo_jogo = "random"; m.dificuldade = "dificil"; m.materias_sel = todas
	m.start_game(); m.launch()
	for i in 3: m.lose_life()
	check(m.state == "FIM", "game over alcançado")
	m.hi = 0
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(m.config_path))
	print("RESULTADO: ", "TUDO OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(0 if falhas == 0 else 1)
