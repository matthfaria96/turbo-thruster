"""The tunnel: slice geometry and position math.

Ported from the original ``tunnel.d``.  The tunnel is a closed tube made of
``DEPTH_NUM`` slices placed ahead of the ship; each slice is a ring of points
whose radius / course-width / bend are taken from the torus circuit.

Rendering goes through fixed-function OpenGL (see ``glrender``): the tube
surface is drawn as translucent quads plus neon wireframe lines, batched into
vertex arrays so the GPU gets everything in a few draw calls.
"""

import math

import numpy as np
from .glrender import *  # noqa: F401,F403  (raw GL functions/constants)

from . import config
from . import glrender
from .vec import Vector3, TWO_PI
from .torus import SliceState


class Slice:
    __slots__ = ("state", "d1", "d2", "center_pos", "point_from", "depth",
                 "point_ratio")

    def __init__(self):
        self.state = SliceState()
        self.d1 = 0.0
        self.d2 = 0.0
        self.center_pos = Vector3()
        self.point_from = 0.0
        self.depth = 0.0
        self.point_ratio = 1.0

    def set_first(self, pf, state, dpt):
        self.center_pos.set(0.0, 0.0, 0.0)
        self.d1 = self.d2 = 0.0
        self.point_from = pf
        self.state.copy_from(state)
        self.depth = dpt
        self.point_ratio = 1.0

    def set_next(self, prev, state, depth_ratio, dpt):
        self.d1 = prev.d1 + state.md1 * depth_ratio
        self.d2 = prev.d2 + state.md2 * depth_ratio
        cp = self.center_pos.set(0.0, 0.0, config.SLICE_DEPTH * depth_ratio)
        cp.rollY(self.d1).rollX(self.d2)
        cp.iadd(prev.center_pos)
        self.point_ratio = 1.0 + (abs(depth_ratio) - 1.0) * 0.02
        self.point_from = prev.point_from + state.mp * depth_ratio
        self.point_from %= state.point_num
        if self.point_from < 0:
            self.point_from += state.point_num
        self.state.copy_from(state)
        self.depth = dpt

    def is_nearly_round(self):
        return self.state.course_width >= self.state.point_num - 1

    def left_edge_deg(self):
        return self.point_from * TWO_PI / self.state.point_num

    def right_edge_deg(self):
        rd = (self.point_from + self.state.course_width) * TWO_PI / self.state.point_num
        if rd >= TWO_PI:
            rd -= TWO_PI
        return rd


class Tunnel:
    def __init__(self):
        self.slices = [Slice() for _ in range(config.DEPTH_NUM)]
        self.torus = None
        self.torus_idx = 0
        self.point_from = 0.0
        self.ship_deg = 0.0
        self.ship_ofs = 0.0
        self.ship_y = 0.0
        self.ship_idx = config.SHIP_IDX_OFS
        self.sight_depth = 0.0
        self._tmp = Vector3()
        # Per-frame ring point cache.
        self.points = np.zeros((config.DEPTH_NUM, config.MAX_POINT_NUM, 3))
        self.npts = [config.DEFAULT_POINT_NUM] * config.DEPTH_NUM

    # ------------------------------------------------------------------ setup
    def start(self, torus):
        self.torus = torus
        self.torus_idx = 0
        self.point_from = 0.0
        self.sight_depth = 0.0

    def set_ship_pos(self, d, o, y):
        self.ship_deg = d
        self.ship_ofs = o
        self.ship_y = y
        self.ship_idx = config.SHIP_IDX_OFS

    def set_slices(self):
        ti = float(self.torus_idx)
        sight_depth = 0.0
        dr = 1.0
        first = self.slices[0]
        first.set_first(self.point_from, self.torus.get_slice_state(self.torus_idx),
                        -self.ship_idx - self.ship_ofs)
        for i in range(1, config.DEPTH_NUM):
            pti = int(ti)
            ti += dr
            sight_depth += dr
            if ti >= self.torus.slice_num:
                ti -= self.torus.slice_num
            self.slices[i].set_next(
                self.slices[i - 1],
                self.torus.get_slice_state_with_ring(int(ti), pti),
                dr,
                sight_depth - self.ship_idx - self.ship_ofs,
            )
            if i >= config.DEPTH_NUM // 2 and dr < config.DEPTH_RATIO_MAX:
                dr *= config.DEPTH_CHANGE_RATIO
        self.sight_depth = sight_depth
        self.compute_ring_points()

    def go_to_next_slice(self, n):
        if n <= 0:
            return
        self.torus_idx += n
        for i in range(n):
            sl = self.slices[i].state
            self.point_from += sl.mp
            self.point_from %= sl.point_num
            if self.point_from < 0:
                self.point_from += sl.point_num
        if self.torus_idx >= self.torus.slice_num:
            self.torus_idx -= self.torus.slice_num
            self.point_from = 0.0

    def compute_ring_points(self):
        pts = self.points
        npts = self.npts
        rad_ratio = config.RAD_RATIO
        for i in range(config.DEPTH_NUM):
            st = self.slices[i].state
            n = st.point_num
            npts[i] = n
            ang = np.arange(n, dtype=np.float64) * (TWO_PI / (n - 1))
            ca = np.cos(ang)
            sa = np.sin(ang)
            # rollZ(ang): (0, r, 0) -> (-r sin a, r cos a, 0)
            r = st.rad * rad_ratio
            x = -r * sa
            y = r * ca
            z = np.zeros(n)
            # rollY(d1)
            d1 = self.slices[i].d1
            c1 = math.cos(d1)
            s1 = math.sin(d1)
            x2 = x * c1 - z * s1
            z2 = x * s1 + z * c1
            # rollX(d2)
            d2 = self.slices[i].d2
            c2 = math.cos(d2)
            s2 = math.sin(d2)
            y3 = y * c2 - z2 * s2
            z3 = y * s2 + z2 * c2
            cp = self.slices[i].center_pos
            pts[i, :n, 0] = x2 + cp.x
            pts[i, :n, 1] = y3 + cp.y
            pts[i, :n, 2] = z3 + cp.z

    # ------------------------------------------------------------ GL render
    def draw_gl(self, line_rgb, poly_rgb, dark_line_ratio):
        n_slices = config.DEPTH_NUM
        lr, lg, lb = line_rgb
        pr, pg, pb = poly_rgb

        # Per-slice brightness (i runs far -> near).
        line_bn = [0.0] * n_slices
        poly_bn = [0.0] * n_slices
        light_bn = [0.0] * n_slices
        _l, _p, _lt = 0.4, 0.0, 0.5 - dark_line_ratio * 0.2
        for i in range(n_slices - 1, -1, -1):
            line_bn[i], poly_bn[i], light_bn[i] = _l, _p, _lt
            _l *= 1.02
            if _l > 1:
                _l = 1
            _lt *= 1.02
            if _lt > 1:
                _lt = 1
            if i < n_slices // 2:
                if _p <= 0:
                    _p = 0.2
                _p *= 1.03
                if _p > 1:
                    _p = 1
            if i < n_slices * 0.75:
                _l *= 1.0 - dark_line_ratio * 0.05
                _lt *= 1.0 + dark_line_ratio * 0.02
            _l = min(1.0, max(0.0, _l))
            _lt = min(1.0, max(0.0, _lt))

        pts = self.points

        # Decorative rings.
        glrender.additive(True)
        for ring in self.torus.rings:
            rel = ring.idx - self.torus_idx
            if rel < 0:
                rel += self.torus.slice_num
            if 0 <= rel <= self.sight_depth + 20:
                self._draw_ring_gl(ring)

        # Road surface (translucent, normal alpha blending) — batched quads.
        glrender.additive(False)
        quad_parts = []
        quad_col_parts = []
        for i in range(n_slices - 1, 0, -1):
            if poly_bn[i] <= 0.28:
                continue
            prv = i - 1
            st = self.slices[i].state
            n = st.point_num
            prv_n = self.npts[prv]
            ridx = self._road_indices(i)
            if len(ridx) < 2:
                continue
            if len(ridx) > 3:
                ridx = ridx[::2]
            ra = np.asarray(ridx, dtype=np.float64)
            a_idx = ra[:-1].astype(np.int64) % n
            b_idx = ra[1:].astype(np.int64) % n
            pa_idx = (ra[:-1] * prv_n / n).astype(np.int64) % prv_n
            pb_idx = (ra[1:] * prv_n / n).astype(np.int64) % prv_n
            k = len(a_idx)
            quads = np.empty((k * 4, 3), dtype=np.float32)
            quads[0::4] = pts[i][a_idx]
            quads[1::4] = pts[i][b_idx]
            quads[2::4] = pts[prv][pa_idx]
            quads[3::4] = pts[prv][pb_idx]
            cols = np.empty((k * 4, 4), dtype=np.float32)
            cols[:] = (pr, pg, pb, poly_bn[i])
            quad_parts.append(quads)
            quad_col_parts.append(cols)

        # Wireframe + seam + edge lights — batched lines and points.
        line_parts = []
        line_col_parts = []
        point_parts = []
        point_col_parts = []
        for i in range(n_slices - 1, 0, -1):
            prv = i - 1
            st = self.slices[i].state
            n = st.point_num
            prv_n = self.npts[prv]
            ridx = self._road_indices(i)
            if not ridx:
                continue
            ra = np.asarray(ridx, dtype=np.float64)
            b_idx = ra[1:].astype(np.int64) % n
            pa_idx = (ra[:-1] * prv_n / n).astype(np.int64) % prv_n
            pb_idx = (ra[1:] * prv_n / n).astype(np.int64) % prv_n
            k = len(b_idx)
            seg = np.empty((k * 4, 3), dtype=np.float32)
            seg[0::4] = pts[i][b_idx]
            seg[1::4] = pts[prv][pb_idx]
            seg[2::4] = pts[prv][pb_idx]
            seg[3::4] = pts[prv][pa_idx]
            cols = np.empty((k * 4, 4), dtype=np.float32)
            cols[:] = (lr * line_bn[i], lg * line_bn[i], lb * line_bn[i], 1.0)
            line_parts.append(seg)
            line_col_parts.append(cols)

            if st.course_width < n:
                pf = self.slices[i].point_from
                p0 = int(pf) % n
                p1 = int(pf * prv_n / n) % prv_n
                seam = np.asarray([pts[i][p0], pts[prv][p1]], dtype=np.float32)
                seam_c = np.empty((2, 4), dtype=np.float32)
                seam_c[:] = (line_bn[i] * 0.66, line_bn[i] * 0.66, line_bn[i], 1.0)
                line_parts.append(seam)
                line_col_parts.append(seam_c)
                if light_bn[i] > 0.2:
                    le = int(pf) % n
                    re = int(pf + st.course_width) % n
                    lp = np.asarray([pts[i][le], pts[i][re]], dtype=np.float32)
                    lc = np.empty((2, 4), dtype=np.float32)
                    lc[:] = (light_bn[i], light_bn[i], 0.6 * light_bn[i], 1.0)
                    point_parts.append(lp)
                    point_col_parts.append(lc)

        if quad_parts:
            glrender.draw_arrays(GL_QUADS, np.concatenate(quad_parts),
                                 np.concatenate(quad_col_parts))
        if line_parts:
            glrender.draw_arrays(GL_LINES, np.concatenate(line_parts),
                                 np.concatenate(line_col_parts))
        if point_parts:
            glPointSize(4.0)
            glrender.draw_arrays(GL_POINTS, np.concatenate(point_parts),
                                 np.concatenate(point_col_parts))

    def _draw_ring_gl(self, ring):
        si, o = self.calc_index(float(ring.idx) - self.torus_idx + self.ship_idx + self.ship_ofs)
        if si < 0 or si >= config.DEPTH_NUM - 1:
            return
        sl = self.slices[si]
        ns = self.slices[si + 1]
        d1 = sl.d1 * (1 - o) + ns.d1 * o
        d2 = sl.d2 * (1 - o) + ns.d2 * o
        cx = sl.center_pos.x * (1 - o) + ns.center_pos.x * o
        cy = sl.center_pos.y * (1 - o) + ns.center_pos.y * o
        cz = sl.center_pos.z * (1 - o) + ns.center_pos.z * o
        cr, cg, cb = ring.color()
        glColor4f(cr, cg, cb, 1.0)
        glBegin(GL_LINE_LOOP)
        n = 16
        for k in range(n):
            a = k * TWO_PI / n + ring.cnt * 0.05
            p = Vector3(math.sin(a) * ring.r * 1.2, math.cos(a) * ring.r * 1.2, 0)
            p.rollY(d1).rollX(d2)
            glVertex3f(p.x + cx, p.y + cy, p.z + cz)
        glEnd()

    # ---------------------------------------------------------------- position
    def calc_index(self, z):
        """Find the slice index/offset for a forward depth ``z``."""
        idx = config.DEPTH_NUM + 99999
        ofs = 0.0
        for i in range(1, config.DEPTH_NUM):
            if z < self.slices[i].depth:
                idx = i - 1
                ofs = (z - self.slices[idx].depth) / (self.slices[idx + 1].depth - self.slices[idx].depth)
                break
        if idx < 0:
            idx = 0
            ofs = 0.0
        elif idx >= config.DEPTH_NUM - 1:
            idx = config.DEPTH_NUM - 2
            ofs = 0.99
        if ofs < 0 or (ofs != ofs):
            ofs = 0.0
        elif ofs >= 1.0:
            ofs = 0.99
        return idx, ofs

    def get_pos(self, d, o, si, rr):
        nsi = si + 1
        sl = self.slices[si]
        ns = self.slices[nsi]
        r = sl.state.rad * (1 - o) + ns.state.rad * o
        d1 = sl.d1 * (1 - o) + ns.d1 * o
        d2 = sl.d2 * (1 - o) + ns.d2 * o
        t = Vector3(0.0, r * rr, 0.0)
        t.rollZ(d).rollY(d1).rollX(d2)
        t.x += sl.center_pos.x * (1 - o) + ns.center_pos.x * o
        t.y += sl.center_pos.y * (1 - o) + ns.center_pos.y * o
        t.z += sl.center_pos.z * (1 - o) + ns.center_pos.z * o
        return t

    def get_pos_v3(self, p):
        """``p`` is (deg, depth, radius_offset)."""
        si, o = self.calc_index(p[1])
        rr = config.RAD_RATIO - p[2] / self.slices[si].state.rad
        return self.get_pos(p[0], o, si, rr)

    def get_pos_2(self, p):
        """``p`` is (deg, depth); radius factor 1.0."""
        si, o = self.calc_index(p[1])
        return self.get_pos(p[0], o, si, 1.0)

    def get_radius(self, z):
        si, o = self.calc_index(z)
        return (self.slices[si].state.rad * (1 - o)
                + self.slices[si + 1].state.rad * o)

    def get_torus_length(self):
        return self.torus.slice_num

    def get_slice(self, y):
        si, o = self.calc_index(y)
        return self.slices[si]

    # ---------------------------------------------------------------- course
    @staticmethod
    def check_deg_inside(d, ld, rd):
        rsl = 0
        if rd <= ld:
            if rd < d < ld:
                if d < (rd + ld) / 2:
                    rsl = 1
                else:
                    rsl = -1
        else:
            if d < ld or d > rd:
                cd = (ld + rd) / 2 + math.pi
                if cd >= TWO_PI:
                    cd -= TWO_PI
                if cd >= math.pi:
                    if d < cd and d > rd:
                        rsl = 1
                    else:
                        rsl = -1
                else:
                    if d > cd and d < ld:
                        rsl = -1
                    else:
                        rsl = 1
        return rsl

    def check_in_course(self, p):
        sl = self.get_slice(p[1])
        if sl.is_nearly_round():
            return 0.0
        ld = sl.left_edge_deg()
        rd = sl.right_edge_deg()
        rsl = self.check_deg_inside(p[0], ld, rd)
        if rsl == 0:
            return 0.0
        rad = sl.state.rad
        if rsl == 1:
            ofs = p[0] - rd
        else:
            ofs = ld - p[0]
        if ofs >= TWO_PI:
            ofs -= TWO_PI
        elif ofs < 0:
            ofs += TWO_PI
        return ofs * rad * rsl


    # ------------------------------------------------------ road indices
    def _road_indices(self, i):
        """Float road-point indices (``pi``) of slice ``i`` in order."""
        st = self.slices[i].state
        n = st.point_num
        width = st.course_width
        ratio = self.slices[i].point_ratio
        pi = self.slices[i].point_from
        out = []
        while width > 0:
            out.append(pi)
            pi += ratio
            while pi >= n:
                pi -= n
            width -= ratio
        return out


