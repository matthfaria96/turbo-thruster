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
- **Mapa da rota** no canto da tela: o traçado do túnel com as curvas, o trecho
  já percorrido, os grupos de inimigos à frente, o chefe no fim e quantos
  metros faltam.
- **Power-ups durante a fase** (só valem no setor atual; cada setor recomeça
  com a arma no nível 1 e o casco cheio):

  | Cápsula | Efeito |
  | --- | --- |
  | **P** verde | +1 nível de arma (até 5) |
  | **+** branco | repara 1 ponto do casco |
  | **E** azul | escudo hexagonal por 10 s (absorve um golpe) |
  | **R** laranja | rajada: cadência quase dobrada por 9 s |
  | **B** rosa | bomba: apaga todas as balas e destrói o que está à frente |

  Levar dano tira um nível da arma.
- **Inimigos fáceis de reconhecer.** Cada tipo tem forma e cor próprias, e a
  tela de seleção de setor mostra quais aparecem em cada um:

  | Inimigo | Forma | Cor | Tiros para destruir | Comportamento |
  | --- | --- | --- | --- | --- |
  | Dardo | tetraedro | rosa | 1 | voa em grupo |
  | Enxame | estrelinhas | vermelho | 1 | chegam em espiral na sua direção |
  | Cata-vento | hélice | roxo | 3 | rápido, ziguezagueia |
  | Esfera | orbe de energia com espinhos | azul | 4 | mergulha direto em você |
  | Mina | estrela | magenta | 6 | parada no túnel, explode ao contato |
  | Cubo | cubo | laranja | 10 | para à sua frente e atira em você |
  | Couraçado | icosaedro | dourado | 28 | blindado, tiro em leque, sempre solta upgrade |
  | **Muralha** | arco listrado | amarelo | indestrutível | fecha parte do túnel: passe pela abertura |
  | **Varredor** | lâminas | vermelho-claro | indestrutível | gira pelo túnel: passe entre as lâminas |

  Inimigos resistentes mostram que estão tomando dano: dão um tranco, tremem,
  soltam faíscas e ganham uma barra de vida. Quando estão quase mortos, piscam
  e soltam fumaça de faíscas. A Muralha também bloqueia os seus tiros.

  A sua nave é **ciano** e atira rastros **amarelos**. As balas inimigas são
  estrelas de energia **laranja-avermelhadas**. A grade do túnel fica mais apagada de
  propósito, para nunca competir com a ação.
- **Nota por setor** (S/A/B/C), calculada pelos abates e pelo dano recebido.
  O recorde de cada setor fica salvo.

## Controles

| Ação | Teclado e mouse | Controle |
| --- | --- | --- |
| Ir para os lados | A / D | analógico / D-pad |
| Acelerar (frente) / frear (trás) | W / S | analógico |
| Atirar (segurar) | botão esquerdo do mouse | A / RT |
| Tiro carregado (segure e solte) | botão direito do mouse | X / LT |
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
