# -*- coding: utf-8 -*-
"""
BREAKOUT MATEMÁTICO  —  Pygame
==============================
Releitura do Breakout (Atari, 1976) com questionários de matemática e conhecimentos gerais.

Como funciona
-------------
- Quebre os blocos com a bola, como no Breakout original.
- Alguns blocos soltam uma CÁPSULA (drop) com um boost.
- Ao pegar a cápsula com a raquete, o jogo pausa e sorteia uma questão
  de um dos 10 questionários (Aritmética, Tabuada, Divisão, Porcentagem,
  Equações, Potências e Raízes, Frações, Expressões, Sequências, Problemas).
- Acertou: ganha o boost da cápsula + pontos bônus (quanto mais rápido, mais pontos).
- Errou ou o tempo acabou: recebe um downgrade temporário.
- A dificuldade das questões e a velocidade da bola aumentam a cada nível.

Controles
---------
  ← → ou A D / mouse ...... mover a raquete
  ESPAÇO / clique ......... lançar a bola / disparar laser
  1 2 3 4 / clique ........ responder o questionário
  P ou ESC ................ pausar
    1 / 2 / 3 ............... selecionar matemática / conhecimentos gerais / ambos no menu
    ENTER ................... iniciar / reiniciar

Requisito:  pip install pygame
Executar:   python breakout_matematico.py
"""
import array
import math
import os
import random
import sys
from fractions import Fraction

import pygame

# ---------------------------------------------------------------------------
# Configurações gerais
# ---------------------------------------------------------------------------
LARGURA, ALTURA = 1280, 720
FPS = 60
TOPO_HUD = 64
LARG_RAQUETE = 160
CHANCE_DROP = 0.22
MAX_DROPS = 3

# Cores (linhas no estilo Atari: vermelho, laranja, verde, amarelo)
COR_FUNDO_1 = (10, 10, 26)
COR_FUNDO_2 = (26, 12, 44)
BRANCO = (240, 240, 245)
CINZA = (140, 140, 160)
VERDE_OK = (70, 200, 110)
VERMELHO_ERRO = (220, 70, 70)
LINHAS_ATARI = [
    ((200, 72, 72), 7), ((200, 72, 72), 7),
    ((198, 108, 58), 5), ((198, 108, 58), 5),
    ((72, 160, 72), 3), ((72, 160, 72), 3),
    ((200, 190, 60), 1), ((200, 190, 60), 1),
]

BOOSTS = {
    "LARGA": {"nome": "Raquete Larga", "cor": (80, 200, 255), "icone": "W", "dur": 15, "desc": "Raquete 50% maior"},
    "MULTI": {"nome": "Multibola", "cor": (255, 210, 60), "icone": "M", "dur": 0, "desc": "+2 bolas em jogo"},
    "LENTA": {"nome": "Câmera Lenta", "cor": (140, 240, 140), "icone": "S", "dur": 12, "desc": "Bola 35% mais lenta"},
    "VIDA": {"nome": "Vida Extra", "cor": (255, 100, 140), "icone": "+", "dur": 0, "desc": "+1 vida"},
    "FOGO": {"nome": "Bola de Fogo", "cor": (255, 130, 40), "icone": "F", "dur": 10, "desc": "Atravessa e destrói blocos"},
    "IMA": {"nome": "Ímã", "cor": (190, 120, 255), "icone": "I", "dur": 15, "desc": "Bola gruda na raquete"},
    "LASER": {"nome": "Laser", "cor": (255, 70, 70), "icone": "L", "dur": 12, "desc": "Segure ESPAÇO para atirar"},
    "X2": {"nome": "Pontos x2", "cor": (235, 235, 235), "icone": "x2", "dur": 15, "desc": "Pontuação em dobro"},
}
PESOS_BOOST = {"LARGA": 3, "MULTI": 3, "LENTA": 2, "VIDA": 1, "FOGO": 2, "IMA": 2, "LASER": 2, "X2": 2}
DOWNGRADES = {
    "ENCOLHE": {"nome": "Raquete Encolhida", "cor": (130, 130, 130), "icone": "-", "dur": 8},
    "RAQUETE_LENTA": {"nome": "Raquete Lenta", "cor": (220, 150, 90), "icone": "L", "dur": 8},
    "BOLA_RAPIDA": {"nome": "Bola Acelerada", "cor": (240, 90, 90), "icone": "!", "dur": 8},
}


# ---------------------------------------------------------------------------
# Questionários de matemática
# ---------------------------------------------------------------------------
def formatar(v):
    if isinstance(v, Fraction):
        return str(v.numerator) if v.denominator == 1 else f"{v.numerator}/{v.denominator}"
    return str(v)


def _dist_int(c, minimo=None, extras=()):
    """Gera 3 alternativas erradas plausíveis para uma resposta inteira."""
    base = [1, -1, 2, -2, 10, -10, 3, -3, 5, -5]
    random.shuffle(base)
    candidatos = list(extras) + [c + d for d in base]
    saida = []
    for d in candidatos:
        if d != c and d not in saida and (minimo is None or d >= minimo):
            saida.append(d)
        if len(saida) == 3:
            break
    k = 11
    while len(saida) < 3:
        if c + k not in saida:
            saida.append(c + k)
        k += 1
    return saida


def _pergunta(categoria, enunciado, correta, distratores, prefixo="", sufixo=""):
    textos = [prefixo + formatar(correta) + sufixo]
    for d in distratores:
        t = prefixo + formatar(d) + sufixo
        if t not in textos:
            textos.append(t)
        if len(textos) == 4:
            break
    k = 1
    while len(textos) < 4:  # garantia de 4 alternativas
        t = prefixo + formatar(correta + k * 7) + sufixo
        if t not in textos:
            textos.append(t)
        k += 1
    resposta = textos[0]
    random.shuffle(textos)
    return {"categoria": categoria, "enunciado": enunciado, "opcoes": textos,
            "indice_correto": textos.index(resposta), "resposta": resposta}


def q_aritmetica(n):
    lim = 20 + 30 * n
    if random.random() < 0.5:
        a, b = random.randint(5, lim), random.randint(5, lim)
        return _pergunta("Aritmética", f"Quanto é {a} + {b}?", a + b, _dist_int(a + b))
    a = random.randint(10, lim)
    b = random.randint(1, a)
    return _pergunta("Aritmética", f"Quanto é {a} - {b}?", a - b, _dist_int(a - b, 0, [a + b]))


def q_tabuada(n):
    a, b = random.randint(2, min(9 + n, 15)), random.randint(2, 10)
    c = a * b
    return _pergunta("Tabuada", f"Quanto é {a} × {b}?", c, _dist_int(c, 0, [a * (b + 1), a * (b - 1), (a + 1) * b]))


def q_divisao(n):
    b, q = random.randint(2, 9 + n // 2), random.randint(2, 12)
    return _pergunta("Divisão", f"Quanto é {b * q} ÷ {b}?", q, _dist_int(q, 1, [q + 1, q - 1, b]))


def q_porcentagem(n):
    p = random.choice([5, 10, 15, 20, 25, 50, 75])
    base = random.randint(1, 10 + n * 2) * 20
    c = base * p // 100
    return _pergunta("Porcentagem", f"Quanto é {p}% de {base}?", c, _dist_int(c, 0, [c * 2, base - c, c + 10]))


def q_equacao(n):
    x = random.randint(1 if n < 3 else -5, 10 + n) or 2
    a, b = random.randint(2, 4 + n), random.randint(-10, 20)
    c = a * x + b
    sinal = "+" if b >= 0 else "-"
    return _pergunta("Equações", f"Resolva: {a}x {sinal} {abs(b)} = {c}. Quanto vale x?",
                     x, _dist_int(x, None, [c - b, -x, x + 1]))


def q_potencia(n):
    t = random.randint(0, 2)
    if t == 0:
        a = random.randint(2, 10 + n)
        return _pergunta("Potências e Raízes", f"Quanto é {a}²?", a * a, _dist_int(a * a, 0, [2 * a, (a + 1) ** 2, a * a + a]))
    if t == 1:
        a = random.randint(2, 5 + n // 2)
        return _pergunta("Potências e Raízes", f"Quanto é {a}³?", a ** 3, _dist_int(a ** 3, 0, [3 * a, a * a, a ** 3 + a]))
    k = random.randint(2, 12 + n)
    return _pergunta("Potências e Raízes", f"Qual é a raiz quadrada de {k * k}?", k, _dist_int(k, 1, [k * k // 2, k + 1, k - 1]))


def q_fracao(n):
    dens = [2, 3, 4, 5, 6, 8, 10]
    ops = ["+", "-"] + (["×"] if n >= 3 else [])
    while True:
        t1 = (random.randint(1, 9), random.choice(dens))
        t2 = (random.randint(1, 9), random.choice(dens))
        t1 = (min(t1[0], t1[1] - 1), t1[1])
        t2 = (min(t2[0], t2[1] - 1), t2[1])
        op = random.choice(ops)
        f1, f2 = Fraction(*t1), Fraction(*t2)
        if op == "-" and f1 < f2:
            t1, t2, f1, f2 = t2, t1, f2, f1
        (a, b), (c, d) = t1, t2
        if op == "+":
            res, errado = f1 + f2, Fraction(a + c, b + d)
        elif op == "-":
            res, errado = f1 - f2, Fraction(max(1, abs(a - c)), max(1, abs(b - d)))
        else:
            res, errado = f1 * f2, Fraction(a * d, b * c)
        if res > 0:
            break
    cands = [errado, res + Fraction(1, res.denominator), res * 2, Fraction(res.denominator, res.numerator)]
    if res - Fraction(1, res.denominator) > 0:
        cands.append(res - Fraction(1, res.denominator))
    dist = []
    for x in cands:
        if x != res and x not in dist:
            dist.append(x)
    return _pergunta("Frações", f"Quanto é {a}/{b} {op} {c}/{d}? (forma simplificada)", res, dist)


def q_expressao(n):
    a, b, c = random.randint(2, 10 + n), random.randint(2, 9), random.randint(2, 9)
    t = random.randint(0, 2)
    if t == 0:
        return _pergunta("Expressões", f"Quanto é {a} + {b} × {c}?", a + b * c, _dist_int(a + b * c, 0, [(a + b) * c]))
    if t == 1:
        return _pergunta("Expressões", f"Quanto é ({a} + {b}) × {c}?", (a + b) * c, _dist_int((a + b) * c, 0, [a + b * c]))
    return _pergunta("Expressões", f"Quanto é {a} × {b} - {c}?", a * b - c, _dist_int(a * b - c, None, [a * (b - c)]))


def q_sequencia(n):
    if n < 2 or random.random() < 0.6:
        s, r = random.randint(1, 20), random.randint(2, 5 + n)
        termos = [s + i * r for i in range(4)]
        prox = s + 4 * r
        extras = [prox + r, prox - 1, prox + 1]
    else:
        s, r = random.randint(1, 5), random.choice([2, 3])
        termos = [s * r ** i for i in range(4)]
        prox = s * r ** 4
        extras = [termos[-1] + (termos[-1] - termos[-2]), prox + r, prox * r]
    seq = ", ".join(map(str, termos))
    return _pergunta("Sequências", f"Qual é o próximo número da sequência: {seq}, ...?", prox, _dist_int(prox, 0, extras))


def q_problema(n):
    t = random.randint(0, 6)
    if t == 0:
        a, b = random.randint(3, 9 + n), random.randint(4, 12)
        return _pergunta("Problemas", f"Uma farmácia recebeu {a} caixas com {b} remédios cada. Quantos remédios ao todo?",
                         a * b, _dist_int(a * b, 0, [a + b, a * b + b]))
    if t == 1:
        a = random.randint(20, 60 + 10 * n)
        b = random.randint(5, a - 1)
        return _pergunta("Problemas", f"Ana tinha {a} figurinhas e deu {b} ao irmão. Com quantas ela ficou?",
                         a - b, _dist_int(a - b, 0, [a + b]))
    if t == 2:
        p, d = random.randint(2, 15) * 20, random.choice([10, 20, 25, 50])
        novo = p - p * d // 100
        return _pergunta("Problemas", f"Um tênis custa R$ {p} e está com {d}% de desconto. Qual é o novo preço?",
                         novo, _dist_int(novo, 0, [p * d // 100, p - d]), prefixo="R$ ")
    if t == 3:
        k, q = random.randint(2, 8), random.randint(3, 12)
        return _pergunta("Problemas", f"{k} amigos dividiram {k * q} balas igualmente. Quantas balas cada um recebeu?",
                         q, _dist_int(q, 1, [k * q - k, q + k]))
    if t == 4:
        v, h = random.choice([40, 50, 60, 80, 90, 100]), random.randint(2, 5)
        return _pergunta("Problemas", f"Um carro anda a {v} km/h. Quantos km ele percorre em {h} horas?",
                         v * h, _dist_int(v * h, 0, [v + h, v * (h - 1)]), sufixo=" km")
    l, c = random.randint(3, 12), random.randint(3, 15)
    if t == 5:
        return _pergunta("Problemas", f"Um retângulo mede {l} m por {c} m. Qual é a sua área?",
                         l * c, _dist_int(l * c, 0, [2 * (l + c), l + c]), sufixo=" m²")
    return _pergunta("Problemas", f"Um retângulo mede {l} m por {c} m. Qual é o seu perímetro?",
                     2 * (l + c), _dist_int(2 * (l + c), 0, [l * c, l + c]), sufixo=" m")


QUESTIONARIOS = {
    "Aritmética": q_aritmetica, "Tabuada": q_tabuada, "Divisão": q_divisao,
    "Porcentagem": q_porcentagem, "Equações": q_equacao, "Potências e Raízes": q_potencia,
    "Frações": q_fracao, "Expressões": q_expressao, "Sequências": q_sequencia, "Problemas": q_problema,
}


QUESTIONARIOS_GERAIS = {
    "Geografia": [
        ("Qual é a capital da Austrália?", "Canberra", ["Sydney", "Melbourne", "Perth"]),
        ("Qual é o maior estado brasileiro em área?", "Amazonas", ["Pará", "Mato Grosso", "Minas Gerais"]),
        ("Qual é o maior oceano da Terra?", "Oceano Pacífico", ["Oceano Atlântico", "Oceano Índico", "Oceano Ártico"]),
        ("Qual rio é tradicionalmente associado ao Egito?", "Rio Nilo", ["Rio Amazonas", "Rio Danúbio", "Rio Ganges"]),
        ("Qual é a capital do Japão?", "Tóquio", ["Osaka", "Quioto", "Hiroshima"]),
        ("Qual é o maior deserto do mundo?", "Antártida", ["Saara", "Gobi", "Atacama"]),
        ("Em qual cordilheira fica o Monte Everest?", "Himalaia", ["Andes", "Alpes", "Montanhas Rochosas"]),
        ("Qual país tem formato de uma bota e fica no sul da Europa?", "Itália", ["Grécia", "Portugal", "Croácia"]),
        ("Qual é a capital da França?", "Paris", ["Marselha", "Lyon", "Nantes"]),
        ("Qual é o menor país do mundo?", "Vaticano", ["Mônaco", "São Marino", "Liechtenstein"]),
        ("Em qual continente fica o deserto do Saara?", "África", ["Ásia", "Europa", "América"]),
        ("Qual país é conhecido como a Terra do Sol Nascente?", "Japão", ["China", "Coreia do Sul", "Tailândia"]),
        ("Qual é a capital da Argentina?", "Buenos Aires", ["Rosário", "Córdoba", "Montevidéu"]),
        ("Qual é a capital do Canadá?", "Ottawa", ["Toronto", "Montreal", "Vancouver"]),
        ("Qual país fica entre o Brasil e a Argentina?", "Uruguai", ["Paraguai", "Chile", "Bolívia"]),
        ("Qual é o rio mais longo do mundo?", "Rio Amazonas", ["Rio Nilo", "Rio Yangtzé", "Rio Mississipi"]),
        ("Qual é a capital da Noruega?", "Oslo", ["Estocolmo", "Copenhague", "Helsinque"]),
        ("Qual país tem a maior extensão territorial da América do Sul?", "Brasil", ["Argentina", "Peru", "Colômbia"]),
        ("Em qual país fica a cidade de Lisboa?", "Portugal", ["Espanha", "Itália", "França"]),
        ("Qual é a capital do México?", "Cidade do México", ["Guadalajara", "Monterrei", "Cancún"]),
        ("Qual é o ponto mais alto do Brasil?", "Pico da Neblina", ["Pico Paraná", "Monte Roraima", "Pico dos Orgãos"]),
        ("Qual estado brasileiro fica na região Nordeste?", "Bahia", ["Acre", "Rio Grande do Sul", "Pará"]),
        ("Qual é a maior ilha do mundo?", "Groenlândia", ["Madagáscar", "Bornéu", "Nova Guiné"]),
        ("Qual cidade fica na margem do Rio Tâmisa?", "Londres", ["Paris", "Berlim", "Madri"]),
        ("Qual país fica no extremo sul da América do Sul?", "Chile", ["Argentina", "Brasil", "Uruguai"]),
    ],
    "Ciências": [
        ("Qual é a fórmula química da água?", "H₂O", ["CO₂", "O₂", "NaCl"]),
        ("Qual planeta é conhecido como planeta vermelho?", "Marte", ["Vênus", "Júpiter", "Mercúrio"]),
        ("Qual gás as plantas absorvem principalmente na fotossíntese?", "Dióxido de carbono", ["Oxigênio", "Hidrogênio", "Hélio"]),
        ("Qual é a unidade de medida da corrente elétrica?", "Ampere", ["Volt", "Watt", "Ohm"]),
        ("Qual é o símbolo químico do ouro?", "Au", ["Ag", "Fe", "O"]),
        ("Qual gás é mais abundante na atmosfera terrestre?", "Nitrogênio", ["Oxigênio", "Dióxido de carbono", "Hidrogênio"]),
        ("Quantas câmaras tem o coração humano?", "Quatro", ["Duas", "Três", "Cinco"]),
        ("A que temperatura a água congela ao nível do mar?", "0 °C", ["-10 °C", "10 °C", "32 °C"]),
        ("Qual é a unidade de medida de força no Sistema Internacional?", "Newton", ["Joule", "Pascal", "Watt"]),
        ("Qual destes animais é um mamífero?", "Golfinho", ["Tubarão", "Polvo", "Truta"]),
        ("Qual é o órgão responsável pela circulação sanguínea?", "Coração", ["Pulmão", "Fígado", "Rim"]),
        ("Qual é o processo pelo qual a água passa do estado líquido para o gasoso?", "Evaporação", ["Condensação", "Solidificação", "Liquefação"]),
        ("Qual é a camada mais externa da Terra?", "Crosta", ["Manto", "Núcleo", "Mesosfera"]),
        ("Qual parte da célula contém o material genético?", "Núcleo", ["Membrana", "Mitocôndria", "Ribossomo"]),
        ("Qual é o gás liberado pelos seres vivos na respiração?", "Dióxido de carbono", ["Oxigênio", "Nitrogênio", "Hidrogênio"]),
        ("Qual elemento químico possui o símbolo Na?", "Sódio", ["Nióbio", "Níquel", "Neônio"]),
        ("Qual é a menor unidade viva?", "Célula", ["Átomo", "Molécula", "Tecido"]),
        ("Qual tipo de energia é armazenada em um objeto elevado?", "Energia potencial gravitacional", ["Energia térmica", "Energia cinética", "Energia química"]),
        ("Qual é a unidade de medida de pressão?", "Pascal", ["Volt", "Ohm", "Ampere"]),
        ("Qual é o nome científico do processo de formação das plantas a partir de sementes?", "Germinação", ["Fotossíntese", "Respiração", "Polinização"]),
        ("Qual é o maior órgão do corpo humano?", "Pele", ["Fígado", "Pulmão", "Coração"]),
        ("Qual substância é conhecida por apagar incêndios ao retirar o oxigênio?", "Água", ["Óleo", "Sal", "Vinagre"]),
        ("Qual é a causa da formação das marés?", "A atração da Lua", ["O movimento das estrelas", "A temperatura do oceano", "O vento"]),
        ("Qual é o nome da molécula que transporta energia na célula?", "ATP", ["DNA", "RNA", "ADN"]),
        ("Qual tipo de ondas são usadas pelos celulares para transmitir sinais?", "Ondas eletromagnéticas", ["Ondas sonoras", "Ondas térmicas", "Ondas gravitacionais"]),
    ],
    "História": [
        ("Em que ano foi proclamada a Independência do Brasil?", "1822", ["1500", "1889", "1922"]),
        ("Em que ano foi abolida a escravidão no Brasil?", "1888", ["1822", "1850", "1889"]),
        ("Em que ano terminou a Segunda Guerra Mundial?", "1945", ["1918", "1939", "1950"]),
        ("Qual cidade-estado grega é associada ao nascimento da democracia?", "Atenas", ["Esparta", "Corinto", "Tebas"]),
        ("Em que ano os portugueses chegaram ao território que hoje é o Brasil?", "1500", ["1492", "1530", "1600"]),
        ("Em que ano começou a Revolução Francesa?", "1789", ["1689", "1815", "1848"]),
        ("Qual civilização construiu Machu Picchu?", "Inca", ["Maia", "Asteca", "Olmeca"]),
        ("Quem foi o primeiro ser humano a pisar na Lua?", "Neil Armstrong", ["Yuri Gagarin", "Buzz Aldrin", "Alan Shepard"]),
        ("Quem foi o presidente dos Estados Unidos durante a Guerra de Secessão?", "Abraham Lincoln", ["George Washington", "Ulysses S. Grant", "Thomas Jefferson"]),
        ("Em que ano ocorreu a Proclamação da República no Brasil?", "1889", ["1879", "1900", "1892"]),
        ("Qual foi a primeira cidade brasileira fundada pelos portugueses?", "Salvador", ["Rio de Janeiro", "São Vicente", "Recife"]),
        ("Quem foi o imperador que aboliu a escravidão no Brasil?", "Dom Pedro II", ["Dom Pedro I", "Pedro Álvares Cabral", "Getúlio Vargas"]),
        ("Qual povo construiu o Coliseu?", "Romanos", ["Gregos", "Vikings", "Francos"]),
        ("Em que cidade ocorreu a Conferência de Berlim?", "Berlim", ["Paris", "Londres", "Roma"]),
        ("Quem liderou a independência do Haiti?", "Toussaint Louverture", ["Simón Bolívar", "José Bonifácio", "Pedro I"]),
        ("Qual foi o primeiro presidente do Brasil?", "Deodoro da Fonseca", ["Floriano Peixoto", "Prudente de Morais", "Campos Sales"]),
        ("Em que ano começou a Primeira Guerra Mundial?", "1914", ["1898", "1904", "1918"]),
        ("Qual civilização construiu os zigurates?", "Mesopotâmica", ["Egípcia", "Inca", "Romana"]),
        ("Quem foi o líder da Revolução Cubana?", "Fidel Castro", ["Che Guevara", "Raúl Castro", "Augusto César"]),
        ("Qual foi o período em que o Brasil foi governado por uma monarquia?", "Império", ["Colônia", "República Velha", "Ditadura"]),
        ("Quem foi o autor da Declaração de Independência dos Estados Unidos?", "Thomas Jefferson", ["Benjamin Franklin", "John Adams", "George Washington"]),
        ("Quem venceu a Batalha de Waterloo?", "Duque de Wellington", ["Napoleão Bonaparte", "Júlio César", "Adolf Hitler"]),
        ("Qual era o nome do antigo reino que ocupava a região do Egito?", "Egito Antigo", ["Roma Antiga", "Espanha Antiga", "Persia"]),
        ("Em que ano foi proclamada a Independência dos Estados Unidos?", "1776", ["1789", "1804", "1750"]),
    ],
    "Cultura": [
        ("Quem pintou a Mona Lisa?", "Leonardo da Vinci", ["Michelangelo", "Vincent van Gogh", "Pablo Picasso"]),
        ("Quem escreveu o romance Dom Casmurro?", "Machado de Assis", ["José de Alencar", "Clarice Lispector", "Carlos Drummond de Andrade"]),
        ("Qual é o idioma oficial do Brasil?", "Português", ["Espanhol", "Francês", "Italiano"]),
        ("Qual instrumento musical tem teclas, cordas e martelos?", "Piano", ["Flauta", "Trompete", "Violino"]),
        ("Quem criou a personagem Harry Potter?", "J. K. Rowling", ["Suzanne Collins", "C. S. Lewis", "Agatha Christie"]),
        ("Qual estilo musical brasileiro está ligado ao desfile de escolas no Carnaval?", "Samba", ["Fado", "Tango", "Flamenco"]),
        ("Quantos anéis aparecem no símbolo dos Jogos Olímpicos?", "Cinco", ["Quatro", "Seis", "Sete"]),
        ("Qual destes instrumentos pertence à família das cordas?", "Violão", ["Clarinete", "Trombone", "Tímpano"]),
        ("Quem escreveu o livro O Pequeno Príncipe?", "Antoine de Saint-Exupéry", ["Jules Verne", "Luís de Camões", "George Orwell"]),
        ("Qual é a capital cultural do Brasil?", "Rio de Janeiro", ["São Paulo", "Salvador", "Belo Horizonte"]),
        ("Quem compôs o Hino Nacional Brasileiro?", "Francisco Manuel da Silva", ["Heitor Villa-Lobos", "Tom Jobim", "Carlos Gomes"]),
        ("Qual é o nome do festival brasileiro de música e arte que celebra a cultura popular?", "Samba", ["Rock in Rio", "Câncer", "Bossa Nova"]),
        ("Quem foi o escritor de A Divina Comédia?", "Dante Alighieri", ["William Shakespeare", "Miguel de Cervantes", "Friedrich Nietzsche"]),
        ("Qual destes artistas é conhecido pela pintura de Guernica?", "Pablo Picasso", ["Vincent van Gogh", "Claude Monet", "Leonardo da Vinci"]),
        ("Qual é o instrumento principal de uma orquestra?", "Violino", ["Bateria", "Flauta", "Piano"]),
        ("Qual é o nome do movimento literário de Machado de Assis?", "Realismo", ["Romantismo", "Modernismo", "Barroco"]),
        ("Quem escreveu a obra O Alienista?", "Machado de Assis", ["Érico Veríssimo", "Clarice Lispector", "Graciliano Ramos"]),
        ("Qual é o nome do teatro famoso no Brasil?", "Teatro Municipal do Rio de Janeiro", ["Teatro Amazonas", "Teatro Nacional", "Teatro da Paz"]),
        ("Quem criou a personagem Capitão América?", "Stan Lee", ["Jack Kirby", "Steve Ditko", "Alan Moore"]),
        ("Qual gênero musical é associado ao ritmo de dança do tango?", "Tango", ["Samba", "Baião", "Frevo"]),
        ("Qual é o nome do personagem principal de O Rei Leão?", "Simba", ["Mufasa", "Timon", "Pumba"]),
        ("Qual é o instrumento que toca a música de uma orquestra com uma pequena batuta?", "Maestro", ["Pianista", "Violinista", "Cantor"]),
        ("Quem escreveu a obra A Comédia Francesa?", "Molière", ["Victor Hugo", "Albert Camus", "Émile Zola"]),
        ("Qual autora escreveu O Diário de Anne Frank?", "Anne Frank", ["J. K. Rowling", "Agatha Christie", "Virginia Woolf"]),
    ],
}
MATERIAS_QUIZ = ("Matemática", *QUESTIONARIOS_GERAIS)


def _pergunta_textual(categoria, enunciado, correta, distratores):
    opcoes = list(dict.fromkeys([correta, *distratores]))
    while len(opcoes) < 4:
        alternativa = f"Outra resposta {len(opcoes)}"
        if alternativa not in opcoes:
            opcoes.append(alternativa)
    random.shuffle(opcoes)
    resposta = correta
    return {"categoria": categoria, "enunciado": enunciado, "opcoes": opcoes,
            "indice_correto": opcoes.index(resposta), "resposta": resposta}


def _identificar_pergunta(categoria, pergunta):
    return categoria, pergunta["enunciado"], tuple(pergunta["opcoes"])


def sortear_pergunta(nivel, evitar=None, materias=None, usadas=None):
    selecionadas = set(materias or ("Matemática",))
    opcoes = []
    for materia in MATERIAS_QUIZ:
        if materia not in selecionadas:
            continue
        if materia == "Matemática":
            opcoes.extend(QUESTIONARIOS.items())
        else:
            opcoes.append((materia, None))
    if not opcoes:
        opcoes = list(QUESTIONARIOS.items())
    usadas = set(usadas or ())
    categorias = [opcao for opcao in opcoes if opcao[0] != evitar]
    if not categorias:
        categorias = opcoes

    for _ in range(20):
        categoria, gerador = random.choice(categorias)
        if gerador is not None:
            pergunta = gerador(nivel)
        else:
            perguntas = QUESTIONARIOS_GERAIS[categoria]
            pergunta = _pergunta_textual(categoria, *random.choice(perguntas))
        identificador = _identificar_pergunta(categoria, pergunta)
        if identificador not in usadas:
            return pergunta

    categoria, gerador = random.choice(categorias)
    if gerador is not None:
        return gerador(nivel)
    return _pergunta_textual(categoria, *random.choice(QUESTIONARIOS_GERAIS[categoria]))


# ---------------------------------------------------------------------------
# Utilidades visuais e sonoras
# ---------------------------------------------------------------------------
def fonte(tam, negrito=False):
    try:
        return pygame.font.SysFont("segoeui,arial,dejavusans,liberationsans", tam, bold=negrito)
    except Exception:
        return pygame.font.Font(None, tam)


def misturar(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def quebrar_texto(texto, fnt, largura_max):
    linhas, atual = [], ""
    for p in texto.split(" "):
        teste = (atual + " " + p).strip()
        if fnt.size(teste)[0] <= largura_max:
            atual = teste
        else:
            if atual:
                linhas.append(atual)
            atual = p
    if atual:
        linhas.append(atual)
    return linhas


def texto_centro(tela, fnt, texto, cor, cx, cy):
    s = fnt.render(texto, True, cor)
    tela.blit(s, s.get_rect(center=(int(cx), int(cy))))


def desenhar_capsula(tela, rect, cor, icone, fnt):
    pygame.draw.rect(tela, cor, rect, border_radius=rect.height // 2)
    pygame.draw.rect(tela, misturar(cor, (255, 255, 255), 0.6), rect, 2, border_radius=rect.height // 2)
    texto_centro(tela, fnt, icone, (20, 20, 30), rect.centerx, rect.centery)


def desenhar_coracao(tela, x, y, cor):
    pygame.draw.circle(tela, cor, (x - 4, y - 2), 5)
    pygame.draw.circle(tela, cor, (x + 4, y - 2), 5)
    pygame.draw.polygon(tela, cor, [(x - 9, y), (x + 9, y), (x, y + 9)])


def criar_fundo():
    s = pygame.Surface((LARGURA, ALTURA))
    for y in range(ALTURA):
        pygame.draw.line(s, misturar(COR_FUNDO_1, COR_FUNDO_2, y / ALTURA), (0, y), (LARGURA, y))
    grade = misturar(COR_FUNDO_1, (60, 60, 110), 0.25)
    for x in range(0, LARGURA, 40):
        pygame.draw.line(s, grade, (x, TOPO_HUD), (x, ALTURA))
    for y in range(TOPO_HUD, ALTURA, 40):
        pygame.draw.line(s, grade, (0, y), (LARGURA, y))
    return s


class Sons:
    def __init__(self):
        self.ok = False
        try:
            if not pygame.mixer.get_init():
                pygame.mixer.init(22050, -16, 1, 512)
            self.freq, _, self.canais = pygame.mixer.get_init()
            self.sons = {
                "raquete": self._seq([(440, 0.05)]),
                "parede": self._seq([(330, 0.03)], 0.12),
                "bloco": self._seq([(660, 0.05)]),
                "duro": self._seq([(250, 0.05)], 0.2),
                "drop": self._seq([(520, 0.06), (780, 0.08)]),
                "certo": self._seq([(523, 0.08), (659, 0.08), (784, 0.08), (1047, 0.16)]),
                "errado": self._seq([(300, 0.12), (200, 0.22)]),
                "vida": self._seq([(220, 0.15), (180, 0.15), (140, 0.3)]),
                "laser": self._seq([(900, 0.04)], 0.1),
                "nivel": self._seq([(392, 0.1), (523, 0.1), (659, 0.1), (784, 0.25)]),
            }
            self.ok = True
        except Exception:
            self.ok = False

    def _seq(self, notas, vol=0.22):
        buf = array.array("h")
        for f, d in notas:
            n = int(self.freq * d)
            for i in range(n):
                env = 1 - 0.85 * (i / n)
                v = vol if math.sin(2 * math.pi * f * i / self.freq) >= 0 else -vol
                amostra = int(v * env * 32767)
                for _ in range(self.canais):
                    buf.append(amostra)
        return pygame.mixer.Sound(buffer=buf.tobytes())

    def tocar(self, nome):
        if self.ok:
            try:
                self.sons[nome].play()
            except Exception:
                pass


ARQ_RECORDE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "recorde_breakout_matematico.txt")


def carregar_recorde():
    try:
        with open(ARQ_RECORDE, encoding="utf-8") as f:
            return int(f.read().strip() or 0)
    except Exception:
        return 0


def salvar_recorde(valor):
    try:
        with open(ARQ_RECORDE, "w", encoding="utf-8") as f:
            f.write(str(valor))
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Entidades
# ---------------------------------------------------------------------------
class Raquete:
    def __init__(self):
        self.x, self.y = LARGURA / 2, ALTURA - 48
        self.largura, self.altura = float(LARG_RAQUETE), 16
        self.vel = 11

    def rect(self):
        return pygame.Rect(int(self.x - self.largura / 2), int(self.y - self.altura / 2), int(self.largura), self.altura)


class Bola:
    def __init__(self, x, y, vx=0.0, vy=0.0):
        self.x, self.y, self.vx, self.vy = x, y, vx, vy
        self.r = 8
        self.presa, self.offset = False, 0.0
        self.rastro = []

    def rect(self):
        return pygame.Rect(int(self.x - self.r), int(self.y - self.r), self.r * 2, self.r * 2)


class Bloco:
    def __init__(self, rect, cor, pontos, hp, tipo="normal"):
        self.rect, self.cor, self.pontos = rect, cor, pontos
        self.hp = self.hp_max = hp
        self.tipo = tipo


class Drop:
    def __init__(self, x, y, tipo):
        self.x, self.y, self.tipo = x, y, tipo
        self.vy, self.t = 2.6, 0.0

    def rect(self):
        return pygame.Rect(int(self.x - 24), int(self.y - 11), 48, 22)


class Particula:
    def __init__(self, x, y, cor):
        ang, v = random.uniform(0, 2 * math.pi), random.uniform(1, 5)
        self.x, self.y = x, y
        self.vx, self.vy = math.cos(ang) * v, math.sin(ang) * v - 1
        self.vida = self.vida_max = random.uniform(0.4, 0.9)
        self.cor, self.tam = cor, random.randint(2, 5)

    def update(self, dt):
        f = dt * 60
        self.x += self.vx * f
        self.y += self.vy * f
        self.vy += 0.15 * f
        self.vida -= dt

    def draw(self, tela):
        tam = max(1, int(self.tam * max(0.0, self.vida / self.vida_max)))
        pygame.draw.rect(tela, self.cor, (int(self.x), int(self.y), tam, tam))


class TextoFlutuante:
    def __init__(self, texto, x, y, cor):
        self.texto, self.x, self.y, self.cor = texto, x, y, cor
        self.vida = 1.4


def criar_blocos(nivel, modo="padrao", dificuldade="normal"):
    linhas, colunas, gap, margem = 8, 14, 4, 40
    larg = (LARGURA - 2 * margem - gap * (colunas - 1)) / colunas
    alt, y0 = 22, TOPO_HUD + 50
    padrao = (nivel - 1) % 5
    ajustes = {"facil": {"densidade": 0.62, "vida_extra": 0, "hazards": (3, 2)},
               "normal": {"densidade": 0.74, "vida_extra": 0, "hazards": (4, 3)},
               "dificil": {"densidade": 0.86, "vida_extra": 1, "hazards": (5, 4)}}
    ajuste = ajustes[dificuldade]
    procedural = random.randrange(5) if modo == "random" else None
    blocos = []
    for r in range(linhas):
        cor, pts = LINHAS_ATARI[r]
        for c in range(colunas):
            if procedural is not None:
                chance = ajuste["densidade"]
                x_norm = (c - (colunas - 1) / 2) / (colunas / 2)
                y_norm = r / (linhas - 1)
                if procedural == 0:
                    ligado = random.random() < chance
                elif procedural == 1:
                    ligado = (x_norm * x_norm + (y_norm - 0.45) ** 2 < 0.95
                              and random.random() < min(1.0, chance + 0.12))
                elif procedural == 2:
                    ligado = ((r + c + random.randint(0, 1)) % 3 != 0
                              and random.random() < chance + 0.15)
                elif procedural == 3:
                    faixa = (r + random.randint(0, 2)) % 4 != 0
                    ligado = faixa and random.random() < min(1.0, chance + 0.1)
                else:
                    ligado = (abs(c - random.randint(2, colunas - 3)) <= (linhas - r) * 0.9
                              and random.random() < min(1.0, chance + 0.2))
            elif padrao == 0:
                ligado = True
            elif padrao == 1:
                ligado = (r + c) % 2 == 0 or r < 2
            elif padrao == 2:
                ligado = abs(c - (colunas - 1) / 2) <= (linhas - r) * 0.9
            elif padrao == 3:
                ligado = not (3 <= c <= 10 and 2 <= r <= 5)
            else:
                ligado = random.random() < 0.75
            rect = pygame.Rect(int(margem + c * (larg + gap)), int(y0 + r * (alt + gap)), int(larg), alt)
            if not ligado:
                if procedural is not None:
                    tipo = random.choices(("obstaculo", "bomba"), weights=ajuste["hazards"])[0]
                    if tipo == "obstaculo":
                        blocos.append(Bloco(rect, (125, 130, 145), 0, 1, "obstaculo"))
                    elif tipo == "bomba":
                        blocos.append(Bloco(rect, (225, 75, 55), 0, 1, "bomba"))
                continue
            hp = 1
            if nivel >= 2 and r < 2:
                hp = 2
            if nivel >= 4:
                hp = 3 if r < 2 else (2 if r < 4 else 1)
            hp = min(4, hp + ajuste["vida_extra"] + (1 if modo == "random" and nivel >= 3 and r < 2 else 0))
            blocos.append(Bloco(rect, cor, pts, hp))
    if not any(bl.tipo == "normal" for bl in blocos):
        rect = pygame.Rect(LARGURA // 2 - 30, y0, 60, alt)
        blocos.append(Bloco(rect, LINHAS_ATARI[0][0], LINHAS_ATARI[0][1], 1 + ajuste["vida_extra"]))
    return blocos


# ---------------------------------------------------------------------------
# Jogo
# ---------------------------------------------------------------------------
class Jogo:
    def __init__(self):
        pygame.mixer.pre_init(22050, -16, 1, 512)
        pygame.init()
        self.tela = pygame.display.set_mode((LARGURA, ALTURA))
        pygame.display.set_caption("Breakout Genius")
        self.relogio = pygame.time.Clock()
        self.f_mini = fonte(15, True)
        self.f_peq = fonte(18)
        self.f_peq_b = fonte(18, True)
        self.f_med = fonte(24, True)
        self.f_grande = fonte(32, True)
        self.f_titulo = fonte(60, True)
        self.sons = Sons()
        self.fundo = criar_fundo()
        self.recorde = carregar_recorde()
        self.materias_selecionadas = {"Matemática"}
        self.perguntas_usadas = set()
        self.modo_jogo = "padrao"
        self.dificuldade = "normal"
        self.foco_modo = 0
        self.foco_dificuldade = 1
        self.foco_materia = 0
        self.foco_confirmar = False
        self.usar_mouse = False
        self.tempo = 0.0
        self.opcoes_rects = []
        self.botao_jogar_rect = pygame.Rect(LARGURA // 2 - 130, 650, 260, 48)
        self.modos_jogo_rects = [
            (pygame.Rect(LARGURA // 2 - 220 + i * 240, 320, 210, 90), modo, nome)
            for i, (modo, nome) in enumerate((("padrao", "Padrão"), ("random", "Random")))
        ]
        self.dificuldades_rects = [
            (pygame.Rect(LARGURA // 2 - 330 + i * 220, 320, 200, 72), dificuldade, nome)
            for i, (dificuldade, nome) in enumerate((
                ("facil", "Fácil"), ("normal", "Normal"), ("dificil", "Difícil"),
            ))
        ]
        self.materias_rects = [
            (pygame.Rect(LARGURA // 2 - 280 + (i % 2) * 285,
                         235 + (i // 2) * 60, 270, 48), materia)
            for i, materia in enumerate(MATERIAS_QUIZ)
        ]
        self.botao_confirmar_rect = pygame.Rect(LARGURA // 2 - 120, 445, 240, 48)
        self.novo_jogo()
        self.estado = "MENU"

    # ---------------- ciclo de vida ----------------
    def novo_jogo(self):
        self.pontos, self.vidas, self.nivel = 0, 3, 1
        self.stats = {"total": 0, "acertos": 0, "por_cat": {}, "tempo": 0.0, "boosts": {}}
        self.ultima_cat = None
        self.perguntas_usadas = set()
        self.raquete = Raquete()
        self.carregar_nivel()
        self.estado = "JOGANDO"

    def carregar_nivel(self):
        self.blocos = criar_blocos(self.nivel, self.modo_jogo, self.dificuldade)
        self.drops, self.lasers, self.particulas, self.textos = [], [], [], []
        self.ativos = {}
        self.quiz = None
        self.congelado = 0.0
        self.cooldown_laser = 0.0
        self.resetar_bola()

    def resetar_bola(self):
        r = self.raquete
        b = Bola(r.x, r.y - r.altura / 2 - 9)
        b.presa = True
        self.bolas = [b]
        self.acel = 1.0

    def velocidade_bola(self):
        ajustes = {"facil": (0.88, 0.28, 8.0), "normal": (1.0, 0.4, 9.0),
                   "dificil": (1.16, 0.58, 10.0)}
        fator, crescimento, limite = ajustes[self.dificuldade]
        v = min((4.8 + crescimento * (self.nivel - 1)) * fator, limite) * self.acel
        v *= 0.65 if "LENTA" in self.ativos else 1.0
        return v * (1.35 if "BOLA_RAPIDA" in self.ativos else 1.0)

    def lancar(self):
        sp = self.velocidade_bola()
        for b in self.bolas:
            if b.presa:
                off = b.offset / max(1.0, self.raquete.largura / 2)
                ang = math.radians(off * 55 if b.offset else random.uniform(-25, 25))
                b.vx, b.vy = sp * math.sin(ang), -sp * math.cos(ang)
                b.presa, b.offset = False, 0.0

    def perder_vida(self):
        self.vidas -= 1
        self.sons.tocar("vida")
        self.ativos, self.drops, self.lasers = {}, [], []
        if self.vidas <= 0:
            self.finalizar()
        else:
            self.resetar_bola()
            self.congelado = 0.5

    def finalizar(self):
        self.novo_recorde = self.pontos > carregar_recorde()
        self.recorde = max(self.recorde, self.pontos)
        salvar_recorde(self.recorde)
        self.estado = "FIM"

    # ---------------- quiz ----------------
    def abrir_quiz(self, tipo):
        p = sortear_pergunta(self.nivel, self.ultima_cat, self.materias_selecionadas, self.perguntas_usadas)
        self.ultima_cat = p["categoria"]
        self.perguntas_usadas.add((p["categoria"], p["enunciado"], tuple(p["opcoes"])))
        tempo_base = {"facil": 25, "normal": 20, "dificil": 16}[self.dificuldade]
        tempo = max(8, tempo_base - int((self.nivel - 1) * 0.8))
        self.quiz = {"p": p, "tipo": tipo, "tempo": tempo, "restante": float(tempo),
                     "escolha": None, "acertou": None, "fb": 0.0, "bonus": 0}
        self.estado = "QUIZ"
        self.sons.tocar("drop")

    def responder(self, indice):
        q = self.quiz
        if q is None or q["escolha"] is not None:
            return
        p = q["p"]
        q["escolha"] = indice
        q["acertou"] = acertou = indice == p["indice_correto"]
        cat = self.stats["por_cat"].setdefault(p["categoria"], [0, 0])
        cat[1] += 1
        self.stats["total"] += 1
        self.stats["tempo"] += q["tempo"] - q["restante"]
        if acertou:
            cat[0] += 1
            self.stats["acertos"] += 1
            q["bonus"] = (50 + int(q["restante"] * 10)) * self.nivel
            self.pontos += q["bonus"]
            self.ativos.pop("ENCOLHE", None)
            self.aplicar_boost(q["tipo"])
            self.sons.tocar("certo")
        else:
            downgrade = random.choice(tuple(DOWNGRADES))
            self.ativos[downgrade] = DOWNGRADES[downgrade]["dur"]
            q["downgrade"] = downgrade
            info = DOWNGRADES[downgrade]
            self.textos.append(TextoFlutuante(f"{info['nome']}!", self.raquete.x, self.raquete.y - 40, info["cor"]))
            self.sons.tocar("errado")
        q["fb"] = 2.4

    def fechar_quiz(self):
        self.quiz = None
        self.estado = "JOGANDO"
        self.congelado = 0.7

    def alternar_materia(self, materia):
        if materia in self.materias_selecionadas:
            if len(self.materias_selecionadas) > 1:
                self.materias_selecionadas.remove(materia)
        else:
            self.materias_selecionadas.add(materia)

    def aplicar_boost(self, tipo):
        info = BOOSTS[tipo]
        self.stats["boosts"][tipo] = self.stats["boosts"].get(tipo, 0) + 1
        r = self.raquete
        if tipo == "MULTI":
            soltas = [b for b in self.bolas if not b.presa]
            src = soltas[0] if soltas else self.bolas[0]
            sp = self.velocidade_bola()
            x, y = (src.x, src.y) if soltas else (r.x, r.y - 20)
            for ang in (-30, 30):
                a = math.radians(ang)
                self.bolas.append(Bola(x, y, sp * math.sin(a), -sp * math.cos(a)))
        elif tipo == "VIDA":
            self.vidas = min(9, self.vidas + 1)
        else:
            self.ativos[tipo] = min(30, self.ativos.get(tipo, 0) + info["dur"])
        self.textos.append(TextoFlutuante(f"{info['nome']}!", r.x, r.y - 40, info["cor"]))

    # ---------------- física ----------------
    def acertar_bloco(self, bl, destruir=False):
        if bl not in self.blocos:
            return
        if bl.tipo == "obstaculo":
            return
        if bl.tipo == "bomba":
            self.explodir_bomba(bl)
            return
        bl.hp = 0 if destruir else bl.hp - 1
        cx, cy = bl.rect.center
        if bl.hp > 0:
            self.sons.tocar("duro")
            for _ in range(4):
                self.particulas.append(Particula(cx, cy, (220, 220, 230)))
            return
        self.blocos.remove(bl)
        pts = bl.pontos * self.nivel * (2 if "X2" in self.ativos else 1)
        self.pontos += pts
        self.sons.tocar("bloco")
        for _ in range(12):
            self.particulas.append(Particula(cx, cy, bl.cor))
        if random.random() < CHANCE_DROP and len(self.drops) < MAX_DROPS:
            tipos, pesos = zip(*PESOS_BOOST.items())
            self.drops.append(Drop(cx, cy, random.choices(tipos, pesos)[0]))

    def explodir_bomba(self, bomba):
        fila = [bomba]
        raio = 105
        while fila:
            atual = fila.pop()
            if atual not in self.blocos or atual.tipo != "bomba":
                continue
            self.blocos.remove(atual)
            cx, cy = atual.rect.center
            self.sons.tocar("bloco")
            for _ in range(28):
                self.particulas.append(Particula(cx, cy, random.choice(((255, 90, 40), (255, 190, 50), (230, 230, 210)))))
            self.textos.append(TextoFlutuante("BOOM!", cx, cy, (255, 150, 60)))
            for vizinho in self.blocos[:]:
                vx, vy = vizinho.rect.center
                if math.hypot(vx - cx, vy - cy) > raio:
                    continue
                if vizinho.tipo == "bomba":
                    fila.append(vizinho)
                elif vizinho.tipo == "normal":
                    self.acertar_bloco(vizinho, destruir=True)

    def colidir_blocos(self, b, eixo):
        rb = b.rect()
        atingidos = [bl for bl in self.blocos if rb.colliderect(bl.rect)]
        if not atingidos:
            return
        obstaculos = [bl for bl in atingidos if bl.tipo == "obstaculo"]
        if obstaculos:
            bl = obstaculos[0]
            if eixo == "x":
                b.x = bl.rect.left - b.r - 0.1 if b.vx > 0 else bl.rect.right + b.r + 0.1
                b.vx = -b.vx
            else:
                b.y = bl.rect.top - b.r - 0.1 if b.vy > 0 else bl.rect.bottom + b.r + 0.1
                b.vy = -b.vy
            self.sons.tocar("duro")
            return
        if "FOGO" in self.ativos:
            for bl in atingidos:
                self.acertar_bloco(bl, destruir=True)
            return
        bl = atingidos[0]
        if eixo == "x":
            b.x = bl.rect.left - b.r - 0.1 if b.vx > 0 else bl.rect.right + b.r + 0.1
            b.vx = -b.vx
        else:
            b.y = bl.rect.top - b.r - 0.1 if b.vy > 0 else bl.rect.bottom + b.r + 0.1
            b.vy = -b.vy
        self.acertar_bloco(bl)

    def normalizar(self, b, sp):
        m = math.hypot(b.vx, b.vy)
        if m == 0:
            b.vx, b.vy = 0.0, -sp
            return
        b.vx, b.vy = b.vx / m * sp, b.vy / m * sp
        minimo = sp * 0.3  # evita trajetórias quase horizontais
        if abs(b.vy) < minimo:
            b.vy = math.copysign(minimo, b.vy or -1)
            b.vx = math.copysign(math.sqrt(sp * sp - minimo * minimo), b.vx or 1)

    def mover_bola(self, b, dt):
        """Retorna False se a bola caiu."""
        f = dt * 60
        passos = max(1, int(math.hypot(b.vx, b.vy) * f / 4) + 1)
        r = self.raquete
        for _ in range(passos):
            b.x += b.vx * f / passos
            if b.x < b.r:
                b.x, b.vx = b.r, abs(b.vx)
                self.sons.tocar("parede")
            elif b.x > LARGURA - b.r:
                b.x, b.vx = LARGURA - b.r, -abs(b.vx)
                self.sons.tocar("parede")
            self.colidir_blocos(b, "x")

            b.y += b.vy * f / passos
            if b.y < TOPO_HUD + b.r:
                b.y, b.vy = TOPO_HUD + b.r, abs(b.vy)
                self.sons.tocar("parede")
            self.colidir_blocos(b, "y")

            pr = r.rect()
            if b.vy > 0 and b.rect().colliderect(pr) and b.y < pr.centery:
                off = max(-1.0, min(1.0, (b.x - r.x) / (r.largura / 2)))
                ang = math.radians(off * 60)
                sp = math.hypot(b.vx, b.vy)
                b.vx, b.vy = sp * math.sin(ang), -abs(sp * math.cos(ang))
                b.y = pr.top - b.r - 0.1
                self.acel = min(1.3, self.acel + 0.01)
                self.sons.tocar("raquete")
                if "IMA" in self.ativos:
                    b.presa, b.offset = True, b.x - r.x
                    return True
            if b.y - b.r > ALTURA:
                return False
        return True

    def disparar_laser(self):
        r = self.raquete
        for dx in (-r.largura / 2 + 8, r.largura / 2 - 8):
            self.lasers.append([r.x + dx, r.y - 12])
        self.cooldown_laser = 0.22
        self.sons.tocar("laser")

    # ---------------- update ----------------
    def update(self, dt):
        self.tempo += dt
        for p in self.particulas[:]:
            p.update(dt)
            if p.vida <= 0:
                self.particulas.remove(p)
        for t in self.textos[:]:
            t.y -= 40 * dt
            t.vida -= dt
            if t.vida <= 0:
                self.textos.remove(t)

        if self.estado == "QUIZ":
            q = self.quiz
            if q["escolha"] is None:
                q["restante"] -= dt
                if q["restante"] <= 0:
                    q["restante"] = 0
                    self.responder(-1)
            else:
                q["fb"] -= dt
                if q["fb"] <= 0:
                    self.fechar_quiz()
            return

        if self.estado == "NIVEL":
            self.timer_nivel -= dt
            if self.timer_nivel <= 0:
                self.nivel += 1
                self.carregar_nivel()
                self.estado = "JOGANDO"
            return

        if self.estado != "JOGANDO":
            return

        # Boosts temporizados
        for k in list(self.ativos):
            self.ativos[k] -= dt
            if self.ativos[k] <= 0:
                del self.ativos[k]
                if k == "IMA":
                    self.lancar()

        # Raquete
        r = self.raquete
        alvo = LARG_RAQUETE * (1.5 if "LARGA" in self.ativos else 1.0) * (0.65 if "ENCOLHE" in self.ativos else 1.0)
        r.largura += (alvo - r.largura) * min(1.0, dt * 10)
        teclas = pygame.key.get_pressed()
        dx = (teclas[pygame.K_RIGHT] or teclas[pygame.K_d]) - (teclas[pygame.K_LEFT] or teclas[pygame.K_a])
        if dx:
            self.usar_mouse = False
            r.x += dx * r.vel * (0.55 if "RAQUETE_LENTA" in self.ativos else 1.0) * dt * 60
        elif self.usar_mouse:
            r.x = pygame.mouse.get_pos()[0]
        r.x = max(r.largura / 2, min(LARGURA - r.largura / 2, r.x))

        # Laser
        self.cooldown_laser -= dt
        if "LASER" in self.ativos and teclas[pygame.K_SPACE] and self.cooldown_laser <= 0 \
                and not any(b.presa for b in self.bolas):
            self.disparar_laser()
        for l in self.lasers[:]:
            l[1] -= 12 * dt * 60
            lr = pygame.Rect(int(l[0] - 2), int(l[1]), 4, 12)
            alvo_bl = next((bl for bl in self.blocos if lr.colliderect(bl.rect)), None)
            if alvo_bl:
                self.acertar_bloco(alvo_bl)
                self.lasers.remove(l)
            elif l[1] < TOPO_HUD:
                self.lasers.remove(l)

        # Bolas
        if self.congelado > 0:
            self.congelado -= dt
        sp = self.velocidade_bola()
        for b in self.bolas[:]:
            if b.presa:
                b.x, b.y = r.x + b.offset, r.y - r.altura / 2 - b.r - 1
                b.rastro.clear()
                continue
            if self.congelado > 0:
                continue
            self.normalizar(b, sp)
            vivo = self.mover_bola(b, dt)
            b.rastro.append((b.x, b.y))
            del b.rastro[:-8]
            if not vivo:
                self.bolas.remove(b)
        if not self.bolas:
            self.perder_vida()
            return

        # Drops (cápsulas)
        for d in self.drops[:]:
            d.y += d.vy * dt * 60
            d.t += dt
            if d.rect().colliderect(r.rect()):
                self.drops.remove(d)
                self.abrir_quiz(d.tipo)
                return
            if d.y > ALTURA + 20:
                self.drops.remove(d)

        if self.pontos > self.recorde:
            self.recorde = self.pontos

        if not any(bl.tipo != "obstaculo" for bl in self.blocos):
            self.blocos.clear()
            self.pontos += self.vidas * 100 * self.nivel
            self.timer_nivel = 2.5
            self.estado = "NIVEL"
            self.sons.tocar("nivel")

    # ---------------- eventos ----------------
    def tratar_evento(self, ev):
        if ev.type == pygame.QUIT:
            self.sair()
        if ev.type == pygame.MOUSEMOTION and self.estado == "JOGANDO":
            self.usar_mouse = True

        if self.estado == "MENU":
            if ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_RETURN, pygame.K_KP_ENTER, pygame.K_SPACE):
                    self.estado = "SELECAO_MODO"
                elif ev.key == pygame.K_ESCAPE:
                    self.sair()
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                if self.botao_jogar_rect.collidepoint(ev.pos):
                    self.estado = "SELECAO_MODO"

        elif self.estado == "SELECAO_MODO":
            if ev.type == pygame.KEYDOWN:
                modos = {pygame.K_1: "padrao", pygame.K_2: "random",
                         pygame.K_KP1: "padrao", pygame.K_KP2: "random"}
                if ev.key in modos:
                    self.modo_jogo = modos[ev.key]
                    self.estado = "SELECAO_DIFICULDADE"
                elif ev.key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN):
                    self.foco_modo = 1 - self.foco_modo
                elif ev.key in (pygame.K_RETURN, pygame.K_KP_ENTER, pygame.K_SPACE):
                    self.modo_jogo = self.modos_jogo_rects[self.foco_modo][1]
                    self.estado = "SELECAO_DIFICULDADE"
                elif ev.key == pygame.K_ESCAPE:
                    self.estado = "MENU"
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                for rect, modo, _ in self.modos_jogo_rects:
                    if rect.collidepoint(ev.pos):
                        self.modo_jogo = modo
                        self.estado = "SELECAO_DIFICULDADE"
                        break

        elif self.estado == "SELECAO_DIFICULDADE":
            if ev.type == pygame.KEYDOWN:
                dificuldades = {pygame.K_1: "facil", pygame.K_2: "normal", pygame.K_3: "dificil",
                                pygame.K_KP1: "facil", pygame.K_KP2: "normal", pygame.K_KP3: "dificil"}
                if ev.key in dificuldades:
                    self.dificuldade = dificuldades[ev.key]
                    self.estado = "SELECAO_QUIZ"
                elif ev.key in (pygame.K_LEFT, pygame.K_RIGHT):
                    self.foco_dificuldade = (self.foco_dificuldade + (1 if ev.key == pygame.K_RIGHT else -1)) % len(self.dificuldades_rects)
                elif ev.key in (pygame.K_UP, pygame.K_DOWN):
                    self.foco_dificuldade = 1
                elif ev.key in (pygame.K_RETURN, pygame.K_KP_ENTER, pygame.K_SPACE):
                    self.dificuldade = self.dificuldades_rects[self.foco_dificuldade][1]
                    self.estado = "SELECAO_QUIZ"
                elif ev.key == pygame.K_ESCAPE:
                    self.estado = "SELECAO_MODO"
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                for rect, dificuldade, _ in self.dificuldades_rects:
                    if rect.collidepoint(ev.pos):
                        self.dificuldade = dificuldade
                        self.estado = "SELECAO_QUIZ"
                        break

        elif self.estado == "SELECAO_QUIZ":
            if ev.type == pygame.KEYDOWN:
                materias_por_tecla = {
                    pygame.K_1: MATERIAS_QUIZ[0], pygame.K_2: MATERIAS_QUIZ[1],
                    pygame.K_3: MATERIAS_QUIZ[2], pygame.K_4: MATERIAS_QUIZ[3],
                    pygame.K_5: MATERIAS_QUIZ[4], pygame.K_KP1: MATERIAS_QUIZ[0],
                    pygame.K_KP2: MATERIAS_QUIZ[1], pygame.K_KP3: MATERIAS_QUIZ[2],
                    pygame.K_KP4: MATERIAS_QUIZ[3], pygame.K_KP5: MATERIAS_QUIZ[4],
                }
                if ev.key in materias_por_tecla:
                    self.foco_materia = MATERIAS_QUIZ.index(materias_por_tecla[ev.key])
                    self.alternar_materia(self.materias_rects[self.foco_materia][1])
                    self.foco_confirmar = False
                elif ev.key in (pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN):
                    self.foco_confirmar = False
                    if ev.key == pygame.K_LEFT:
                        self.foco_materia = max(0, self.foco_materia - 1)
                    elif ev.key == pygame.K_RIGHT:
                        self.foco_materia = min(len(self.materias_rects) - 1, self.foco_materia + 1)
                    elif ev.key == pygame.K_UP:
                        self.foco_materia = max(0, self.foco_materia - 2)
                    else:
                        proximo = self.foco_materia + 2
                        self.foco_materia = min(len(self.materias_rects) - 1, proximo)
                elif ev.key == pygame.K_TAB:
                    self.foco_confirmar = not self.foco_confirmar
                elif ev.key == pygame.K_SPACE:
                    if self.foco_confirmar:
                        self.novo_jogo()
                    else:
                        self.alternar_materia(self.materias_rects[self.foco_materia][1])
                elif ev.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    if self.foco_confirmar:
                        self.novo_jogo()
                    else:
                        self.alternar_materia(self.materias_rects[self.foco_materia][1])
                elif ev.key == pygame.K_ESCAPE:
                    self.estado = "SELECAO_DIFICULDADE"
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                for rect, materia in self.materias_rects:
                    if rect.collidepoint(ev.pos):
                        self.foco_materia = next(i for i, (_, item) in enumerate(self.materias_rects) if item == materia)
                        self.foco_confirmar = False
                        self.alternar_materia(materia)
                        break
                else:
                    if self.botao_confirmar_rect.collidepoint(ev.pos):
                        self.foco_confirmar = True
                        self.novo_jogo()

        elif self.estado == "JOGANDO":
            if ev.type == pygame.KEYDOWN:
                if ev.key == pygame.K_SPACE:
                    if any(b.presa for b in self.bolas):
                        self.lancar()
                    elif "LASER" in self.ativos and self.cooldown_laser <= 0:
                        self.disparar_laser()
                elif ev.key in (pygame.K_p, pygame.K_ESCAPE):
                    self.estado = "PAUSA"
            elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                if any(b.presa for b in self.bolas):
                    self.lancar()
                elif "LASER" in self.ativos and self.cooldown_laser <= 0:
                    self.disparar_laser()

        elif self.estado == "QUIZ":
            q = self.quiz
            if q["escolha"] is None:
                if ev.type == pygame.KEYDOWN:
                    mapa = {pygame.K_1: 0, pygame.K_2: 1, pygame.K_3: 2, pygame.K_4: 3,
                            pygame.K_KP1: 0, pygame.K_KP2: 1, pygame.K_KP3: 2, pygame.K_KP4: 3}
                    if ev.key in mapa:
                        self.responder(mapa[ev.key])
                elif ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1:
                    for i, rect in enumerate(self.opcoes_rects):
                        if rect.collidepoint(ev.pos):
                            self.responder(i)
            elif q["fb"] < 2.0 and (
                    (ev.type == pygame.KEYDOWN and ev.key in (pygame.K_RETURN, pygame.K_SPACE, pygame.K_KP_ENTER))
                    or (ev.type == pygame.MOUSEBUTTONDOWN and ev.button == 1)):
                self.fechar_quiz()

        elif self.estado == "PAUSA":
            if ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_p, pygame.K_ESCAPE):
                    self.estado = "JOGANDO"
                elif ev.key == pygame.K_q:
                    self.finalizar()
                    self.estado = "MENU"

        elif self.estado == "FIM":
            if ev.type == pygame.KEYDOWN:
                if ev.key in (pygame.K_RETURN, pygame.K_KP_ENTER):
                    self.novo_jogo()
                elif ev.key == pygame.K_m:
                    self.estado = "MENU"
                elif ev.key == pygame.K_ESCAPE:
                    self.sair()

    def sair(self):
        salvar_recorde(max(self.recorde, carregar_recorde()))
        pygame.quit()
        sys.exit()

    # ---------------- desenho ----------------
    def desenhar_hud(self):
        t = self.tela
        pygame.draw.rect(t, (16, 16, 32), (0, 0, LARGURA, TOPO_HUD))
        pygame.draw.line(t, (70, 70, 120), (0, TOPO_HUD), (LARGURA, TOPO_HUD), 2)
        t.blit(self.f_peq_b.render(f"PONTOS  {self.pontos:06d}", True, BRANCO), (16, 8))
        t.blit(self.f_peq.render(f"RECORDE {self.recorde:06d}", True, CINZA), (210, 8))
        texto_centro(t, self.f_peq_b, f"NÍVEL {self.nivel}", (255, 220, 120), LARGURA / 2, 18)
        s = self.stats
        quiz_txt = f"QUIZ {s['acertos']}/{s['total']}"
        q = self.f_peq_b.render(quiz_txt, True, (150, 210, 255))
        t.blit(q, (LARGURA - 200 - q.get_width(), 8))
        for i in range(min(self.vidas, 9)):
            desenhar_coracao(t, LARGURA - 24 - i * 22, 18, (255, 90, 120))
        # Boosts ativos
        x = 16
        for k, resto in self.ativos.items():
            info = BOOSTS.get(k, DOWNGRADES.get(k))
            total = info["dur"]
            rotulo = self.f_mini.render(f"{info['nome']} {int(math.ceil(resto))}s", True, BRANCO)
            w = rotulo.get_width() + 14
            rect = pygame.Rect(x, 36, w, 20)
            pygame.draw.rect(t, (35, 35, 60), rect, border_radius=6)
            frac = max(0.0, min(1.0, resto / max(total, 1)))
            pygame.draw.rect(t, misturar(info["cor"], (0, 0, 0), 0.45), (x, 36, int(w * frac), 20), border_radius=6)
            pygame.draw.rect(t, info["cor"], rect, 1, border_radius=6)
            t.blit(rotulo, (x + 7, 37))
            x += w + 8

    def desenhar_jogo(self):
        t = self.tela
        t.blit(self.fundo, (0, 0))
        # Blocos
        for bl in self.blocos:
            if bl.tipo == "obstaculo":
                pygame.draw.rect(t, (105, 112, 128), bl.rect, border_radius=3)
                pygame.draw.rect(t, (185, 190, 202), bl.rect, width=2, border_radius=3)
                continue
            if bl.tipo == "bomba":
                pygame.draw.rect(t, (155, 45, 42), bl.rect, border_radius=7)
                pygame.draw.rect(t, (255, 115, 65), bl.rect, width=2, border_radius=7)
                pygame.draw.circle(t, (255, 205, 85), bl.rect.center, 7)
                pygame.draw.circle(t, (75, 35, 35), bl.rect.center, 3)
                pygame.draw.line(t, (255, 225, 150), (bl.rect.centerx + 4, bl.rect.centery - 4),
                                (bl.rect.centerx + 11, bl.rect.centery - 11), 3)
                continue
            cor = misturar(bl.cor, (210, 210, 225), 0.35 * (bl.hp - 1))
            pygame.draw.rect(t, cor, bl.rect, border_radius=3)
            pygame.draw.line(t, misturar(cor, (255, 255, 255), 0.4), bl.rect.topleft, (bl.rect.right - 1, bl.rect.top), 2)
            pygame.draw.line(t, misturar(cor, (0, 0, 0), 0.4), (bl.rect.left, bl.rect.bottom - 1), (bl.rect.right - 1, bl.rect.bottom - 1), 2)
            for k in range(bl.hp - 1):
                pygame.draw.rect(t, (40, 40, 60), bl.rect.inflate(-6 - 6 * k, -6 - 6 * k), 1, border_radius=2)
            if bl.hp < bl.hp_max:  # rachadura
                cx, cy = bl.rect.center
                pygame.draw.lines(t, (30, 30, 40), False, [(cx - 8, cy - 6), (cx - 2, cy), (cx + 3, cy - 3), (cx + 9, cy + 5)], 2)
        # Drops
        for d in self.drops:
            info = BOOSTS[d.tipo]
            rect = d.rect()
            brilho = pygame.Surface((rect.w + 16, rect.h + 16), pygame.SRCALPHA)
            a = int(60 + 40 * math.sin(d.t * 8))
            pygame.draw.rect(brilho, (*info["cor"], a), brilho.get_rect(), border_radius=18)
            t.blit(brilho, (rect.x - 8, rect.y - 8))
            desenhar_capsula(t, rect, info["cor"], info["icone"] + "?", self.f_mini)
        # Lasers
        for l in self.lasers:
            pygame.draw.rect(t, (255, 90, 90), (int(l[0] - 2), int(l[1]), 4, 12))
            pygame.draw.rect(t, (255, 220, 220), (int(l[0] - 1), int(l[1]), 2, 12))
        # Raquete
        r = self.raquete
        pr = r.rect()
        cor_r = (90, 200, 255)
        if "ENCOLHE" in self.ativos or "RAQUETE_LENTA" in self.ativos:
            cor_r = (150, 150, 160)
        if "IMA" in self.ativos:
            cor_r = BOOSTS["IMA"]["cor"]
        pygame.draw.rect(t, cor_r, pr, border_radius=8)
        pygame.draw.rect(t, misturar(cor_r, (255, 255, 255), 0.6), (pr.x + 6, pr.y + 3, pr.w - 12, 3), border_radius=2)
        if "LASER" in self.ativos:
            for dx in (-r.largura / 2 + 8, r.largura / 2 - 8):
                pygame.draw.rect(t, (255, 70, 70), (int(r.x + dx - 4), pr.y - 8, 8, 10), border_radius=2)
        # Bolas
        fogo = "FOGO" in self.ativos
        for b in self.bolas:
            for i, (x, y) in enumerate(b.rastro):
                raio = max(1, int(b.r * (i + 1) / len(b.rastro) * 0.8))
                cor = (255, 120 + i * 12, 40) if fogo else (90, 120 + i * 10, 200)
                pygame.draw.circle(t, cor, (int(x), int(y)), raio)
            if fogo:
                pygame.draw.circle(t, (255, 160, 40), (int(b.x), int(b.y)), b.r + 3)
            pygame.draw.circle(t, (255, 240, 200) if fogo else BRANCO, (int(b.x), int(b.y)), b.r)
        for p in self.particulas:
            p.draw(t)
        for tx in self.textos:
            texto_centro(t, self.f_med, tx.texto, tx.cor, tx.x, tx.y)
        if any(b.presa for b in self.bolas) and self.estado == "JOGANDO":
            if int(self.tempo * 2) % 2 == 0:
                texto_centro(t, self.f_peq, "ESPAÇO ou clique para lançar", BRANCO, LARGURA / 2, ALTURA - 90)
        self.desenhar_hud()

    def escurecer(self, alpha=170):
        s = pygame.Surface((LARGURA, ALTURA), pygame.SRCALPHA)
        s.fill((5, 5, 15, alpha))
        self.tela.blit(s, (0, 0))

    def desenhar_quiz(self):
        t, q = self.tela, self.quiz
        p, info = q["p"], BOOSTS[q["tipo"]]
        self.escurecer()
        painel = pygame.Rect(0, 0, 780, 500)
        painel.center = (LARGURA // 2, ALTURA // 2 + 10)
        pygame.draw.rect(t, (24, 24, 44), painel, border_radius=16)
        pygame.draw.rect(t, info["cor"], painel, 3, border_radius=16)
        # Cabeçalho
        cab = pygame.Rect(painel.x, painel.y, painel.w, 56)
        pygame.draw.rect(t, misturar(info["cor"], (20, 20, 40), 0.55), cab, border_top_left_radius=16, border_top_right_radius=16)
        t.blit(self.f_med.render(f"QUESTIONÁRIO  •  {p['categoria'].upper()}", True, BRANCO), (painel.x + 24, painel.y + 13))
        cap = pygame.Rect(painel.right - 90, painel.y + 16, 66, 24)
        desenhar_capsula(t, cap, info["cor"], info["icone"], self.f_mini)
        texto_centro(t, self.f_peq, f"Acerte e ganhe: {info['nome']} — {info['desc']}", info["cor"],
                     painel.centerx, painel.y + 82)
        # Enunciado
        linhas = quebrar_texto(p["enunciado"], self.f_grande, painel.w - 80)
        y = painel.y + 120
        for ln in linhas:
            texto_centro(t, self.f_grande, ln, BRANCO, painel.centerx, y + 18)
            y += 42
        # Alternativas
        self.opcoes_rects = []
        mouse = pygame.mouse.get_pos()
        y0 = painel.y + 245
        for i, op in enumerate(p["opcoes"]):
            col, lin = i % 2, i // 2
            rect = pygame.Rect(painel.x + 40 + col * 360, y0 + lin * 86, 340, 70)
            self.opcoes_rects.append(rect)
            cor_fundo, cor_borda = (40, 40, 70), (90, 90, 140)
            if q["escolha"] is None and rect.collidepoint(mouse):
                cor_fundo, cor_borda = (60, 60, 100), info["cor"]
            if q["escolha"] is not None:
                if i == p["indice_correto"]:
                    cor_fundo, cor_borda = misturar(VERDE_OK, (0, 0, 0), 0.5), VERDE_OK
                elif i == q["escolha"]:
                    cor_fundo, cor_borda = misturar(VERMELHO_ERRO, (0, 0, 0), 0.5), VERMELHO_ERRO
            pygame.draw.rect(t, cor_fundo, rect, border_radius=12)
            pygame.draw.rect(t, cor_borda, rect, 2, border_radius=12)
            pygame.draw.circle(t, cor_borda, (rect.x + 34, rect.centery), 18)
            texto_centro(t, self.f_med, str(i + 1), (15, 15, 25), rect.x + 34, rect.centery)
            s = self.f_med.render(op, True, BRANCO)
            t.blit(s, s.get_rect(midleft=(rect.x + 66, rect.centery)))
        # Tempo / feedback
        yb = painel.bottom - 50
        if q["escolha"] is None:
            frac = q["restante"] / q["tempo"]
            barra = pygame.Rect(painel.x + 40, yb, painel.w - 80, 14)
            pygame.draw.rect(t, (45, 45, 70), barra, border_radius=7)
            cor = misturar(VERMELHO_ERRO, VERDE_OK, frac)
            pygame.draw.rect(t, cor, (barra.x, barra.y, int(barra.w * frac), barra.h), border_radius=7)
            texto_centro(t, self.f_peq, f"{q['restante']:.1f}s  •  Teclas 1-4 ou clique  •  Resposta rápida = mais pontos",
                         CINZA, painel.centerx, yb + 30)
        else:
            if q["acertou"]:
                msg, cor = f"CORRETO!  +{q['bonus']} pts  •  {info['nome']} ativado", VERDE_OK
            elif q["escolha"] == -1:
                penalidade = DOWNGRADES[q["downgrade"]]
                msg, cor = f"TEMPO ESGOTADO!  Resposta: {p['resposta']}  •  {penalidade['nome']}", VERMELHO_ERRO
            else:
                penalidade = DOWNGRADES[q["downgrade"]]
                msg, cor = f"ERROU!  Resposta: {p['resposta']}  •  {penalidade['nome']} por {penalidade['dur']}s", VERMELHO_ERRO
            texto_centro(t, self.f_med, msg, cor, painel.centerx, yb + 4)
            texto_centro(t, self.f_mini, "ENTER para continuar", CINZA, painel.centerx, yb + 32)

    def desenhar_titulo(self, texto, cy):
        larg = self.f_titulo.size(texto)[0]
        x = LARGURA / 2 - larg / 2
        for i, ch in enumerate(texto):
            cor = LINHAS_ATARI[(i // 2) % 8][0] if ch != " " else BRANCO
            s = self.f_titulo.render(ch, True, cor)
            dy = math.sin(self.tempo * 3 + i * 0.4) * 4
            self.tela.blit(s, (x, cy + dy))
            x += s.get_width()

    def desenhar_menu(self):
        t = self.tela
        t.blit(self.fundo, (0, 0))
        self.desenhar_titulo("BREAKOUT GENIUS", 40)
        texto_centro(t, self.f_grande, "MATEMÁTICA + CONHECIMENTOS GERAIS", (150, 210, 255), LARGURA / 2, 140)
        texto_centro(t, self.f_peq, "Quebre os blocos, pegue as cápsulas e resolva a questão sorteada para ganhar o boost!",
                     BRANCO, LARGURA / 2, 185)
        # Boosts
        texto_centro(t, self.f_med, "BOOSTS", (255, 220, 120), LARGURA / 2, 228)
        for i, (k, info) in enumerate(BOOSTS.items()):
            col, lin = i % 2, i // 2
            x, y = 50 + col * 450, 252 + lin * 40
            desenhar_capsula(t, pygame.Rect(x, y, 48, 22), info["cor"], info["icone"], self.f_mini)
            t.blit(self.f_peq_b.render(info["nome"], True, info["cor"]), (x + 60, y))
            t.blit(self.f_peq.render(info["desc"], True, CINZA), (x + 195, y))
        # Questionários
        texto_centro(t, self.f_med, "QUESTIONÁRIOS", (255, 220, 120), LARGURA / 2, 428)
        cats = list(QUESTIONARIOS)
        texto_centro(t, self.f_peq, "  •  ".join(cats[:5]), BRANCO, LARGURA / 2, 460)
        texto_centro(t, self.f_peq, "  •  ".join(cats[5:]), BRANCO, LARGURA / 2, 486)
        texto_centro(t, self.f_peq, "Conhecimentos gerais: Geografia  •  Ciências  •  História  •  Cultura",
                 BRANCO, LARGURA / 2, 512)
        texto_centro(t, self.f_peq, "Errou ou o tempo acabou? Recebe um downgrade por 8 segundos.", VERMELHO_ERRO, LARGURA / 2, 530)
        rotulo_materias = "   •   ".join(
            f"[x] {materia}" for materia in MATERIAS_QUIZ if materia in self.materias_selecionadas
        )
        nomes_modo = {"padrao": "Padrão", "random": "Random"}
        nomes_dificuldade = {"facil": "Fácil", "normal": "Normal", "dificil": "Difícil"}
        texto_centro(t, self.f_peq_b,
                 f"MODO: {nomes_modo[self.modo_jogo]}   •   DIFICULDADE: {nomes_dificuldade[self.dificuldade]}",
                     (150, 210, 255), LARGURA / 2, 553)
        texto_centro(t, self.f_peq, f"QUIZ: {rotulo_materias}", BRANCO, LARGURA / 2, 577)
        # Controles
        texto_centro(t, self.f_peq, "← → / A D / mouse: mover   •   ESPAÇO: lançar / laser   •   1-4: responder   •   P: pausa",
                 CINZA, LARGURA / 2, 606)
        texto_centro(t, self.f_peq_b, f"RECORDE: {self.recorde}", (150, 210, 255), LARGURA / 2, 632)
        pygame.draw.rect(t, (45, 110, 175), self.botao_jogar_rect, border_radius=8)
        pygame.draw.rect(t, (150, 210, 255), self.botao_jogar_rect, width=2, border_radius=8)
        texto_centro(t, self.f_med, "JOGAR", BRANCO, self.botao_jogar_rect.centerx, self.botao_jogar_rect.centery)

    def desenhar_selecao_quiz(self):
        self.desenhar_menu()
        camada = pygame.Surface((LARGURA, ALTURA), pygame.SRCALPHA)
        camada.fill((0, 0, 0, 190))
        self.tela.blit(camada, (0, 0))
        painel = pygame.Rect(LARGURA // 2 - 320, 150, 640, 430)
        pygame.draw.rect(self.tela, (24, 24, 48), painel, border_radius=10)
        pygame.draw.rect(self.tela, (100, 140, 210), painel, width=2, border_radius=10)
        texto_centro(self.tela, self.f_med, "ESCOLHA AS MATÉRIAS", BRANCO, painel.centerx, 195)
        for i, (rect, materia) in enumerate(self.materias_rects):
            selecionada = materia in self.materias_selecionadas
            cor = (55, 115, 165) if selecionada else (45, 48, 76)
            pygame.draw.rect(self.tela, cor, rect, border_radius=6)
            focada = i == self.foco_materia and not self.foco_confirmar
            cor_borda = (255, 220, 120) if focada else ((150, 210, 255) if selecionada else (100, 105, 135))
            pygame.draw.rect(self.tela, cor_borda, rect, width=3 if focada else (2 if selecionada else 1),
                             border_radius=6)
            marca = "[x]" if selecionada else "[ ]"
            texto_centro(self.tela, self.f_peq_b, f"{marca} {materia}", BRANCO,
                         rect.centerx, rect.centery)
        pygame.draw.rect(self.tela, (45, 110, 175), self.botao_confirmar_rect, border_radius=7)
        pygame.draw.rect(self.tela, (255, 220, 120) if self.foco_confirmar else (150, 210, 255),
                 self.botao_confirmar_rect, width=3 if self.foco_confirmar else 2, border_radius=7)
        texto_centro(self.tela, self.f_peq_b, "COMEÇAR", BRANCO,
                     self.botao_confirmar_rect.centerx, self.botao_confirmar_rect.centery)
        texto_centro(self.tela, self.f_mini, "Setas navegam; Espaço/Enter marca; Tab vai a Começar; Esc volta",
                     CINZA, painel.centerx, 535)

    def desenhar_selecao_modo(self):
        self.desenhar_menu()
        camada = pygame.Surface((LARGURA, ALTURA), pygame.SRCALPHA)
        camada.fill((0, 0, 0, 190))
        self.tela.blit(camada, (0, 0))
        painel = pygame.Rect(LARGURA // 2 - 330, 205, 660, 310)
        pygame.draw.rect(self.tela, (24, 24, 48), painel, border_radius=10)
        pygame.draw.rect(self.tela, (100, 140, 210), painel, width=2, border_radius=10)
        texto_centro(self.tela, self.f_med, "ESCOLHA O MODO DE JOGO", BRANCO, painel.centerx, 255)
        descricoes = {"padrao": "Fases clássicas em sequência", "random": "Fases procedurais aleatórias"}
        for i, (rect, modo, nome) in enumerate(self.modos_jogo_rects):
            selecionado = modo == self.modo_jogo
            pygame.draw.rect(self.tela, (55, 115, 165) if selecionado else (45, 48, 76),
                             rect, border_radius=8)
            pygame.draw.rect(self.tela, (255, 220, 120) if i == self.foco_modo else (150, 210, 255),
                             rect, width=3 if i == self.foco_modo else 2, border_radius=8)
            texto_centro(self.tela, self.f_med, nome, BRANCO, rect.centerx, rect.centery - 10)
            texto_centro(self.tela, self.f_mini, descricoes[modo], CINZA, rect.centerx, rect.centery + 19)
        texto_centro(self.tela, self.f_mini, "Clique ou pressione 1/2 para escolher; Esc volta",
                     CINZA, painel.centerx, 475)

    def desenhar_selecao_dificuldade(self):
        self.desenhar_menu()
        camada = pygame.Surface((LARGURA, ALTURA), pygame.SRCALPHA)
        camada.fill((0, 0, 0, 190))
        self.tela.blit(camada, (0, 0))
        painel = pygame.Rect(LARGURA // 2 - 360, 220, 720, 280)
        pygame.draw.rect(self.tela, (24, 24, 48), painel, border_radius=10)
        pygame.draw.rect(self.tela, (100, 140, 210), painel, width=2, border_radius=10)
        texto_centro(self.tela, self.f_med, "ESCOLHA A DIFICULDADE", BRANCO, painel.centerx, 270)
        detalhes = {
            "facil": "Bola mais lenta, mais tempo",
            "normal": "Ritmo equilibrado",
            "dificil": "Bola rápida, menos tempo",
        }
        for i, (rect, dificuldade, nome) in enumerate(self.dificuldades_rects):
            selecionado = dificuldade == self.dificuldade
            pygame.draw.rect(self.tela, (55, 115, 165) if selecionado else (45, 48, 76),
                             rect, border_radius=8)
            pygame.draw.rect(self.tela, (255, 220, 120) if i == self.foco_dificuldade else (150, 210, 255),
                             rect, width=3 if i == self.foco_dificuldade else 2, border_radius=8)
            texto_centro(self.tela, self.f_peq_b, nome, BRANCO, rect.centerx, rect.centery - 8)
            texto_centro(self.tela, self.f_mini, detalhes[dificuldade], CINZA,
                         rect.centerx, rect.centery + 17)
        texto_centro(self.tela, self.f_mini, "Clique ou pressione 1/2/3 para escolher; Esc volta",
                     CINZA, painel.centerx, 455)

    def desenhar_fim(self):
        t = self.tela
        t.blit(self.fundo, (0, 0))
        texto_centro(t, self.f_titulo, "FIM DE JOGO", VERMELHO_ERRO, LARGURA / 2, 80)
        texto_centro(t, self.f_grande, f"Pontuação: {self.pontos}   •   Nível: {self.nivel}", BRANCO, LARGURA / 2, 150)
        if getattr(self, "novo_recorde", False):
            if int(self.tempo * 3) % 2 == 0:
                texto_centro(t, self.f_med, "NOVO RECORDE!", (255, 220, 120), LARGURA / 2, 192)
        else:
            texto_centro(t, self.f_peq, f"Recorde: {self.recorde}", CINZA, LARGURA / 2, 192)
        s = self.stats
        pct = (100 * s["acertos"] / s["total"]) if s["total"] else 0
        medio = (s["tempo"] / s["total"]) if s["total"] else 0
        texto_centro(t, self.f_med, "DESEMPENHO NOS QUESTIONÁRIOS", (150, 210, 255), LARGURA / 2, 240)
        texto_centro(t, self.f_peq_b, f"Respondidas: {s['total']}   •   Acertos: {s['acertos']} ({pct:.0f}%)   •   Tempo médio: {medio:.1f}s",
                     BRANCO, LARGURA / 2, 274)
        y = 310
        cats = sorted(s["por_cat"].items(), key=lambda kv: -kv[1][1])
        if not cats:
            texto_centro(t, self.f_peq, "Nenhuma cápsula coletada nesta partida.", CINZA, LARGURA / 2, y + 20)
        for nome, (ac, tot) in cats[:10]:
            t.blit(self.f_peq.render(nome, True, BRANCO), (250, y))
            barra = pygame.Rect(470, y + 4, 220, 14)
            pygame.draw.rect(t, (45, 45, 70), barra, border_radius=7)
            frac = ac / tot if tot else 0
            pygame.draw.rect(t, misturar(VERMELHO_ERRO, VERDE_OK, frac), (barra.x, barra.y, int(barra.w * frac), barra.h), border_radius=7)
            t.blit(self.f_peq_b.render(f"{ac}/{tot}", True, BRANCO), (705, y))
            y += 28
        texto_centro(t, self.f_med, "ENTER: jogar de novo   •   M: menu   •   ESC: sair", BRANCO, LARGURA / 2, ALTURA - 50)

    def desenhar(self):
        if self.estado == "MENU":
            self.desenhar_menu()
        elif self.estado == "SELECAO_MODO":
            self.desenhar_selecao_modo()
        elif self.estado == "SELECAO_DIFICULDADE":
            self.desenhar_selecao_dificuldade()
        elif self.estado == "SELECAO_QUIZ":
            self.desenhar_selecao_quiz()
        elif self.estado == "FIM":
            self.desenhar_fim()
        else:
            self.desenhar_jogo()
            if self.estado == "QUIZ":
                self.desenhar_quiz()
            elif self.estado == "PAUSA":
                self.escurecer()
                texto_centro(self.tela, self.f_titulo, "PAUSADO", BRANCO, LARGURA / 2, ALTURA / 2 - 30)
                texto_centro(self.tela, self.f_peq, "P / ESC: continuar   •   Q: encerrar partida", CINZA, LARGURA / 2, ALTURA / 2 + 30)
            elif self.estado == "NIVEL":
                self.escurecer(120)
                texto_centro(self.tela, self.f_titulo, f"NÍVEL {self.nivel} CONCLUÍDO!", (255, 220, 120), LARGURA / 2, ALTURA / 2 - 30)
                texto_centro(self.tela, self.f_med, f"Bônus de vidas: +{self.vidas * 100 * self.nivel}", BRANCO, LARGURA / 2, ALTURA / 2 + 30)
            if self.congelado > 0 and self.estado == "JOGANDO" and not any(b.presa for b in self.bolas):
                texto_centro(self.tela, self.f_grande, "Prepare-se!", BRANCO, LARGURA / 2, ALTURA / 2 + 80)

    # ---------------- loop principal ----------------
    def executar(self):
        while True:
            dt = min(self.relogio.tick(FPS) / 1000.0, 1 / 30)
            for ev in pygame.event.get():
                self.tratar_evento(ev)
            self.update(dt)
            self.desenhar()
            pygame.display.flip()


if __name__ == "__main__":
    Jogo().executar()