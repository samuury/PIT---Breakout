extends RefCounted
# Geração pura de fases (sem nós): devolve uma lista de células {r, c, tipo, hp}.

const COLS := 14
const ROWS := 8
# Fração dos obstáculos sorteados que permanecem (menor = menos blocos inquebráveis).
# Os obstáculos removidos viram blocos normais na mesma posição.
const OBSTACLE_KEEP := 0.45


static func generate(level: int, modo: String, dif: Dictionary) -> Array:
	var cells: Array = []
	var padrao := (level - 1) % 5
	var proc := -1
	if modo == "random":
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
			if not on:
				if proc >= 0:
					var wo: int = dif.haz_obs
					var wb: int = dif.haz_bomba
					var tipo := "obstaculo" if randi() % (wo + wb) < wo else "bomba"
					if tipo == "obstaculo" and randf() > OBSTACLE_KEEP:
						cells.append({"r": r, "c": c, "tipo": "normal", "hp": brick_hp(level, r, modo, dif)})
						any_normal = true
						continue
					cells.append({"r": r, "c": c, "tipo": tipo, "hp": 1})
				continue
			cells.append({"r": r, "c": c, "tipo": "normal", "hp": brick_hp(level, r, modo, dif)})
			any_normal = true
	if not any_normal:
		for i in range(cells.size() - 1, -1, -1):
			if cells[i].r == 0 and cells[i].c == 6:
				cells.remove_at(i)
		cells.append({"r": 0, "c": 6, "tipo": "normal", "hp": 1 + int(dif.vida_extra)})
	return cells


static func brick_hp(level: int, r: int, modo: String, dif: Dictionary) -> int:
	var hp := 1
	if level >= 2 and r < 2:
		hp = 2
	if level >= 4:
		hp = 3 if r < 2 else (2 if r < 4 else 1)
	var bonus_hp := 1 if (modo == "random" and level >= 3 and r < 2) else 0
	return mini(4, hp + int(dif.vida_extra) + bonus_hp)
