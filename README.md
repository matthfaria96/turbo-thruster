# Turbo Thruster

Uma recriação moderna e multiplataforma do **Torus Trooper** (Kenta Cho, 2004),
com uma **campanha** completa, **Modo Turbo** infinito e direção de arte
neon saturada. Roda nativamente em **Windows, macOS e Linux**, com **suporte
total a resoluções modernas e widescreen** (16:9, 16:10, 21:9 ultrawide, 4:3,
janela redimensionável e tela cheia).

> Baseado no projeto de referência: <https://github.com/speps/tt>

---

## O jogo

Mantém a essência arcade do original — pilote sua nave por dentro de um túnel
em forma de toro, destrua inimigos e corra contra o relógio — e adiciona um
**objetivo de conclusão** e **rejogabilidade**:

- **Campanha** com **12 setores**, cada um com tema visual próprio, inimigos
  crescentes e um **chefe exclusivo**. O último setor tem um **chefe final**.
- **Melhorias para a nave** — após concluir cada setor você escolhe uma de três
  melhorias (cadência, dano, disparo duplo, turbo, carga, escudo, cronômetro).
- **Modo Turbo** — desbloqueado ao concluir a campanha: o modo infinito
  original, frenético, só acumulando pontos, com **placar de melhores
  pontuações** persistente.
- **Menu completo** — Iniciar (campanha + Modo Turbo), Configurações e Sair.
  Tudo com progresso salvo automaticamente.

---

## Recursos

- **Jogabilidade fiel** ao original: aceleração ligada ao tempo, tiros
  automáticos, *charge shot*, inimigos pequenos/médios/chefes, pontuação e
  extensão de tempo.
- **Chefes únicos por setor** com cores, resistência e padrões de tiro próprios,
  incluindo o chefe final "Coração do Toro".
- **Corrida contínua por setor**: do início ao chefe, sem fases intermediárias;
  ao derrotar o chefe um **portal vortex** se abre e, ao cruzá-lo, fogos de
  artifício celebram a chegada antes do resultado.
- **Mapa da rota** no HUD mostrando sua posição no circuito e o portal de chegada.
- **Túnel 3D em toro** renderizado por **OpenGL acelerado por GPU**, com malha
  *wireframe* neon anti-aliased, brilho aditivo e superfície de estrada
  translúcida colorida por setor — desenhado em *vertex arrays* batched (60 fps
  com folga mesmo em 1080p).
- **Direção de arte rica**: cores saturadas, *bloom*/brilho (configurável),
  transições de *fade*, tremor de tela e partículas.
- **Áudio original** reutilizado (música OGG + efeitos WAV de Kenta Cho), com
  volume de música/efeitos ajustável.
- **Widescreen correto ("hor+")**: campo de visão vertical fixo e horizontal
  expandindo com a proporção — sem imagem esticada ou cortada.
- **Mecânicas de arcade**: 3 vidas por setor, dash (`E`), bomba (`Q`),
  combo por abates em sequência, power-ups coletáveis (vida, tempo, tiro
  triplo, pontos) e conquistas com tela dedicada no menu.
- **Configurações**: resolução, tela cheia, efeitos, volumes e brilho, com
  remapeamento completo de teclas.
- **Progresso persistente**: setores desbloqueados, melhorias, Modo Turbo e
  placar, salvos em JSON.

---

## Requisitos

- Python **3.9+** (testado no 3.12)
- `pygame-ce`, `numpy` e `PyOpenGL`

```bash
pip install -r requirements.txt
```

---

## Como jogar

| Ação                        | Tecla(s)                              |
| --------------------------- | ------------------------------------- |
| Mover (cima/baixo)          | `W` / `S` (setas também funcionam)    |
| Mover (esquerda/direita)    | `A` / `D` (setas também funcionam)    |
| Atirar (auto-fire)          | `Z`, `Ctrl`, `.`, `Espaço` ou clique esq. (segurar) |
| Charge shot                 | `X`, `Alt`, `Shift` ou clique dir. (segurar e soltar) |
| Dash (impulso)              | `E`                                   |
| Bomba (limpa balas)         | `Q` (2 por setor)                     |
| Confirmar (menus)           | `Z` / `Enter` / `Espaço`              |
| Voltar (menus)              | `Esc`                                 |
| Pausar                      | `P`                                   |
| Tela cheia / janela         | `F11`                                 |

Todas as teclas são **remapeáveis** em Configurações → aba **CONTROLES**.

**Dicas:** segure a tecla para cima para acelerar — velocidade gera tempo. O
*charge shot* atravessa inimigos, limpa balas e ainda funciona como freio
regenerativo. Na campanha, cada setor é uma corrida contínua até o chefe;
conclua para escolher uma melhoria e desbloquear o próximo. Abates em sequência
geram **combo**; colete as gemas do túnel (vida, tempo, tiro triplo, pontos).

---

## Instalação e execução

### Windows

```powershell
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python tt.py
```

### macOS

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 tt.py
```

> Se o som falhar, use `pip install pygame-ce --no-binary :all:` ou
> `brew install sdl2_mixer`.

### Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 tt.py
```

> Pode ser necessário: `sudo apt install libsdl2-2.0-0 libsdl2-mixer-2.0-0
> libogg0 libvorbis0a`.

---

## Resoluções e widescreen

- Inicia em **1280×720**, redimensionável (mínimo 640×480); `F11` alterna tela
  cheia; a resolução pode ser alterada em **Configurações**.
- Projeção **"hor+"**: em 16:9/21:9 você vê *mais* na horizontal, com o mesmo
  campo de visão vertical do 4:3 original.
- HUD ancorado aos cantos e fontes escaladas com a altura da janela.

```bash
python tt.py -fullscreen -res 3440 1440
```

---

## Linha de comando

```
python tt.py [opções]

  -res W H         tamanho da janela
  -window          iniciar em janela
  -fullscreen      iniciar em tela cheia
  -nosound         desativar som
  -brightness N    brilho 0-100
  -reverse         inverte tiro / charge shot
  -vsync 0|1       vsync (padrão 1)
```

---

## Gerando um executável

```bash
pip install pyinstaller
pyinstaller tt.spec
```

O binário sai em `dist/` (Windows `.exe`, Linux binário, macOS `.app`). O
`.github/workflows/build.yml` compila as três plataformas via GitHub Actions.

---

## Estrutura

```
tt.py                     # ponto de entrada (CLI + loop)
turbothruster/
  config.py               # constantes e opções
  campaign.py             # 12 setores + melhorias
  progress.py             # persistência (progresso/placar/configurações)
  vec.py / torus.py / tunnel.py   # 3D e geometria do túnel
  ship.py / enemy.py / entities.py / stage.py # gameplay
  shapes.py               # malhas wireframe (nave, inimigos, gemas)
  glrender.py             # render OpenGL (raw GL, vertex arrays, texturas)
  audio.py / hud.py / game.py  # som, HUD e máquina de estados
assets/sounds/            # música (.ogg) e efeitos (.wav) originais
tools/                    # utilitários de desenvolvimento
```

---

## Licença e créditos

Recreação baseada no **Torus Trooper**, de **Kenta Cho** (ABA Games, 2004).
Música e efeitos sonoros são os originais do autor. Veja [`LICENSE`](LICENSE)
para os termos (licença permissiva estilo BSD) e atribuição completa.

- Jogo original: <https://github.com/speps/tt>
- Site original: <http://www.asahi-net.or.jp/~cs8k-cyu/windows/tt_e.html>
