"""Vector math, deterministic RNG and small math helpers.

The rotation conventions (``rollX`` / ``rollY`` / ``rollZ``) are ported
verbatim from the original Torus Trooper source (``src/abagames/util/vector.d``)
so that the tunnel geometry reproduces the original look.
"""

import math
import random

PI = math.pi
TWO_PI = 2.0 * math.pi
HALF_PI = math.pi * 0.5


def clamp(v, lo, hi):
    return lo if v < lo else (hi if v > hi else v)


def wrap_two_pi(a):
    """Wrap an angle into ``[0, 2*pi)``."""
    a = a % TWO_PI
    if a < 0:
        a += TWO_PI
    return a


class Vector2:
    __slots__ = ("x", "y")

    def __init__(self, x=0.0, y=0.0):
        self.x = float(x)
        self.y = float(y)

    def set(self, x, y):
        self.x = float(x)
        self.y = float(y)
        return self

    def copy(self):
        return Vector2(self.x, self.y)

    def __repr__(self):
        return "Vector2(%r, %r)" % (self.x, self.y)


class Vector3:
    __slots__ = ("x", "y", "z")

    def __init__(self, x=0.0, y=0.0, z=0.0):
        self.x = float(x)
        self.y = float(y)
        self.z = float(z)

    def set(self, x, y, z):
        self.x = float(x)
        self.y = float(y)
        self.z = float(z)
        return self

    def copy(self):
        return Vector3(self.x, self.y, self.z)

    def blend(self, v1, v2, ratio):
        """self = v1 * ratio + v2 * (1 - ratio)."""
        r = 1.0 - ratio
        self.x = v1.x * ratio + v2.x * r
        self.y = v1.y * ratio + v2.y * r
        self.z = v1.z * ratio + v2.z * r
        return self

    def rollX(self, d):
        c = math.cos(d)
        s = math.sin(d)
        y = self.y * c - self.z * s
        z = self.y * s + self.z * c
        self.y = y
        self.z = z
        return self

    def rollY(self, d):
        c = math.cos(d)
        s = math.sin(d)
        x = self.x * c - self.z * s
        z = self.x * s + self.z * c
        self.x = x
        self.z = z
        return self

    def rollZ(self, d):
        c = math.cos(d)
        s = math.sin(d)
        x = self.x * c - self.y * s
        y = self.x * s + self.y * c
        self.x = x
        self.y = y
        return self

    def __add__(self, o):
        if isinstance(o, Vector3):
            return Vector3(self.x + o.x, self.y + o.y, self.z + o.z)
        return Vector3(self.x + o, self.y + o, self.z + o)

    def __sub__(self, o):
        if isinstance(o, Vector3):
            return Vector3(self.x - o.x, self.y - o.y, self.z - o.z)
        return Vector3(self.x - o, self.y - o, self.z - o)

    def __mul__(self, o):
        return Vector3(self.x * o, self.y * o, self.z * o)

    __rmul__ = __mul__

    def __truediv__(self, o):
        return Vector3(self.x / o, self.y / o, self.z / o)

    def iadd(self, o):
        if isinstance(o, Vector3):
            self.x += o.x
            self.y += o.y
            self.z += o.z
        else:
            self.x += o
            self.y += o
            self.z += o
        return self

    def imul(self, o):
        self.x *= o
        self.y *= o
        self.z *= o
        return self

    def as_tuple(self):
        return (self.x, self.y, self.z)

    def __repr__(self):
        return "Vector3(%r, %r, %r)" % (self.x, self.y, self.z)


def dot(a, b):
    return a.x * b.x + a.y * b.y + a.z * b.z


def cross(a, b):
    return Vector3(
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x,
    )


def normalize(v):
    ln = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    if ln > 0:
        return Vector3(v.x / ln, v.y / ln, v.z / ln)
    return Vector3()


class Rand:
    """Seeded RNG with the same method names the original uses."""

    def __init__(self, seed=0):
        self._r = random.Random(seed)

    def set_seed(self, s):
        self._r.seed(s)

    def next_int(self, n):
        return self._r.randrange(n)

    def next_int32(self):
        return self._r.getrandbits(32)

    def next_float(self, f=1.0):
        return self._r.random() * f

    def next_signed_float(self, f=1.0):
        return (self._r.random() * 2.0 - 1.0) * f
