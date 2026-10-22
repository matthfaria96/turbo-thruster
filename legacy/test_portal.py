"""Dev tool: verify the finish portal flow (boss -> portal -> celebration)."""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame
from turbothruster import config, glrender
from turbothruster.game import Game
from turbothruster.ship import DIR_UP, BTN_A


def main():
    pygame.init()
    g = Game(config.Options())
    g.progress.path = os.path.join(tempfile.gettempdir(), "tt_portal.json")
    screen = pygame.display.set_mode((800, 450), pygame.OPENGL | pygame.DOUBLEBUF)
    glrender.init_gl(800, 450)

    g.start_sector(0)
    g.ship.shields = 999
    portal_seen = False
    crossed = False
    anim_seen = 0
    for i in range(6000):
        g.update(DIR_UP, BTN_A, False)
        if g.portal_dist > 0:
            portal_seen = True
        if g.portal_anim > 0:
            crossed = True
            anim_seen = max(anim_seen, g.portal_anim)
            if i % 4 == 0:
                g.draw(screen)
        if g.state != "play":
            break
    print("portal_seen=%s crossed=%s max_anim=%d state=%s" %
          (portal_seen, crossed, anim_seen, g.state))
    assert portal_seen and crossed, "portal flow did not trigger"


if __name__ == "__main__":
    main()
