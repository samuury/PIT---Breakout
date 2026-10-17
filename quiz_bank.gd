extends RefCounted
@warning_ignore_start("integer_division")
# Banco de perguntas: geradores de matemática + perguntas gerais (JSON).
# Também guarda a fila de REVISÃO: perguntas erradas voltam depois de 3 perguntas.

const MATH_GENS := [
	["Aritmética", "q_aritmetica"], ["Tabuada", "q_tabuada"], ["Divisão", "q_divisao"],
	["Porcentagem", "q_porcentagem"], ["Equações", "q_equacao"],
	["Potências e Raízes", "q_potencia"], ["Frações", "q_fracao"],
	["Expressões", "q_expressao"], ["Sequências", "q_sequencia"], ["Problemas", "q_problema"]]

var gerais: Dictionary = {}
var revisit: Array = []
var level := 1


func load_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("Banco de perguntas não encontrado: " + path)
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("JSON de perguntas inválido: " + path)
		return false
	gerais = data
	return true


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
	var lista: Array = gerais.get(cat, [])
	var e: Array = lista.pick_random()
	return mk(cat, e[0], e[1], e[2])


func note_wrong(q: Dictionary) -> void:
	var cat: String = q.cat
	for r in revisit:
		if r.cat == cat:
			return
	revisit.append({"cat": cat, "wait": 3, "q": q.duplicate(true)})


func math_gen_for(cat: String) -> String:
	for g in MATH_GENS:
		if g[0] == cat:
			return g[1]
	return ""


func due_revisit() -> Dictionary:
	for r in revisit:
		r.wait = int(r.wait) - 1
	for r in revisit:
		if int(r.wait) <= 0:
			revisit.erase(r)
			var q: Dictionary
			var gname := math_gen_for(r.cat)
			if gname != "":
				q = call(gname, level)
			else:
				q = (r.q as Dictionary).duplicate(true)
				var ans: String = q.ans
				var o: Array = q.opts
				o.shuffle()
				q.opts = o
				q.correct = o.find(ans)
			q["revisao"] = true
			return q
	return {}


func pick(materias: Array, ultima_cat: String, used: Dictionary, lvl: int) -> Dictionary:
	level = lvl
	var rv := due_revisit()
	if not rv.is_empty():
		return rv
	var opts: Array = []
	for m in materias:
		if m == "Matemática":
			for g in MATH_GENS:
				opts.append([g[0], g[1]])
		elif gerais.has(m) and not (gerais[m] as Array).is_empty():
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
