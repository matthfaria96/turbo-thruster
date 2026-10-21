"""OpenGL rendering helpers (fixed-function pipeline, matching the original).

The original Torus Trooper uses fixed-function OpenGL with anti-aliased lines
(GL_LINE_SMOOTH) and additive blending for the neon glow.  This module imports
PyOpenGL's *raw* C-level functions (no error checking, no late binding) so hot
rendering loops run at full speed, and re-exports them so other modules can
``from .glrender import *``.
"""

import OpenGL

# Disable per-call GL error checking *before* importing the GL modules: the
# checkers are built at import time, and the raw C functions do not implement
# the glBegin/glEnd onBegin/onEnd protocol (calling glGetError inside a
# glBegin/glEnd block would itself be a GL_INVALID_OPERATION).  This also
# removes a large per-call overhead in hot rendering loops.
OpenGL.ERROR_CHECKING = False
OpenGL.ERROR_ON_COPY = False

import numpy as np
import pygame
from OpenGL.raw.GL.VERSION.GL_1_0 import *
from OpenGL.raw.GL.VERSION.GL_1_1 import *
from OpenGL.raw.GLU import *

TAN_HALF_FOV_V = 0.75
NEAR_PLANE = 0.1
FAR_PLANE = 1000.0


def init_gl(width, height):
    glViewport(0, 0, width, height)
    glClearColor(0.0, 0.0, 0.0, 1.0)
    glDisable(GL_DEPTH_TEST)
    glDisable(GL_CULL_FACE)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE)
    glEnable(GL_LINE_SMOOTH)
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST)
    glLineWidth(1.0)


def set_projection(width, height):
    """Perspective with a fixed vertical FOV (hor+ widescreen)."""
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    half_v = NEAR_PLANE * TAN_HALF_FOV_V
    half_h = half_v * width / max(1, height)
    glFrustum(-half_h, half_h, -half_v, half_v, NEAR_PLANE, FAR_PLANE)
    glMatrixMode(GL_MODELVIEW)


def set_modelview(eye, center, up):
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()
    gluLookAt(eye[0], eye[1], eye[2],
              center[0], center[1], center[2],
              up[0], up[1], up[2])


def set_ortho_2d(width, height):
    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()
    glOrtho(0, width, height, 0, -1, 1)
    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity()


def clear():
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)


def additive(on=True):
    glBlendFunc(GL_SRC_ALPHA, GL_ONE) if on else glBlendFunc(
        GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)


def draw_arrays(mode, verts, cols):
    """Draw a batched vertex/colour array in one call (fast path)."""
    if verts is None or len(verts) == 0:
        return
    glEnableClientState(GL_VERTEX_ARRAY)
    glEnableClientState(GL_COLOR_ARRAY)
    glVertexPointer(3, GL_FLOAT, 0, verts)
    glColorPointer(4, GL_FLOAT, 0, cols)
    glDrawArrays(mode, 0, len(verts))
    glDisableClientState(GL_COLOR_ARRAY)
    glDisableClientState(GL_VERTEX_ARRAY)


class Texture2D:
    """A cached GL texture for drawing a pygame surface as a 2D overlay."""

    def __init__(self, width, height):
        self.width = width
        self.height = height
        buf = np.zeros(1, dtype=np.uint32)
        glGenTextures(1, buf)
        self.tex = int(buf[0])
        glBindTexture(GL_TEXTURE_2D, self.tex)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0,
                     GL_RGBA, GL_UNSIGNED_BYTE, None)

    def upload(self, surface):
        data = pygame.image.tostring(surface, "RGBA", False)
        glBindTexture(GL_TEXTURE_2D, self.tex)
        glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, self.width, self.height,
                        GL_RGBA, GL_UNSIGNED_BYTE, data)

    def draw(self, width, height):
        glEnable(GL_TEXTURE_2D)
        glBindTexture(GL_TEXTURE_2D, self.tex)
        glColor4f(1.0, 1.0, 1.0, 1.0)
        glBegin(GL_QUADS)
        glTexCoord2f(0, 0)
        glVertex2f(0, 0)
        glTexCoord2f(1, 0)
        glVertex2f(width, 0)
        glTexCoord2f(1, 1)
        glVertex2f(width, height)
        glTexCoord2f(0, 1)
        glVertex2f(0, height)
        glEnd()
        glDisable(GL_TEXTURE_2D)
