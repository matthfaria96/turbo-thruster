"""HUD rendering (score, time, speed, lives, bosses, gauges, map).

The HUD is anchored to the screen edges/corners and its font sizes scale with
window height, so it stays correct on any resolution or aspect ratio.
"""

import math

from . import config
from .vec import TWO_PI, PI


class HudFonts:
    def __init__(self):
        self._cache = {}

    def get(self, pygame, size):
        if size not in self._cache:
            self._cache[size] = pygame.font.Font(None, size)
        return self._cache[size]


def _text(surface, pygame, fonts, txt, size, x, y, color=(255, 255, 255),
          anchor="topleft", glow=True):
    font = fonts.get(pygame, int(size))
    img = font.render(txt, True, color)
    rect = img.get_rect()
    setattr(rect, anchor, (int(x), int(y)))
    if glow:
        shadow = font.render(txt, True, (0, 0, 0))
        surface.blit(shadow, (rect.x + 1, rect.y + 1))
    surface.blit(img, rect)
    return rect


def _panel(surface, pygame, x, y, w, h, alpha=95):
    panel = pygame.Surface((int(w), int(h)), pygame.SRCALPHA)
    panel.fill((8, 14, 28, alpha))
    pygame.draw.rect(panel, (70, 100, 150, 210), panel.get_rect(), 1, border_radius=8)
    surface.blit(panel, (int(x), int(y)))


def _bar(surface, pygame, x, y, w, h, ratio, fill=(120, 220, 255)):
    ratio = max(0.0, min(1.0, ratio))
    pygame.draw.rect(surface, (30, 38, 50), (int(x), int(y), int(w), int(h)))
    if ratio > 0:
        pygame.draw.rect(surface, fill, (int(x), int(y), int(w * ratio), int(h)))
    pygame.draw.rect(surface, (150, 170, 195), (int(x), int(y), int(w), int(h)), 1)


def _draw_diamond(surface, pygame, color, x, y, r):
    pts = [(x, y - r), (x + r, y), (x, y + r), (x - r, y)]
    col = tuple(int(c * 255) for c in color)
    pygame.draw.polygon(surface, col, pts)
    pygame.draw.polygon(surface, (255, 255, 255), pts, 1)


def _draw_triangle(surface, pygame, color, x, y, r):
    pts = [(x, y - r), (x + r, y + r), (x - r, y + r)]
    col = tuple(int(c * 255) for c in color)
    pygame.draw.polygon(surface, col, pts)
    pygame.draw.polygon(surface, (255, 255, 255), pts, 1)


def _heart(surface, pygame, x, y, r, color=(255, 95, 105)):
    pygame.draw.circle(surface, color, (int(x - r * 0.55), int(y - r * 0.4)), int(r * 0.55))
    pygame.draw.circle(surface, color, (int(x + r * 0.55), int(y - r * 0.4)), int(r * 0.55))
    pygame.draw.polygon(surface, color, [
        (int(x - r), int(y - r * 0.3)), (int(x + r), int(y - r * 0.3)),
        (int(x), int(y + r * 0.85))])


def _bomb_icon(surface, pygame, x, y, r, color=(255, 220, 120)):
    pygame.draw.circle(surface, color, (int(x), int(y)), int(r))
    pygame.draw.circle(surface, (60, 40, 10), (int(x), int(y)), int(r * 0.3))
    pygame.draw.line(surface, color, (int(x + r * 0.4), int(y - r)),
                     (int(x + r * 0.9), int(y - r * 1.5)), 2)
    pygame.draw.circle(surface, (255, 200, 90), (int(x + r * 1.05), int(y - r * 1.6)),
                       int(r * 0.3))


def draw_hud(surface, pygame, fonts, game, ship, opts):
    w, h = surface.get_size()
    s = h / 480.0  # HUD scale factor

    # --- Top-left panel: time, lives, bombs, legend ---
    tl_x, tl_y, tl_w, tl_h = 6 * s, 6 * s, 372 * s, 152 * s
    _panel(surface, pygame, tl_x, tl_y, tl_w, tl_h)

    time_ms = game.time
    secs = max(0, time_ms // 1000)
    txt = "%d:%02d" % (secs // 60, secs % 60)
    _text(surface, pygame, fonts, "TIME", 11 * s, tl_x + 10 * s, tl_y + 8 * s,
          color=(150, 190, 220))
    _text(surface, pygame, fonts, txt, 24 * s, tl_x + 56 * s, tl_y + 4 * s)

    if game.time_changed_show_cnt >= 0 and (game.time_changed_show_cnt % 64) > 32:
        _text(surface, pygame, fonts, game.time_changed_msg, 13 * s,
              tl_x + 160 * s, tl_y + 12 * s, color=(255, 255, 120))

    _text(surface, pygame, fonts, "VIDAS", 11 * s, tl_x + 10 * s, tl_y + 36 * s,
          color=(150, 190, 220))
    for i in range(max(0, ship.lives)):
        _heart(surface, pygame, tl_x + 62 * s + i * 24 * s, tl_y + 46 * s, 8 * s)

    _text(surface, pygame, fonts, "BOMBAS", 11 * s, tl_x + 150 * s, tl_y + 36 * s,
          color=(150, 190, 220))
    for i in range(max(0, game.bombs)):
        _bomb_icon(surface, pygame, tl_x + 222 * s + i * 26 * s, tl_y + 45 * s, 6 * s)

    # Legend: power-ups + enemies.
    ly = tl_y + 64 * s
    _text(surface, pygame, fonts, "POWER-UPS", 10 * s, tl_x + 10 * s, ly,
          color=(140, 150, 165), glow=False)
    pws = [((0.4, 1.0, 0.5), "VIDA"), ((1.0, 0.9, 0.3), "TEMPO"),
           ((0.3, 0.9, 1.0), "TIRO"), ((1.0, 0.4, 1.0), "PTS")]
    for i, (c, label) in enumerate(pws):
        x = tl_x + 12 * s + i * 88 * s
        _draw_diamond(surface, pygame, c, x, ly + 13 * s, 6 * s)
        _text(surface, pygame, fonts, label, 10 * s, x + 11 * s, ly + 9 * s,
              color=(160, 170, 180), glow=False)
    ly2 = ly + 28 * s
    _text(surface, pygame, fonts, "INIMIGOS", 10 * s, tl_x + 10 * s, ly2,
          color=(140, 150, 165), glow=False)
    _draw_triangle(surface, pygame, (1.0, 0.35, 0.3), tl_x + 26 * s, ly2 + 14 * s, 8 * s)
    _text(surface, pygame, fonts, "INIMIGO", 10 * s, tl_x + 40 * s, ly2 + 9 * s,
          color=(160, 170, 180), glow=False)
    _draw_triangle(surface, pygame, (1.0, 0.3, 0.55), tl_x + 150 * s, ly2 + 12 * s, 11 * s)
    _text(surface, pygame, fonts, "CHEFE", 10 * s, tl_x + 166 * s, ly2 + 9 * s,
          color=(160, 170, 180), glow=False)

    # --- Top-center: sector name, boss bar, combo ---
    if getattr(game, "mode", "campaign") == "campaign":
        from . import campaign
        sec = campaign.SECTORS[game.sector]
        colr = tuple(int(c * 255) for c in sec.line)
        _text(surface, pygame, fonts, sec.name, 18 * s, w / 2, 10 * s,
              anchor="midtop", color=colr)

    boss = None
    for e in game.enemies.items:
        if e.exists and e.spec.is_boss:
            boss = e
            break
    if boss is not None:
        ratio = boss.spec.shield / max(1, boss.max_shield)
        bw = 380 * s
        bh = 12 * s
        bx = (w - bw) / 2
        by = 40 * s
        label = "CHEFE FINAL" if boss.spec.final else "CHEFE"
        _text(surface, pygame, fonts, label, 13 * s, bx, by - 18 * s,
              color=(255, 120, 120))
        _bar(surface, pygame, bx, by, bw, bh, ratio, (255, 90, 90))

    if game.combo >= 2:
        _text(surface, pygame, fonts, "COMBO x%d" % game.combo, 16 * s, w / 2, 62 * s,
              anchor="midtop", color=(255, 200, 80))

    # --- Top-right: score panel ---
    score_txt = str(game.score)
    tr_x, tr_y, tr_w, tr_h = w - 170 * s, 6 * s, 164 * s, 52 * s
    _panel(surface, pygame, tr_x, tr_y, tr_w, tr_h)
    _text(surface, pygame, fonts, score_txt, 24 * s, tr_x + 10 * s, tr_y + 6 * s)
    _text(surface, pygame, fonts, "/", 13 * s, tr_x + 104 * s, tr_y + 18 * s)
    _text(surface, pygame, fonts, str(max(0, game.next_extend - game.score)),
          13 * s, tr_x + 116 * s, tr_y + 18 * s, color=(140, 190, 230))

    # --- Bottom-center: speed panel ---
    kmh = ship.speed_kmh()
    sp_txt = str(kmh)
    spd_ratio = min(1.0, ship.speed / 1.6)
    bc_w, bc_h = 150 * s, 72 * s
    bc_x, bc_y = (w - bc_w) / 2, h - 84 * s
    _panel(surface, pygame, bc_x, bc_y, bc_w, bc_h)
    _text(surface, pygame, fonts, sp_txt, 30 * s, w / 2, bc_y + 4 * s, anchor="midtop")
    _text(surface, pygame, fonts, "KM/H", 12 * s, w / 2, bc_y + 38 * s, anchor="midtop",
          color=(150, 190, 220))
    _bar(surface, pygame, bc_x + 20 * s, bc_y + 54 * s, bc_w - 40 * s, 5 * s, spd_ratio,
         (120, 255, 150))

    # --- Charge gauge (above the speed panel) ---
    if ship.charging_shot is not None and ship.charging_shot.in_charge:
        lvl = min(1.0, ship.charging_shot.charge_cnt / config.MAX_CHARGE)
        bw = 170 * s
        bh = 8 * s
        bx = (w - bw) / 2
        by = h - 98 * s
        _text(surface, pygame, fonts, "CARGA", 12 * s, bx, by - 16 * s,
              color=(150, 255, 170))
        _bar(surface, pygame, bx, by, bw, bh, lvl, (120, 255, 150))

    # --- Bottom-left: sector/rank panel ---
    bl_x, bl_y, bl_w, bl_h = 6 * s, h - 84 * s, 150 * s, 78 * s
    _panel(surface, pygame, bl_x, bl_y, bl_w, bl_h)
    if getattr(game, "mode", "campaign") == "campaign":
        _text(surface, pygame, fonts, "SETOR %d" % (game.sector + 1), 15 * s,
              bl_x + 10 * s, bl_y + 8 * s)
    else:
        _text(surface, pygame, fonts, "NIVEL %d" % int(game.level), 15 * s,
              bl_x + 10 * s, bl_y + 8 * s)
    _text(surface, pygame, fonts, "RANK", 11 * s, bl_x + 10 * s, bl_y + 34 * s,
          color=(150, 190, 220))
    _text(surface, pygame, fonts, "%d/%d" % (ship.rank, max(0, ship.zone_end_rank)),
          15 * s, bl_x + 58 * s, bl_y + 30 * s)
    if ship.shields > 0:
        _text(surface, pygame, fonts, "ESCUDO x%d" % ship.shields, 12 * s,
              bl_x + 10 * s, bl_y + 58 * s, color=(120, 220, 255))

    # --- Zone progress bar (bottom edge) ---
    if ship.zone_end_rank > 0:
        ratio = min(1.0, ship.rank / ship.zone_end_rank)
        bw = w * 0.5
        bh = 4 * s
        bx = (w - bw) / 2
        by = h - 5 * s
        _bar(surface, pygame, bx, by, bw, bh, ratio, (150, 210, 255))

    # --- Control hint (subtle, bottom edge) ---
    _text(surface, pygame, fonts,
          "WASD mover   Clique esq: atirar   Clique dir: carga   E: dash   Q: bomba",
          11 * s, w / 2, h - 3 * s, anchor="midbottom", color=(95, 108, 120),
          glow=False)

    # --- Map (bottom-right): the closed route with the player position ---
    if getattr(game, "mode", "campaign") == "campaign":
        length = max(1, game.tunnel.get_torus_length())
        mx = w - 62 * s
        my = h - 62 * s
        r = 36 * s
        pygame.draw.circle(surface, (8, 14, 28, 150), (int(mx), int(my)), int(r + 5))
        pygame.draw.circle(surface, (70, 100, 150, 230), (int(mx), int(my)), int(r + 5), 1)
        pygame.draw.circle(surface, (24, 32, 54), (int(mx), int(my)), int(r))
        # Start marker (top of the loop).
        pygame.draw.circle(surface, (90, 115, 160), (int(mx), int(my - r)), 2)
        # Player position.
        ang = (ship.pos_y % length) / length * TWO_PI - PI / 2
        pr = r - 8 * s
        px = mx + math.cos(ang) * pr
        py = my + math.sin(ang) * pr
        pygame.draw.circle(surface, (255, 255, 255), (int(px), int(py)), 4)
        pygame.draw.circle(surface, (0, 0, 0), (int(px), int(py)), 4, 1)
        # Finish portal marker when active.
        if game.portal_dist >= 0 or game.portal_anim > 0:
            pang = ((ship.pos_y + max(0.0, game.portal_dist)) % length) / length * TWO_PI - PI / 2
            pygame.draw.circle(surface, (255, 90, 200),
                               (int(mx + math.cos(pang) * pr), int(my + math.sin(pang) * pr)), 5)
        _text(surface, pygame, fonts, "ROTA", 10 * s, mx, my - r - 16 * s,
              anchor="center", color=(140, 150, 165), glow=False)

    # --- Center messages ---
    if game.ach_timer > 0:
        _text(surface, pygame, fonts, game.ach_msg, 20 * s, w / 2, h * 0.30,
              anchor="center", color=(255, 210, 90))
    if game.boss_warn > 0 and (game.boss_warn % 40) > 20:
        _text(surface, pygame, fonts, "ALERTA: CHEFE!", 34 * s, w / 2, h * 0.22,
              anchor="center", color=(255, 90, 90))
    if game.pickup_timer > 0:
        _text(surface, pygame, fonts, game.pickup_msg, 22 * s, w / 2, h * 0.16,
              anchor="center", color=(150, 255, 180))
    if game.portal_anim > 0:
        _text(surface, pygame, fonts, "CHEGADA!", 46 * s, w / 2, h * 0.34,
              anchor="center", color=(255, 220, 120))
    if ship.is_game_over:
        _text(surface, pygame, fonts, "GAME OVER", 40 * s, w / 2, h / 2 - 30 * s,
              anchor="center")
    elif game.pause_cnt > 0 and (game.pause_cnt % 64) < 32:
        _text(surface, pygame, fonts, "PAUSE", 32 * s, w / 2, h / 2, anchor="center")

    # Keyboard focus warning (window must be clicked before keys respond).
    if not pygame.key.get_focused():
        _text(surface, pygame, fonts, "CLIQUE NA JANELA PARA ATIVAR O TECLADO", 20 * s,
              w / 2, h * 0.44, anchor="center", color=(255, 170, 90))
