"""Dev tool: exercise Turbo (infinite) mode end-to-end."""
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
    g.progress.path = os.path.join(tempfile.gettempdir(), "tt_turbo.json")
    screen = pygame.display.set_mode((800, 450), pygame.OPENGL | pygame.DOUBLEBUF)
    glrender.init_gl(800, 450)

    g.start_turbo()
    g.ship.shields = 999
    for i in range(3000):
        g.update(DIR_UP, BTN_A, False)
        if i % 300 == 0:
            g.draw(screen)
    print("mode=%s state=%s score=%d level=%.1f" %
          (g.mode, g.state, g.score, g.level))

    # Force game over and check the leaderboard flow.
    g.ship.lives = 0
    g.time = 0
    for i in range(200):
        g.update(0, BTN_A, False)
        if g.state != "play":
            break
    print("after gameover state=%s leaderboard_len=%d" %
          (g.state, len(g.progress.get_leaderboard())))


if __name__ == "__main__":
    main()
