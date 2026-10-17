# Breakout Matemático

Projeto acadêmico de programação orientada a objetos inspirado em Breakout,
com perguntas de matemática e conhecimentos gerais. Há duas implementações:
Godot, a versão principal, e uma versão alternativa em Pygame.

## Godot

Requer Godot 4.4 ou superior. A cena principal é `Main.tscn`; o jogo cria a
cena, a interface e os elementos 3D por código.

Para abrir, importe `project.godot` no Godot e pressione **F5**, ou execute na
pasta do projeto:

```sh
godot --path .
```

O jogo tem modos Padrão e Random, três dificuldades, blocos especiais, boosts,
questionários e estatísticas por matéria. Use as setas ou **A/D** para mover a
raquete; o mouse também funciona. **Espaço** ou clique lança a bola, **1-4**
respondem aos questionários e **P** pausa. As matérias do quiz são escolhidas
antes da partida.

O banco de conhecimentos gerais fica em `data/perguntas.json`. Para incluir
esse arquivo em uma exportação, adicione `*.json` aos filtros de recursos não
recurso nas configurações de exportação do Godot. O recorde da versão Godot é
salvo em `user://recorde_breakout_matematico.txt`.

### Testes

Com o executável do Godot disponível no `PATH`, rode os testes sem abrir janela:

```sh
godot --headless --path . --script res://tests/test_headless.gd
```

Os testes verificam o carregamento e a validade das perguntas, geração de
fases, limite de multibolas, progresso da partida, cápsulas, pontuação e
persistência do recorde.

### Arquivos principais

- `Main.gd`: fluxo do jogo, física, interface, boosts e recorde.
- `quiz_bank.gd`: perguntas matemáticas, banco geral e fila de revisão.
- `level_gen.gd`: geração procedural das fases.
- `data/perguntas.json`: perguntas de conhecimentos gerais.
- `tests/test_headless.gd`: testes automatizados headless.

## Pygame

`TestGame.py` é uma implementação alternativa. Requer Python 3 e Pygame:

```sh
python -m pip install pygame
python TestGame.py
```

Essa versão salva o recorde em `recorde_breakout_matematico.txt` na pasta do
projeto.