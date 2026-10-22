"""Wireframe meshes (player ship, enemies, shots, bullets) + 3D drawing.

Uses the same model-transform convention as the original OpenGL code
(``T * Rz * Ry * Rx * v``), so a shape is oriented by ``(rz, ry, rx)`` Euler
angles around the global axes and then translated.
"""

import math

from .glrender import *  # noqa: F401,F403  (raw GL functions/constants)

from .vec import PI, TWO_PI

# Original Structure.COLOR_RGB palette.
SHAPE_COLORS = [
    (1.0, 1.0, 1.0),
    (0.6, 0.6, 0.6),
    (0.9, 0.5, 0.5),
    (0.5, 0.9, 0.5),
    (0.5, 0.5, 0.9),
    (0.7, 0.7, 0.5),
    (0.7, 0.5, 0.7),
    (0.5, 0.7, 0.7),
]


class Mesh:
    __slots__ = ("verts", "lines", "polys", "line_color", "poly_color", "poly_alpha")

    def __init__(self):
        self.verts = []      # list of (x, y, z) local space
        self.lines = []      # list of (i, j) vertex-index pairs
        self.polys = []      # list of [i, j, k, ...] vertex-index lists
        self.line_color = (1.0, 1.0, 1.0)
        self.poly_color = (0.5, 0.5, 0.5)
        self.poly_alpha = 0.5


def draw_mesh(mesh, trans, rz=0.0, ry=0.0, rx=0.0, scale=1.0):
    if not mesh.verts:
        return
    glPushMatrix()
    glTranslatef(trans[0], trans[1], trans[2])
    glRotatef(rz * 180.0 / PI, 0, 0, 1)
    glRotatef(ry * 180.0 / PI, 0, 1, 0)
    glRotatef(rx * 180.0 / PI, 1, 0, 0)
    glScalef(scale, scale, scale)
    # Filled polygons (translucent body).
    if mesh.polys:
        pc = mesh.poly_color
        glColor4f(pc[0], pc[1], pc[2], mesh.poly_alpha)
        glBegin(GL_TRIANGLES)
        for poly in mesh.polys:
            v0 = poly[0]
            for j in range(1, len(poly) - 1):
                glVertex3f(*mesh.verts[v0])
                glVertex3f(*mesh.verts[poly[j]])
                glVertex3f(*mesh.verts[poly[j + 1]])
        glEnd()
    # Wireframe lines.
    lc = mesh.line_color
    glColor4f(lc[0], lc[1], lc[2], 1.0)
    glBegin(GL_LINES)
    for i, j in mesh.lines:
        glVertex3f(*mesh.verts[i])
        glVertex3f(*mesh.verts[j])
    glEnd()
    glPopMatrix()


def make_ship_mesh(length, width, fin_count, fin_span, fin_length, color_idx):
    m = Mesh()
    r, g, b = SHAPE_COLORS[color_idx % len(SHAPE_COLORS)]
    m.line_color = (r, g, b)
    m.poly_color = (r * 0.75, g * 0.75, b * 0.75)
    m.poly_alpha = 0.6
    hz = length / 2.0
    nose = (0.0, 0.0, hz)
    tail_z = -hz
    ring = []
    for i in range(4):
        a = i * PI / 2 + PI / 4
        ring.append((math.cos(a) * width, math.sin(a) * width, tail_z))
    m.verts = [nose] + ring
    for i in range(4):
        j = (i + 1) % 4
        m.lines.append((0, 1 + i))
        m.lines.append((1 + i, 1 + j))
        m.polys.append([0, 1 + i, 1 + j])
    base = len(m.verts)
    for i in range(fin_count):
        a = (i / fin_count) * TWO_PI
        anchor = (math.cos(a) * width, math.sin(a) * width, tail_z * 0.4)
        tip = (math.cos(a) * fin_span, math.sin(a) * fin_span, -hz + fin_length)
        root = (math.cos(a) * width * 0.2, math.sin(a) * width * 0.2, tail_z * 0.6)
        m.verts += [anchor, tip, root]
        m.lines += [(base, base + 1), (base + 1, base + 2), (base + 2, base)]
        m.polys.append([base, base + 1, base + 2])
        base += 3
    return m


def player_ship_mesh():
    m = make_ship_mesh(2.2, 0.30, 2, 0.95, 0.85, 0)
    # Bright white/cyan tint for the player, so it stands out.
    m.line_color = (1.0, 1.0, 1.0)
    m.poly_color = (0.6, 0.7, 0.9)
    m.poly_alpha = 0.65
    return m


def enemy_mesh(kind, color=None):
    """kind 0 = small, 1 = middle, 2 = large/boss.  ``color`` overrides hue.

    Enemies use hostile red/orange/magenta by default and a spiky silhouette
    (more fins) so they read clearly as threats next to the white player ship.
    """
    if kind == 0:
        m = make_ship_mesh(2.4, 0.30, 5, 0.95, 0.7, 2)
    elif kind == 1:
        m = make_ship_mesh(3.3, 0.44, 6, 1.25, 1.0, 2)
    elif kind == 3:
        # Kamikaze: a finless dart that looks like a missile.
        m = make_ship_mesh(3.4, 0.24, 0, 0.0, 0.0, 2)
    else:
        m = make_ship_mesh(4.8, 0.62, 7, 1.7, 1.6, 2)
    if color is not None:
        m.line_color = (color[0], color[1], color[2])
        m.poly_color = (color[0] * 0.75, color[1] * 0.75, color[2] * 0.75)
        m.poly_alpha = 0.6
    else:
        if kind == 0:
            lc = (1.0, 0.32, 0.28)
        elif kind == 1:
            lc = (1.0, 0.5, 0.18)
        else:
            lc = (1.0, 0.28, 0.5)
        m.line_color = lc
        m.poly_color = (lc[0] * 0.75, lc[1] * 0.75, lc[2] * 0.75)
        m.poly_alpha = 0.6
    return m


def shot_mesh(charge=False):
    m = Mesh()
    m.line_color = (0.8, 1.0, 0.7)
    m.poly_color = (0.5, 0.7, 0.5)
    m.poly_alpha = 0.5
    if charge:
        L = 1.6
    else:
        L = 1.1
    nose = (0.0, 0.0, L)
    tail_z = -L
    ring = []
    for i in range(4):
        a = i * PI / 2 + PI / 4
        ring.append((math.cos(a) * 0.18, math.sin(a) * 0.18, tail_z))
    m.verts = [nose] + ring
    for i in range(4):
        j = (i + 1) % 4
        m.lines.append((0, 1 + i))
        m.lines.append((1 + i, 1 + j))
        m.polys.append([0, 1 + i, 1 + j])
    return m


def powerup_mesh():
    """A small glowing gem (octahedron) used for collectible power-ups."""
    m = Mesh()
    m.verts = [(0, 0, 1.4), (1.1, 0, 0), (0, 1.1, 0), (-1.1, 0, 0),
               (0, -1.1, 0), (0, 0, -1.4)]
    m.lines = [(0, 1), (0, 2), (0, 3), (0, 4), (5, 1), (5, 2), (5, 3), (5, 4),
               (1, 2), (2, 3), (3, 4), (4, 1)]
    m.polys = [[0, 1, 2], [0, 2, 3], [0, 3, 4], [0, 4, 1],
               [5, 1, 2], [5, 2, 3], [5, 3, 4], [5, 4, 1]]
    m.poly_alpha = 0.5
    return m


def bullet_mesh(kind=0):
    """Enemy bullet: 0 triangle, 1 square."""
    m = Mesh()
    m.line_color = (1.0, 0.7, 0.8)
    m.poly_color = (0.7, 0.4, 0.5)
    m.poly_alpha = 0.45
    if kind == 0:
        m.verts = [(0.0, 0.0, 1.2), (0.7, 0.0, -0.6), (-0.7, 0.0, -0.6),
                   (0.0, 0.7, -0.6), (0.0, -0.7, -0.6)]
        m.lines = [(0, 1), (0, 2), (0, 3), (0, 4), (1, 3), (3, 2), (2, 4), (4, 1)]
        m.polys = [[0, 1, 3], [0, 3, 2], [0, 2, 4], [0, 4, 1]]
    else:
        s = 0.7
        m.verts = [(-s, -s, s), (s, -s, s), (s, s, s), (-s, s, s),
                   (-s, -s, -s), (s, -s, -s), (s, s, -s), (-s, s, -s)]
        m.lines = [(0, 1), (1, 2), (2, 3), (3, 0),
                   (4, 5), (5, 6), (6, 7), (7, 4),
                   (0, 4), (1, 5), (2, 6), (3, 7)]
        m.polys = [[0, 1, 2, 3], [4, 5, 6, 7]]
    return m
