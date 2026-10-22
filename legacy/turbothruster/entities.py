"""Gameplay entities: particles, player shots, and enemy bullets."""

import math

from .glrender import *  # noqa: F401,F403  (raw GL functions/constants)

from . import config
from . import glrender
from .vec import wrap_two_pi, TWO_PI
from .shapes import shot_mesh, bullet_mesh, powerup_mesh, draw_mesh

POWERUP_COLORS = {
    "life": (0.4, 1.0, 0.5),
    "spread": (0.3, 0.9, 1.0),
    "time": (1.0, 0.9, 0.3),
    "score": (1.0, 0.4, 1.0),
}


class Particle:
    __slots__ = ("deg", "depth", "vx", "vy", "life", "max_life",
                 "color", "size", "exists")

    def __init__(self):
        self.exists = False
        self.color = (1.0, 1.0, 1.0)
        self.size = 2
        self.deg = 0.0
        self.depth = 0.0
        self.vx = 0.0
        self.vy = 0.0
        self.life = 0
        self.max_life = 1

    def set(self, pos, vx, vy, life, r, g, b, size):
        self.deg = pos[0]
        self.depth = pos[1]
        self.vx = vx
        self.vy = vy
        self.life = int(life)
        self.max_life = int(life)
        self.color = (r, g, b)
        self.size = size
        self.exists = True

    def move(self):
        self.deg += self.vx
        self.depth += self.vy
        self.life -= 1
        if self.life <= 0:
            self.exists = False


class ParticlePool:
    def __init__(self, n):
        self.items = [Particle() for _ in range(n)]
        self.rand = None  # set later

    def get(self):
        for p in self.items:
            if not p.exists:
                return p
        return None

    def get_forced(self):
        # Reuse the oldest (lowest life) particle.
        return min(self.items, key=lambda p: p.life)

    def clear(self):
        for p in self.items:
            p.exists = False

    def move(self):
        for p in self.items:
            if p.exists:
                p.move()

    def draw_gl(self, tunnel):
        active = []
        for p in self.items:
            if not p.exists:
                continue
            if p.depth < -3 or p.depth > 200:
                continue
            w = tunnel.get_pos_2((p.deg, p.depth))
            active.append((p, w))
        if not active:
            return
        glrender.additive(True)
        # Glow pass (large, dim).
        glPointSize(6.0)
        glBegin(GL_POINTS)
        for p, w in active:
            fade = p.life / max(1, p.max_life)
            r, g, b = p.color
            glColor4f(r * fade * 0.4, g * fade * 0.4, b * fade * 0.4, fade * 0.4)
            glVertex3f(w.x, w.y, w.z)
        glEnd()
        # Core pass (small, bright).
        glPointSize(3.0)
        glBegin(GL_POINTS)
        for p, w in active:
            fade = p.life / max(1, p.max_life)
            r, g, b = p.color
            glColor4f(r * fade, g * fade, b * fade, fade)
            glVertex3f(w.x, w.y, w.z)
        glEnd()


class Shot:
    __slots__ = ("pos_x", "pos_y", "deg", "charge", "in_charge", "charge_cnt",
                 "range", "size", "trg_size", "damage", "multiplier",
                 "star_shell", "cnt", "charge_rate", "exists")

    def __init__(self):
        self.exists = False
        self.pos_x = 0.0
        self.pos_y = 0.0
        self.deg = 0.0
        self.cnt = 0
        self.charge_rate = 1.0

    def set(self, charge=False, star=False, d=0.0):
        self.cnt = 0
        self.multiplier = 1
        self.charge_rate = 1.0
        if charge:
            self.charge = self.in_charge = True
            self.range = 0.0
            self.charge_cnt = 0
            self.size = self.trg_size = 0.0
            self.damage = 100
            self.star_shell = False
            self.deg = d
        else:
            self.charge = self.in_charge = False
            self.range = float(config.IN_SIGHT_DEPTH_DEFAULT)
            self.charge_cnt = 0
            self.size = self.trg_size = 1.0
            self.damage = 1
            self.star_shell = star
            self.deg = d
        self.exists = True

    def update(self, p):
        self.pos_x = p[0]
        self.pos_y = p[1] + 0.3

    def release(self):
        if self.charge_cnt < config.MAX_CHARGE * config.CHARGE_RELEASE_RATIO:
            self.exists = False
            return
        self.in_charge = False
        self.range = config.SHOT_RANGE_MIN + self.charge_cnt * config.SHOT_RANGE_RATIO
        self.trg_size = config.SHOT_SIZE_MIN + self.charge_cnt * config.SHOT_SIZE_RATIO

    def move(self):
        if self.in_charge:
            if self.charge_cnt < config.MAX_CHARGE:
                self.charge_cnt += self.charge_rate
                self.trg_size = (config.SHOT_SIZE_MIN + self.charge_cnt * config.SHOT_SIZE_RATIO) * 0.33
        else:
            self.pos_x += math.sin(self.deg) * config.SHOT_SPEED
            self.pos_y += math.cos(self.deg) * config.SHOT_SPEED
            self.range -= config.SHOT_SPEED
            if self.range <= 0:
                self.exists = False
            elif self.range < 10:
                self.trg_size *= 0.75
        self.size += (self.trg_size - self.size) * 0.1
        self.cnt += 1

    def draw_gl(self, tunnel):
        w = tunnel.get_pos_2((self.pos_x, self.pos_y))
        mesh = shot_mesh(self.charge)
        draw_mesh(mesh, (w.x, w.y, w.z),
                  rz=self.deg + self.cnt * 0.12, ry=0.0, rx=0.0, scale=self.size)


class ShotPool:
    def __init__(self, n):
        self.items = [Shot() for _ in range(n)]

    def get(self):
        for s in self.items:
            if not s.exists:
                return s
        return None

    def get_forced(self):
        return min(self.items, key=lambda s: s.cnt)

    def clear(self):
        for s in self.items:
            s.exists = False

    def move(self):
        for s in self.items:
            if s.exists:
                s.move()

    def draw_gl(self, tunnel):
        for s in self.items:
            if s.exists:
                s.draw_gl(tunnel)


class Bullet:
    __slots__ = ("pos_x", "pos_y", "ppx", "ppy", "vx", "vy", "life", "size",
                 "kind", "exists")

    def __init__(self):
        self.exists = False
        self.pos_x = 0.0
        self.pos_y = 0.0
        self.ppx = 0.0
        self.ppy = 0.0
        self.vx = 0.0
        self.vy = 0.0
        self.kind = 0

    def set(self, px, py, vx, vy, life=300, size=1.0, kind=0):
        self.pos_x = self.ppx = px
        self.pos_y = self.ppy = py
        self.vx = vx
        self.vy = vy
        self.life = life
        self.size = size
        self.kind = kind
        self.exists = True

    def move(self):
        self.ppx = self.pos_x
        self.ppy = self.pos_y
        self.pos_x = wrap_two_pi(self.pos_x + self.vx)
        self.pos_y += self.vy
        self.life -= 1
        if self.life <= 0 or self.pos_y < -4 or self.pos_y > 300:
            self.exists = False

    def draw_gl(self, tunnel):
        w = tunnel.get_pos_2((self.pos_x, self.pos_y))
        mesh = bullet_mesh(self.kind)
        draw_mesh(mesh, (w.x, w.y, w.z), rz=0.0, ry=0.0, rx=0.0, scale=self.size)


class BulletPool:
    def __init__(self, n):
        self.items = [Bullet() for _ in range(n)]

    def get(self):
        for b in self.items:
            if not b.exists:
                return b
        return None

    def clear(self):
        for b in self.items:
            b.exists = False

    def clear_visible(self):
        for b in self.items:
            if b.exists and b.pos_y > -2:
                b.exists = False

    def move(self):
        for b in self.items:
            if b.exists:
                b.move()

    def draw_gl(self, tunnel):
        for b in self.items:
            if b.exists:
                b.draw_gl(tunnel)


class PowerUp:
    __slots__ = ("pos_x", "pos_y", "type", "exists", "cnt")

    def __init__(self):
        self.exists = False
        self.pos_x = 0.0
        self.pos_y = 0.0
        self.type = "score"
        self.cnt = 0

    def set(self, px, py, ptype):
        self.pos_x = px
        self.pos_y = py
        self.type = ptype
        self.cnt = 0
        self.exists = True

    def move(self):
        self.cnt += 1
        self.pos_y -= 0.22  # drift toward the player
        if self.pos_y < -5:
            self.exists = False

    def draw_gl(self, tunnel):
        w = tunnel.get_pos_2((self.pos_x, self.pos_y))
        c = POWERUP_COLORS.get(self.type, (1.0, 1.0, 1.0))
        mesh = powerup_mesh()
        mesh.line_color = c
        mesh.poly_color = (c[0] * 0.6, c[1] * 0.6, c[2] * 0.6)
        draw_mesh(mesh, (w.x, w.y, w.z), rz=self.cnt * 0.06, rx=self.cnt * 0.04,
                  scale=1.3)


class PowerUpPool:
    def __init__(self, n):
        self.items = [PowerUp() for _ in range(n)]

    def get(self):
        for p in self.items:
            if not p.exists:
                return p
        return None

    def clear(self):
        for p in self.items:
            p.exists = False

    def move(self):
        for p in self.items:
            if p.exists:
                p.move()

    def draw_gl(self, tunnel):
        for p in self.items:
            if p.exists:
                p.draw_gl(tunnel)
