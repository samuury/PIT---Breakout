# Breakout Matemático

Projeto acadêmico de programação orientada a objetos: um jogo inspirado em
Breakout com perguntas de matemática e conhecimentos gerais.

## Versão principal: Godot

A versão atual é feita em Godot 4 e inicia pela cena `Main.tscn`. O jogo inclui
modos de jogo, níveis de dificuldade, blocos especiais, melhorias e penalidades,
questionários, estatísticas por matéria e recorde salvo.

### Executar

1. Instale o Godot 4.4 ou superior.
2. Importe `project.godot` no Godot, ou abra o projeto pela linha de comando:

```sh
godot --path .
```

No editor, execute o projeto com **F6** para a cena atual ou **F5** para iniciar
pela cena principal.

### Testes headless

Com o Godot disponível no `PATH`, execute o teste automatizado:

```sh
MODO=padrao DIF=normal godot --headless --path . --script tests/test_headless.gd
```

## Versão Python

`TestGame.py` contém uma versão jogável em Pygame. Para executá-la, instale
Python 3 e a dependência:

```sh
python -m pip install pygame
python TestGame.py
```

O recorde da versão Python é salvo em
`recorde_breakout_matematico.txt` no diretório do projeto.