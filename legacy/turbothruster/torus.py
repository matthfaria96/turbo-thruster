"""The deterministic torus circuit (ported from ``tunnel.d``).

A "torus" here is the whole looping track: a closed tube made of thousands of
cross-section slices.  Each slice is described by a :class:`SliceState` that
controls its radius, the width of the drivable "course" around its
circumference, and how much it bends/twists relative to the previous slice.
"""

from . import config
from .vec import Rand


class SliceState:
    """Cross-section parameters of one slice of the tunnel."""

    __slots__ = ("md1", "md2", "rad", "point_num", "course_width", "mp", "ring")

    def __init__(self):
        self.init()

    def init(self):
        self.md1 = 0.0
        self.md2 = 0.0
        self.rad = config.DEFAULT_RAD
        self.point_num = config.DEFAULT_POINT_NUM
        self.course_width = float(self.point_num)
        self.mp = 0.0
        self.ring = None

    def copy_from(self, s):
        self.md1 = s.md1
        self.md2 = s.md2
        self.rad = s.rad
        self.point_num = s.point_num
        self.course_width = s.course_width
        self.mp = s.mp
        self.ring = s.ring

    def blend(self, s1, s2, ratio):
        """self = s1 * ratio + s2 * (1 - ratio)."""
        r = 1.0 - ratio
        self.md1 = s1.md1 * ratio + s2.md1 * r
        self.md2 = s1.md2 * ratio + s2.md2 * r
        self.rad = s1.rad * ratio + s2.rad * r
        self.point_num = int(s1.point_num * ratio + s2.point_num * r)
        if s1.course_width == s1.point_num and s2.course_width == s2.point_num:
            self.course_width = float(self.point_num)
        else:
            self.course_width = s1.course_width * ratio + s2.course_width * r
        self.mp = s1.mp
        return self

    def change_deg(self, rand):
        self.md1 = rand.next_signed_float(0.005)
        self.md2 = rand.next_signed_float(0.005)

    def change_rad(self, rand):
        self.rad = config.DEFAULT_RAD + rand.next_signed_float(config.DEFAULT_RAD * 0.3)
        ppn = self.point_num
        self.point_num = int(self.rad * config.DEFAULT_POINT_NUM / config.DEFAULT_RAD)
        if ppn == self.course_width:
            self.change_width_to_full()
        else:
            self.course_width = self.course_width * self.point_num / ppn

    def change_width(self, rand):
        self.course_width = rand.next_int(self.point_num // 4) + self.point_num * 0.36

    def change_width_to_full(self):
        self.course_width = float(self.point_num)

    def change_to_straight(self):
        self.mp = 0.0

    def change_to_easy_curve(self, rand):
        self.mp = rand.next_float(0.05) + 0.04
        if rand.next_int(2) == 0:
            self.mp = -self.mp

    def change_to_tight_curve(self, rand, direction=None):
        if direction is None:
            direction = rand.next_int(2) * 2 - 1
        self.mp = (rand.next_float(0.04) + 0.1) * direction


class TorusPart:
    BLEND_DISTANCE = 64

    def __init__(self):
        self.slice_num = 0
        self.slice_state = SliceState()
        self.blended_slice_state = SliceState()
        self.slice_idx_from = 0
        self.slice_idx_to = 0

    def create(self, prev, slice_idx, sn, rand):
        self.slice_state.copy_from(prev)
        self.slice_state.change_deg(rand)
        if abs(prev.mp) >= 1.0:
            # Recovery from a very tight curve (dead branch in practice, kept
            # for faithfulness).
            if rand.next_int(2) == 0:
                if prev.mp >= 1:
                    self.slice_state.change_to_tight_curve(rand, -1)
                else:
                    self.slice_state.change_to_tight_curve(rand, 1)
            else:
                self.slice_state.change_to_straight()
        elif prev.course_width == prev.point_num or rand.next_int(2) == 0:
            r = rand.next_int(3)
            if r == 0:
                self.slice_state.change_rad(rand)
            elif r == 1:
                self.slice_state.change_width(rand)
            else:
                self.slice_state.change_width_to_full()
        else:
            r = rand.next_int(4)
            if r == 0:
                self.slice_state.change_to_tight_curve(rand)
            elif r == 2:
                self.slice_state.change_to_easy_curve(rand)
            else:
                self.slice_state.change_to_straight()
        self.slice_num = sn
        self.slice_idx_from = slice_idx
        self.slice_idx_to = slice_idx + sn

    def contains(self, idx):
        return self.slice_idx_from <= idx < self.slice_idx_to

    def create_blended_slice_state(self, blendee, idx):
        dst = idx - self.slice_idx_from
        blend_ratio = dst / self.BLEND_DISTANCE
        if blend_ratio >= 1.0:
            return self.slice_state
        self.blended_slice_state.blend(self.slice_state, blendee, blend_ratio)
        return self.blended_slice_state


class Ring:
    COLOR_RGB = [(0.5, 1.0, 0.9), (1.0, 0.9, 0.5)]

    def __init__(self, idx, ss, rtype=0):
        self.idx = idx
        self.cnt = 0
        self.rtype = rtype
        self.r = ss.rad

    def move(self):
        self.cnt += 1

    def color(self):
        return self.COLOR_RGB[self.rtype]


class Torus:
    def __init__(self):
        self.rand = Rand()
        self.parts = []
        self.rings = []
        self.slice_num = 0
        self.tp_idx = 0

    def create(self, seed):
        self.rand.set_seed(seed)
        self.tp_idx = 0
        self.parts = []
        self.slice_num = 0
        tl = config.TORUS_LENGTH
        prev = SliceState()
        while tl > 0:
            tp = TorusPart()
            lgt = 64 + self.rand.next_int(30)
            tp.create(prev, self.slice_num, lgt, self.rand)
            prev = tp.slice_state
            self.parts.append(tp)
            tl -= tp.slice_num
            self.slice_num += tp.slice_num
        # Straight, full-width course at the start/finish seam.
        self.parts[0].slice_state.init()
        self.parts[-1].slice_state.init()
        self.rings = []
        ri = 5
        while ri < self.slice_num - 100:
            ss = self.get_slice_state(ri)
            if ri == 5:
                self.rings.append(Ring(ri, ss, 1))
            else:
                self.rings.append(Ring(ri, ss))
            ri += 100 + self.rand.next_int(200)

    def get_torus_part(self, idx):
        for _ in range(len(self.parts)):
            if self.parts[self.tp_idx].contains(idx):
                break
            self.tp_idx += 1
            if self.tp_idx >= len(self.parts):
                self.tp_idx = 0
        return self.parts[self.tp_idx]

    def get_slice_state(self, idx):
        tp = self.get_torus_part(idx)
        prv_idx = self.tp_idx - 1
        if prv_idx < 0:
            prv_idx = len(self.parts) - 1
        # Return a fresh copy to avoid aliasing of the reused blend object.
        st = SliceState()
        st.copy_from(tp.create_blended_slice_state(self.parts[prv_idx].slice_state, idx))
        return st

    def get_slice_state_with_ring(self, idx, pidx):
        st = self.get_slice_state(idx)
        st.ring = None
        for r in self.rings:
            if idx > pidx:
                if r.idx <= idx and r.idx > pidx:
                    st.ring = r
                    break
            else:
                if r.idx <= idx or r.idx > pidx:
                    st.ring = r
                    break
        if st.ring is not None:
            st.ring.move()
        return st
