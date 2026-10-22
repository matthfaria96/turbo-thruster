"""Dev tool: exercise the new gameplay features headless."""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame
from turbothruster import config, glrender
from turbothruster.game import Game
from turbothruster.ship import DIR_UP, DIR_RIGHT, DIR_LEFT, BTN_A, BTN_B


def main():
    pygame.init()
    g = Game(config.Options())
    g.progress.path = os.path.join(tempfile.gettempdir(), "tt_feat.json")
    screen = pygame.display.set_mode((1280, 720), pygame.OPENGL | pygame.DOUBLEBUF)
    glrender.init_gl(1280, 720)

    g.start_sector(0)
    g.ship.shields = 999  # survive so we can observe power-ups/combo
    pu_seen = 0
    for i in range(3000):
        d = DIR_UP | (DIR_RIGHT if (i // 60) % 2 == 0 else DIR_LEFT)
        g.update(d, BTN_A, False)
        pu_seen = max(pu_seen, sum(1 for p in g.powerups.items if p.exists))
        if i % 300 == 0:
            g.draw(screen)
    print("state=%s lives=%d combo=%d bombs=%d powerups_seen=%d score=%d" %
          (g.state, g.ship.lives, g.combo, g.bombs, pu_seen, g.score))

    # Test bomb + dash.
    g.trigger_bomb()
    g.ship.trigger_dash()
    print("after bomb/dash: bombs=%d dash_cd=%d dash_timer=%d" %
          (g.bombs, g.ship.dash_cd, g.ship.dash_timer))


if __name__ == "__main__":
    main()
