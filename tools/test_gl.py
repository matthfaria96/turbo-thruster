"""Dev tool: render a frame via OpenGL and dump it for visual verification."""
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import pygame

from turbothruster import config
from turbothruster import glrender
from turbothruster.glrender import *  # noqa: F401,F403  (raw GL constants)
from turbothruster.game import Game
from turbothruster.ship import DIR_UP, DIR_RIGHT, BTN_A


def main():
    pygame.init()
    g = Game(config.Options())
    g.progress.path = os.path.join(tempfile.gettempdir(), "tt_gl.json")
    W, H = 1280, 720
    screen = pygame.display.set_mode((W, H), pygame.OPENGL | pygame.DOUBLEBUF)
    glrender.init_gl(W, H)

    g.start_sector(0)
    for _ in range(90):
        g.update(DIR_UP | DIR_RIGHT, BTN_A, False)
    g.fade = 1.0
    g.draw(screen)

    def read_screen():
        glReadBuffer(GL_BACK)
        buf = np.zeros((W * H * 4,), dtype=np.uint8)
        glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE, buf)
        return buf.reshape(H, W, 4)[::-1].copy()

    arr = read_screen()
    surf = pygame.image.frombuffer(arr.tobytes(), (W, H), "RGBA")
    pygame.image.save(surf, "gl_gameplay.png")
    print("saved gl_gameplay.png  non-black%%=%.1f" %
          (100.0 * (arr[:, :, :3].sum(axis=2) > 24).mean()))

    # Also dump the menu.
    g._set_state("menu")
    g.fade = 1.0
    g.draw(screen)
    arr = read_screen()
    surf = pygame.image.frombuffer(arr.tobytes(), (W, H), "RGBA")
    pygame.image.save(surf, "gl_menu.png")
    print("saved gl_menu.png")


if __name__ == "__main__":
    main()
