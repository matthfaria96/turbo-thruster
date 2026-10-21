"""
Turbo Thruster — a cross-platform (Windows/macOS/Linux) recreation of
Torus Trooper by Kenta Cho, rebuilt in Python + pygame.

Faithful to the original gameplay and visual style, with modern
widescreen / multi-resolution support.
"""

import OpenGL

# Must be set before any GL module import: the error checkers are built at
# import time, and the raw C functions do not implement the glBegin/glEnd
# onBegin/onEnd protocol (calling glGetError inside a glBegin/glEnd block is
# itself a GL_INVALID_OPERATION).  Disabling also removes per-call overhead
# in hot rendering loops.
OpenGL.ERROR_CHECKING = False
OpenGL.ERROR_ON_COPY = False

__version__ = "1.0.0"
