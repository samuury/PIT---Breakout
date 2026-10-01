# PIT - Breakout
Trabalho acadêmico de programação orientada a objetos usando pygame.

BREAKOUT MATEMÁTICO  —  Pygame
==============================
Releitura do Breakout (Atari, 1976) com questionários de matemática.

Como funciona
-------------
- Quebre os blocos com a bola, como no Breakout original.
- Alguns blocos soltam uma CÁPSULA (drop) com um boost.
- Ao pegar a cápsula com a raquete, o jogo pausa e sorteia uma questão
  de um dos 10 questionários (Aritmética, Tabuada, Divisão, Porcentagem,
  Equações, Potências e Raízes, Frações, Expressões, Sequências, Problemas).
- Acertou: ganha o boost da cápsula + pontos bônus (quanto mais rápido, mais pontos).
- Errou ou o tempo acabou: a raquete encolhe por alguns segundos.
- A dificuldade das questões e a velocidade da bola aumentam a cada nível.

Controles
---------
  ← → ou A D / mouse ...... mover a raquete
  ESPAÇO / clique ......... lançar a bola / disparar laser
  1 2 3 4 / clique ........ responder o questionário
  P ou ESC ................ pausar
  ENTER ................... iniciar / reiniciar

Requisito:  pip install pygame
Executar:   python breakout_matematico.py