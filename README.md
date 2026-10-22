# Turbo Thruster

Uma corrida arcade neon dentro de um túnel, inspirada em **Torus Trooper**
(Kenta Cho, 2004), com visual geométrico moderno no estilo **Geometry Wars 3**:
formas de arestas brilhantes, faíscas, estilhaços, ondas de choque e uma grade
que ondula com as explosões. Feito em **Godot 4.7** e roda em **Windows,
macOS e Linux**.

> Projeto de referência: <https://github.com/speps/tt>

## O jogo

- **Campanha com 10 setores roteirizados.** Cada setor tem de 5 a 6 **atos**
  com nome e regras próprias (escuridão, câmera girando, estroboscópio,
  tremores, zona turbo com velocidade mínima, chuva de tiros), um trecho de
  respiro com power-ups, mini-chefes de elite e, no fim, um **chefe**. Um
  setor dura de 4 a 9 minutos e cada um é mais insano que o anterior. Ao derrotá-lo, um **portal** se abre. Atravesse
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
  | **M** laranja | mísseis teleguiados por 10 s |
  | **T** azul-claro | câmera lenta no mundo por 4 s (a nave segue normal) |
  | **I** verde | ímã: atrai todos os geoms por 8 s |
  | **L** ciano | laser contínuo por 6 s |
  | **P** verde | +1 nível de arma (até 5) |
  | **+** branco | repara 1 ponto do casco |
  | **E** azul | escudo hexagonal por 10 s (absorve um golpe) |
  | **R** laranja | rajada: cadência quase dobrada por 9 s |
  | **B** rosa | +1 bomba no estoque (até 4). Solte com **Espaço**: apaga as balas e destrói o que está à frente |

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
  | Espectro | losango | azul-claro | 5 | some e reaparece; o tiro carregado o revela |
  | Divisor | cubo duplo | verde-água | 6 → 3 → 1 | divide-se em dois menores ao morrer |
  | Escudeiro | hexágono | azul | 8 | protege os inimigos próximos: mate primeiro |
  | Torre laser | torre | vermelho | 8 | avisa com uma linha fina e dispara um feixe na faixa |
  | Serpente | corrente | verde-limão | 14 (cabeça) | só a cabeça leva dano; o corpo bloqueia tiros |
  | **Anel pulsante** | anel | rosa | indestrutível | letal só no pulso: passe no intervalo |
  | **Espinho** | estrela fixa | laranja | indestrutível | campo fixo com corredores |
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

- **Chefes únicos**: Sentinela, Hidra (3 cabeças), Leviatã (galáxia), Colosso
  (placas de blindagem), Ciclone (puxa a nave), Espectro-Rei (some e solta
  clones), Quimera (muda de forma a cada 25%), Fornalha (anéis em sequência),
  Gêmeos (dois chefes) e o Coração do Toro (3 fases).
- **Mecânicas de túnel por ato**: corredor que estreita e alarga (paredes de
  energia), controles invertidos com a câmera de ponta-cabeça (Eclipse), calor
  que queima o casco se você ficar parado (Forja), escuridão, tremores e zona
  turbo.
- **Raspão e onda limpa**: passar rente às balas dá pontos (a cada 3, +1 no
  multiplicador); destruir uma onda inteira dá bônus. Três **medalhas** por
  setor: Intocável, Exterminador e Multiplicador (x50).
- **Modo Arcade**: túnel infinito, sem chefe nem portal. Cinco níveis por tempo
  (Aquecimento, Engrenando, Intenso, Brutal e Impossível, depois de 6 min),
  mini-chefe a cada 90 s, placar dos 5 melhores com iniciais estilo fliperama.
  Pela pausa dá para encerrar a partida contando os pontos.
- **Painel lateral e marcadores**: à esquerda, *PODERES* mostra a bomba (quantas
  e a tecla), o tiro carregado e o tempo dos power-ups ativos; *NA ÁREA* lista o
  que vem pela frente com ícone, nome, distância e o que fazer (ATIRE, DESVIE,
  PEGUE ou BÔNUS), com "NOVO!" na primeira aparição. Na tela, colchetes
  vermelhos marcam inimigos, losangos amarelos marcam obstáculos e cada
  power-up tem ícone e nome.
- **Naves perdidas**: cargueiros dourados e inofensivos vagam pelo túnel a cada
  20 s mais ou menos. Fogem quando atingidos e valem muitos pontos, geoms e um
  power-up.
- **HUD de cockpit** (números em display de 7 segmentos e textos em fonte de
  terminal; mapa da rota vertical na borda direita): eliminações, pontos e multiplicador, distância percorrida
  e cronômetro, ato atual com barra de progresso, velocímetro com o anel do
  tiro carregado, medidores circulares de casco e arma, retícula de mira e
  alerta de obstáculo à frente. O painel balança junto com a nave.
- **Trilha sonora própria**, toda sintetizada (sem vocais reais e sem samples),
  em três estilos escolhidos em Configurações → *Estilo de som*:
  - **Hyperdrive** (padrão): festa hardcore, de 128 a 200 BPM (hard trance,
    hardstyle, happy hardcore, rawstyle, gabber, uptempo e frenchcore), com
    supersaws, kicks afinados, builds e drops. Para gerar de novo:
    `tools/music/synth_hyper.py` e `tools/music/sfx_hyper.py`.
  - **Metal**: metal industrial/punk no estilo DOOM moderno, de 100 a
    180 BPM, com efeitos sonoros pesados. Para gerar de novo:
    `tools/music/synth_metal.py` e `tools/music/sfx_metal.py`.
  - **Clássico**: a trilha eletrônica pump/techno (`tools/music/synth.py`) e os
    efeitos originais do Torus Trooper.

## Controles

| Ação | Teclado e mouse | Controle |
| --- | --- | --- |
| Ir para os lados | A / D | analógico / D-pad |
| Acelerar (frente) / frear (trás) | W / S | analógico |
| Atirar (segurar) | botão esquerdo do mouse | A / RT |
| Anel de energia (segure ~0,5 s e solte) | botão direito do mouse | X / LT |
| Especial: bomba (até 4 em estoque) | Espaço | Y / B |
| Pausar | Esc / P | Start |
| Tela cheia | F11 | — |

Acelerar rende mais pontos. Frear deixa as balas inimigas mais lentas. O anel de
energia carrega uma esfera na ponta da nave; ao soltar, sai uma "rosquinha" de
energia que cresce pelo túnel, apaga as balas inimigas no caminho e acerta no
máximo 3 inimigos antes de se desfazer.

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
```

## Créditos

Música e efeitos sonoros originais de **Kenta Cho** (Torus Trooper), sob a
licença BSD. Veja `UPSTREAM_README.txt` e `LICENSE`.

Fontes **Audiowide**, **Rajdhani**, **Share Tech Mono** e **DSEG** sob a SIL
Open Font License (veja `assets/fonts/`).
