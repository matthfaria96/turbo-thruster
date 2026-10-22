# Turbo Thruster — Mapa de melhorias de gameplay

Objetivo: chegar a uma campanha de **10 setores** com dificuldade bem
dosada, cada setor ensinando algo novo, e depois lançar o **Modo Arcade**
(sobrevivência infinita com placar dos 5 melhores).

Situação atual (v2.0): 8 setores, 7 inimigos, 2 obstáculos indestrutíveis,
5 power-ups, chefe com 5 padrões de ataque, mapa da rota, multiplicador.

---

## 1. Princípios de design

1. **Matar ou desviar**: todo trecho mistura alvos (dão pontos e
   multiplicador) e perigos indestrutíveis (exigem leitura e movimento).
2. **Um conceito novo por setor**: o setor apresenta o conceito sozinho,
   depois o combina com o que já existe.
3. **Respiro e pico**: cada setor alterna trechos calmos (coleta de geoms,
   power-ups) e ondas intensas, terminando em pico com o chefe.
4. **Upgrades valem só no setor**: a arma e o casco recomeçam a cada setor.
   A progressão permanente fica na habilidade do jogador e nos recordes.
5. **Duração-alvo**: 2 a 3 minutos por setor, sendo o chefe cerca de 40 s.

---

## 2. Os 10 setores

| # | Nome | Novidade do setor | Inimigos/perigos principais | Chefe (padrão novo) |
|---|------|-------------------|-----------------------------|---------------------|
| 1 | Aurora | Movimento, tiro e geoms | Dardo, Enxame | **Sentinela**: leque e anel com abertura |
| 2 | Corrente | Inimigos resistentes e barra de vida | + Cata-vento, Muralha | **Hidra**: 3 cabeças destruíveis separadamente |
| 3 | Abismo | Inimigos que atiram | + Cubo, Esfera | **Leviatã**: espiral "galáxia" |
| 4 | Prisma | Obstáculos em movimento | + Varredor, Mina | **Colosso**: blindagem em placas que caem |
| 5 | Vórtice | Túnel aberto (trechos sem parede, à moda Torus Trooper) | + Couraçado | **Ciclone**: puxa a nave para o centro |
| 6 | Nebulosa | Pouca visibilidade (névoa, inimigos surgem perto) | + **Espectro**: fica invisível e reaparece | **Espectro-Rei**: clones falsos |
| 7 | Fratura | Túnel que se estreita e alarga | + **Divisor**: parte-se em 2 a cada golpe | **Quimera**: muda de forma a cada 25% de vida |
| 8 | Forja | Zonas de calor: ficar parado custa casco | + **Laser fixo**: feixes de aviso e depois disparo | **Fornalha**: anéis de fogo em sequência |
| 9 | Eclipse | Gravidade invertida em trechos (o "chão" muda de lado) | + **Escudeiro**: protege outros inimigos | **Gêmeos**: dois chefes ao mesmo tempo |
| 10 | Núcleo | Tudo combinado, ritmo máximo | Todos | **Coração do Toro**: 3 fases, mistura todos os padrões |

### Curva de dificuldade (por setor)

- **Densidade de ondas**: de 0,9 a 1,9.
- **Vida do chefe**: de 90 a 520.
- **Velocidade das balas inimigas**: +4% por setor.
- **Proporção de perigos indestrutíveis**: 10% no setor 1, 30% no setor 10.
- **Primeiro setor de cada novidade**: ela aparece sozinha nos primeiros
  20% do setor (tutorial implícito), e só depois é combinada.

---

## 3. Novos sistemas

### 3.1 Inimigos novos

| Inimigo | Forma | Regra | Contra-jogo |
|---------|-------|-------|-------------|
| Espectro | losango translúcido | some por 1,5 s e reaparece | o tiro carregado revela |
| Divisor | dodecaedro | ao levar dano, divide-se em 2 menores (até 3 gerações) | concentrar fogo |
| Escudeiro | anel hexagonal | projeta escudo nos vizinhos | matar primeiro |
| Laser fixo | torre na parede | 1 s de aviso (linha fina), depois um feixe por 1 s | sair da faixa |
| Serpente | corrente de esferas | só a cabeça leva dano, o corpo bloqueia tiros | contornar |

### 3.2 Perigos indestrutíveis novos

- **Portão duplo**: duas muralhas com aberturas em lados opostos, quase
  coladas (exige um "S").
- **Anel pulsante**: o túnel inteiro fica perigoso por 0,5 s, em ritmo
  regular; é preciso estar acelerado ou freado para passar no intervalo.
- **Campo de minas fixas**: grade indestrutível com corredores.

### 3.3 Power-ups novos

| Cápsula | Efeito |
|---------|--------|
| **M** Míssil | 6 mísseis teleguiados por 10 s |
| **T** Tempo | câmera lenta no mundo por 4 s (a nave continua normal) |
| **I** Ímã | atrai todos os geoms da tela |
| **L** Laser | troca o tiro por um feixe contínuo por 6 s |

### 3.4 Melhorias de sensação

- **Quase-acerto ("raspão")**: passar muito perto de uma bala sem ser
  atingido dá pontos e +1 de multiplicador, com faísca e som.
- **Combo de abate**: matar uma onda inteira rápido dá bônus "ONDA LIMPA".
- **Câmera reage**: zoom ao acelerar, leve inclinação nas curvas e tremor
  proporcional ao tamanho da explosão.
- **Música adaptativa**: camadas da trilha entram conforme a intensidade.
- **Feedback de dano no HUD**: a vinheta indica de que lado veio o golpe.

### 3.5 Progressão e rejogabilidade

- **Nota S/A/B/C por setor** (já existe), com **medalhas** por objetivo:
  sem dano, 100% de abates, multiplicador acima de x50.
- **Desafios diários** (fase opcional, posterior): semente fixa do dia.
- **Galeria** (o modo de depuração vira tela no menu): enciclopédia de
  inimigos que se desbloqueia ao encontrá-los.

---

## 4. Modo Arcade (planejado; ainda NÃO implementado)

No menu principal já existe o botão **"Modo Arcade · em breve"**, bloqueado.

### Ideia

Um túnel infinito: sair matando tudo até morrer ou desistir. Sem chefe
obrigatório e sem portal, só sobrevivência e pontuação.

### Regras

- **Vidas**: casco de 4. Reparos ficam mais raros com o tempo.
- **Power-ups**: os mesmos da campanha. A arma sobe e cai como nas fases.
- **Fim**: quando o casco zera, ou quando o jogador sai pelo menu de pausa.
  Sair também conta a pontuação.

### Diretor de dificuldade

A dificuldade sobe com o tempo `t` (em segundos), seguindo uma curva:

| Tempo | Sensação | O que muda |
|-------|----------|------------|
| 0:00 – 1:00 | aquecimento | só Dardos, Enxames e Cata-ventos; densidade 0,8 |
| 1:00 – 2:30 | engrenando | entram Cubos, Esferas e Muralhas; balas +10% |
| 2:30 – 4:00 | intenso | Varredores e Couraçados; um **mini-chefe** a cada 90 s |
| 4:00 – 6:00 | brutal | todos os tipos; densidade 2,0; balas +35% |
| 6:00+ | impossível | a densidade cresce sem limite (+15% a cada 30 s); ondas sobrepostas |

Fórmula base da densidade: `densidade(t) = 0,8 + 1,2 · (t / 360)^1,4`,
crescendo depois dos 6 min. A partir dos 6 min, cerca de 95% dos jogadores
devem morrer em até 60 s.

### Pontuação

- Pontos por abate × multiplicador (como na campanha).
- Bônus de sobrevivência: +100 pontos por segundo vivo, dobrando a cada minuto.
- Tempo sobrevivido aparece em destaque no HUD (cronômetro no lugar do mapa).

### Tela de fim

1. "FIM DE JOGO" com explosão da nave e câmera lenta.
2. Resumo: pontos, tempo, abates e maior multiplicador.
3. Se entrou no top 5: digitar **3 letras** (estilo fliperama, navegável
   com WASD).
4. **Placar dos 5 melhores** (pontos, iniciais, tempo, data), com a nova
   posição piscando.
5. Botões: **Jogar de novo**, **Menu principal**.

### Detalhes técnicos previstos

- `ArcadeDirector`: substitui o `WavePlan` e gera ondas por tempo, em vez
  de por distância.
- Túnel infinito: o `Track` já é analítico e o `Tunnel` já gera pedaços sob
  demanda, então basta não ter fim de fase.
- Recordes em `Save` → `arcade_top5`: lista com até 5 entradas.
- Reaproveita HUD, overlays, power-ups e efeitos sem mudanças estruturais.

---

## 5. Ordem de execução sugerida

1. **Fundação**:
   - balanceamento dos 8 setores atuais;
   - raspão;
   - "onda limpa";
   - música adaptativa.
2. **Setores 2 a 4**: chefes Hidra e Colosso com partes destrutíveis.
3. **Setores 5 e 6**: túnel aberto (Vórtice), névoa e Espectro.
4. **Setores 7 e 8**: túnel que muda de largura, Divisor, Laser fixo e
   zonas de calor.
5. **Setores 9 e 10**: gravidade invertida, Escudeiro, Gêmeos e o chefe
   final de 3 fases.
6. **Power-ups novos e medalhas**.
7. **Modo Arcade** (por último): diretor, placar top 5, entrada de iniciais
   e liberação do botão no menu.

Cada etapa termina com testes automáticos, capturas de tela e uma build
instalada para teste manual antes de seguir.
