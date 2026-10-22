# Turbo Thruster

Uma corrida arcade neon dentro de um túnel, inspirada em **Torus Trooper**
(Kenta Cho, 2004), com visual geométrico moderno no estilo **Geometry Wars 3**:
formas de arestas brilhantes, faíscas, estilhaços, ondas de choque e uma grade
que ondula com as explosões. Feito em **Godot 4.7** e roda em **Windows,
macOS e Linux**.

> Projeto de referência: <https://github.com/speps/tt>

## O jogo

- **Campanha com 8 setores.** Cada setor é uma corrida com ondas de inimigos
  e termina com um **chefe**. Ao derrotá-lo, um **portal** se abre. Atravesse
  o portal para que tudo exploda e o **placar do setor** apareça, com as opções
  **Próximo setor**, **Repetir** ou **Menu**.
- **Multiplicador.** Inimigos destruídos soltam pequenos losangos verdes. Passe
  perto para que sejam atraídos: cada um coletado aumenta o multiplicador de
  pontos (x1, x2, x3...). Levar dano corta o multiplicador pela metade.
- **Upgrades só valem no setor atual.** Os inimigos soltam cápsulas:
  **P verde** sobe o nível da arma (1 a 5) e **+ azul** repara o casco. Você
  começa cada setor com a arma no nível 1 e o casco cheio. Levar dano tira
  um nível da arma.
- **Inimigos fáceis de reconhecer.** Cada tipo tem forma e cor próprias, e a
  tela de seleção de setor mostra quais aparecem em cada um:

  | Inimigo | Forma | Cor | Comportamento |
  | --- | --- | --- | --- |
  | Dardo | tetraedro | rosa | voa em grupo, morre com um tiro |
  | Cata-vento | hélice | roxo | rápido, ziguezagueia |
  | Cubo | cubo | laranja | para à sua frente e atira em você |
  | Mina | estrela | magenta | parada no túnel, explode ao contato |
  | Couraçado | icosaedro | dourado | blindado, tiro em leque, sempre solta upgrade |

  A sua nave é **ciano** e atira rastros **amarelos**. As balas inimigas são
  orbes **laranja-avermelhados**. A grade do túnel fica mais apagada de
  propósito, para nunca competir com a ação.
- **Nota por setor** (S/A/B/C), calculada pelos abates e pelo dano recebido.
  O recorde de cada setor fica salvo.

## Controles

| Ação | Teclado | Controle |
| --- | --- | --- |
| Mover pelo túnel | A / D ou ← / → | analógico / D-pad |
| Acelerar / frear | W / S ou ↑ / ↓ | analógico |
| Atirar | Z / Espaço / J (ou tiro automático) | A / RT |
| Tiro carregado (segure e solte) | X / K / Shift | X / LT |
| Pausar | Esc / P | Start |
| Tela cheia | F11 | — |

Acelerar rende mais pontos. Frear deixa as balas inimigas mais lentas. O tiro
carregado atravessa os inimigos e apaga as balas no caminho.

## Configurações

Modo de tela (janela ou tela cheia), tamanho da janela, VSync, volumes,
intensidade do brilho, tremor de tela e tiro automático. A janela pode ser
redimensionada livremente: a interface se adapta a 16:9, 16:10, 21:9 e 4:3.

## Rodar a partir do código

1. Instale o [Godot 4.7](https://godotengine.org/download).
2. Abra o `project.godot` no editor e aperte **F5**, ou rode pelo terminal:

```bash
godot --path .
```

## Gerar executáveis

Instale os *export templates* do Godot 4.7 e rode:

```bash
godot --headless --export-release "Windows" build/windows/TurboThruster.exe
godot --headless --export-release "macOS"   build/macos/TurboThruster.zip
godot --headless --export-release "Linux"   build/linux/TurboThruster.x86_64
```

O workflow `.github/workflows/build.yml` faz o mesmo no GitHub Actions ao
publicar uma tag `v*`.

## Testes

```bash
godot --headless -s tests/test_logic.gd
```

Para testes visuais, o jogo aceita argumentos depois de `--`. Este exemplo
salva uma captura de tela e fecha:

```bash
godot --path . -- --screen=game --level=0 --autoplay --skip=1450 --shot=/tmp/boss.png --delay=8
```

## Estrutura

```
src/autoload/   configurações salvas, mapa de entrada e áudio
src/data/       setores e tipos de inimigo
src/game/       túnel, nave, inimigos, chefe, projéteis, efeitos e fluxo do setor
src/ui/         tema, menus, HUD e painéis
src/shaders/    túnel, brilho neon, partículas, portal e vinheta
legacy/         versão antiga em Python (apenas referência, ignorada pelo Godot)
```

## Créditos

Música e efeitos sonoros originais de **Kenta Cho** (Torus Trooper), sob a
licença BSD. Veja `UPSTREAM_README.txt` e `LICENSE`.

Fontes **Orbitron** e **Rajdhani** sob a SIL Open Font License (veja
`assets/fonts/`).
