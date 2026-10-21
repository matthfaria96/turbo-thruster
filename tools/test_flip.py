"""Dev tool: determine if the HUD texture is uploaded upside down."""
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import numpy as np
import pygame
from OpenGL.GL import *

from turbothruster import glrender


def main():
    pygame.init()
    W, H = 64, 64
    screen = pygame.display.set_mode((W, H), pygame.OPENGL | pygame.DOUBLEBUF)
    glrender.init_gl(W, H)

    # Surface: top half red, bottom half blue.
    surf = pygame.Surface((W, H), pygame.SRCALPHA)
    surf.fill((255, 0, 0, 255), (0, 0, W, H // 2))
    surf.fill((0, 0, 255, 255), (0, H // 2, W, H // 2))

    tex = glrender.Texture2D(W, H)
    tex.upload(surf)
    glrender.set_ortho_2d(W, H)
    glClear(GL_COLOR_BUFFER_BIT)
    tex.draw(W, H)

    glReadBuffer(GL_BACK)
    data = glReadPixels(0, 0, W, H, GL_RGBA, GL_UNSIGNED_BYTE)
    arr = np.frombuffer(data, dtype=np.uint8).reshape(H, W, 4)
    # arr row 0 = framebuffer bottom (glReadPixels is bottom-up).
    bottom = arr[0, W // 2, :3]
    top = arr[H - 1, W // 2, :3]
    print("framebuffer TOP color:", tuple(top), "(expected red 255,0,0)")
    print("framebuffer BOTTOM color:", tuple(bottom), "(expected blue 0,0,255)")
    print("=>", "CORRECT" if tuple(top)[0] > 200 else "UPSIDE DOWN")


if __name__ == "__main__":
    main()
