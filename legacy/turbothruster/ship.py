"""The player ship (movement, shooting, camera) — ported from ``ship.d``."""

import math

import numpy as np

from . import config
from . import glrender
from .glrender import *  # noqa: F401,F403  (raw GL functions/constants)
from .vec import TWO_PI, PI, wrap_two_pi, Vector3
from .shapes import player_ship_mesh, draw_mesh

# Direction / button bit flags (mirror the original Input enum).
DIR_UP = 1
DIR_DOWN = 2
DIR_LEFT = 4
DIR_RIGHT = 8
BTN_A = 1   # shot
BTN_B = 2   # charge shot


class Ship:
    def __init__(self, tunnel):
        self.tunnel = tunnel
        self.rand = None
        self.game = None
        self.shots = None
        self.particles = None
        self.grade = config.GRADE_NORMAL

        self.pos_x = 0.0      # deg around tube
        self.pos_y = 0.0      # absolute distance along torus
        self.rel_x = 0.0      # visual deg
        self.rel_y = 0.0      # visual depth (0..RELPOS_MAX_Y)
        self.eye_x = 0.0      # smoothed eye angle
        self.bank = 0.0
        self.speed = 0.0
        self.target_speed = 0.0
        self.d1 = 0.0
        self.d2 = 0.0
        self.tunnel_ofs = 0.0
        self.cnt = 0
        self.fire_cnt = 0
        self.side_fire_cnt = 99999
        self.fire_shot_cnt = 0
        self.side_fire_shot_cnt = 0
        self.regenerative_charge = 0.0
        self.charging_shot = None
        self.is_game_over = False
        self.rank = 0
        self.boss_app_rank = 0
        self.boss_app_num = 0
        self.zone_end_rank = 0
        self.in_boss_mode = False
        self.is_boss_mode_end = False
        self.in_sight_depth = float(config.IN_SIGHT_DEPTH_DEFAULT)
        self.lap = 1
        self.screen_shake_cnt = 0
        self.screen_shake_intense = 0.0
        self.pos3 = Vector3()
        self._mesh = player_ship_mesh()
        self.upgrades = set()
        self.shields = 0
        self.lives = 3
        self.spread_timer = 0
        self.dash_cd = 0
        self.dash_timer = 0

    # ---------------------------------------------------------------- setup
    def set_game(self, game):
        self.game = game

    def set_shots(self, shots):
        self.shots = shots

    def set_particles(self, particles):
        self.particles = particles

    def set_upgrades(self, upgrades):
        self.upgrades = set(upgrades)

    def has_upgrade(self, uid):
        return uid in self.upgrades

    def start(self, grade, seed):
        self.grade = grade
        self.tunnel_ofs = 0.0
        self.pos_x = self.pos_y = 0.0
        self.rel_x = self.rel_y = 0.0
        self.eye_x = 0.0
        self.bank = 0.0
        self.speed = 0.0
        self.d1 = self.d2 = 0.0
        self.cnt = -config.INVINCIBLE_CNT
        self.fire_shot_cnt = self.side_fire_shot_cnt = 0
        self.in_sight_depth = float(config.IN_SIGHT_DEPTH_DEFAULT)
        self.rank = 0
        self.lap = 1
        self.is_game_over = False
        self.shields = 1 if self.has_upgrade("shield") else 0
        self.lives = 3
        self.spread_timer = 0
        self.dash_cd = 0
        self.dash_timer = 0
        self.restart()

    def restart(self):
        self.target_speed = 0.0
        self.fire_cnt = 0
        self.side_fire_cnt = 99999
        self.charging_shot = None
        self.regenerative_charge = 0.0

    # ---------------------------------------------------------------- move
    def move(self, dir_bits, btn_bits):
        self.cnt += 1

        if self.is_game_over:
            dir_bits = btn_bits = 0
            self.speed *= 0.9
            self.game.clear_visible_bullets()
            if self.cnt < -config.INVINCIBLE_CNT:
                self.cnt = -config.RESTART_CNT
        elif self.cnt < -config.INVINCIBLE_CNT:
            dir_bits = btn_bits = 0
            self.rel_y *= 0.99
            self.game.clear_visible_bullets()

        grade = self.grade
        as_speed = self.target_speed
        if btn_bits & BTN_B:
            as_speed *= 0.5
        else:
            acc = self.regenerative_charge * 0.1
            self.speed += acc
            as_speed += acc
            self.regenerative_charge -= acc
        if self.speed < as_speed:
            self.speed += (as_speed - self.speed) * 0.015
        else:
            if btn_bits & BTN_B:
                self.regenerative_charge -= (as_speed - self.speed) * 0.05
            self.speed += (as_speed - self.speed) * 0.05

        self.pos_y += self.speed
        self.tunnel_ofs += self.speed
        tmv = int(self.tunnel_ofs)
        self.tunnel.go_to_next_slice(tmv)
        # Dash burst + timers.
        if self.dash_timer > 0:
            self.dash_timer -= 1
            self.pos_y += 0.8
            if self.particles is not None:
                p = self.particles.get()
                if p is not None:
                    p.set((self.rel_x, self.rel_y), 0.0, 0.4, 10, 0.5, 0.8, 1.0, 3)
        if self.dash_cd > 0:
            self.dash_cd -= 1
        if self.spread_timer > 0:
            self.spread_timer -= 1
        self.game.add_score(tmv)
        self.tunnel_ofs = self.pos_y - int(self.pos_y)
        if self.pos_y >= self.tunnel.get_torus_length():
            self.pos_y -= self.tunnel.get_torus_length()
            self.lap += 1

        self.tunnel.set_ship_pos(self.rel_x, self.tunnel_ofs, self.pos_y)
        self.tunnel.set_slices()

        sp = self.tunnel.get_pos_2((self.rel_x, self.rel_y))
        self.pos3.set(sp.x, sp.y, sp.z)

        bank_max = config.BANK_MAX_DEFAULT[grade]
        if dir_bits & DIR_RIGHT:
            self.bank += (-bank_max - self.bank) * 0.1
        if dir_bits & DIR_LEFT:
            self.bank += (bank_max - self.bank) * 0.1
        over_accel = False
        if dir_bits & DIR_UP:
            if self.rel_y < config.RELPOS_MAX_Y:
                self.rel_y += config.RELPOS_Y_MOVE
            else:
                self.target_speed += config.ACCEL_RATIO[grade]
                if not (btn_bits & BTN_B) and not self.in_boss_mode and not self.is_boss_mode_end:
                    over_accel = True
        if dir_bits & DIR_DOWN and self.rel_y > 0:
            self.rel_y -= config.RELPOS_Y_MOVE
        speed_max = config.SPEED_MAX[grade] * (1.15 if self.has_upgrade("speed") else 1.0)
        acc = (self.rel_y * (speed_max - config.SPEED_DEFAULT[grade])
               / config.RELPOS_MAX_Y + config.SPEED_DEFAULT[grade])
        if over_accel:
            self.target_speed += (acc - self.target_speed) * 0.001
        elif self.target_speed < acc:
            self.target_speed += (acc - self.target_speed) * 0.005
        else:
            self.target_speed += (acc - self.target_speed) * 0.03
        self.in_sight_depth = config.IN_SIGHT_DEPTH_DEFAULT * (1 + self.rel_y / config.RELPOS_MAX_Y)
        if self.speed > speed_max:
            self.in_sight_depth += (config.IN_SIGHT_DEPTH_DEFAULT
                                    * (self.speed - speed_max)
                                    / speed_max * 3.0)
        self.bank *= 0.9
        self.pos_x += self.bank * 0.08 * (config.DEFAULT_RAD / self.tunnel.get_radius(self.rel_y))
        self.pos_x = wrap_two_pi(self.pos_x)
        self.rel_x = self.pos_x

        ox = self.rel_x - self.eye_x
        if ox > PI:
            ox -= TWO_PI
        elif ox < -PI:
            ox += TWO_PI
        self.eye_x += ox * 0.1
        self.eye_x = wrap_two_pi(self.eye_x)

        sl = self.tunnel.get_slice(self.rel_y)
        co = self.tunnel.check_in_course((self.rel_x, self.rel_y))
        if co != 0.0:
            bm = (-config.OUT_OF_COURSE_BANK * co - self.bank) * 0.075
            bm = max(-1.0, min(1.0, bm))
            self.speed *= (1 - abs(bm))
            self.bank += bm
            lo = abs(self.pos_x - sl.left_edge_deg())
            if lo > PI:
                lo = TWO_PI - lo
            ro = abs(self.pos_x - sl.right_edge_deg())
            if ro > PI:
                ro = TWO_PI - ro
            if lo > ro:
                self.pos_x = sl.right_edge_deg()
            else:
                self.pos_x = sl.left_edge_deg()
            self.rel_x = self.pos_x

        self.d1 += (sl.d1 - self.d1) * 0.05
        self.d2 += (sl.d2 - self.d2) * 0.05

        # Shooting.
        if btn_bits & BTN_B:
            if self.charging_shot is None:
                s = self.shots.get_forced() if self.shots else None
                if s is not None:
                    s.set(charge=True)
                    s.charge_rate = 1.35 if self.has_upgrade("charge") else 1.0
                    if self.has_upgrade("power"):
                        s.damage *= 2
                    self.charging_shot = s
        else:
            if self.charging_shot is not None:
                self.charging_shot.release()
                self.charging_shot = None
            if btn_bits & BTN_A:
                self._fire(False)

        if self.fire_cnt > 0:
            self.fire_cnt -= 1
        ssc = 99999
        if self.speed > config.SPEED_DEFAULT[grade] * 1.33:
            ssc = int(100000 / ((self.speed - config.SPEED_DEFAULT[grade] * 1.33) * 99999
                                / (speed_max - config.SPEED_DEFAULT[grade]) + 1))
        if self.side_fire_cnt > ssc:
            self.side_fire_cnt = ssc
        if self.side_fire_cnt > 0:
            self.side_fire_cnt -= 1

        rocket_pos = (self.rel_x - self.bank * 0.1, self.rel_y)
        if self.charging_shot is not None:
            self.charging_shot.update(rocket_pos)
        if self.cnt >= -config.INVINCIBLE_CNT and self.particles is not None:
            self._add_rocket_particles(rocket_pos)

        # Speed streaks: at high speed, points race past the ship.
        if self.speed > config.SPEED_DEFAULT[self.grade] * 1.1 \
                and self.cnt % 2 == 0 and self.particles is not None:
            p = self.particles.get()
            if p is not None:
                off = math.radians((self.cnt * 137.5) % 360)
                p.set((self.rel_x + math.cos(off) * 6.0, self.rel_y + 4.0),
                      0.0, -0.85, 8, 0.55, 0.75, 1.0, 3)

        if self.screen_shake_cnt > 0:
            self.screen_shake_cnt -= 1

    def _fire(self, charge):
        if self.fire_cnt <= 0:
            base = config.FIRE_INTERVAL
            if self.has_upgrade("cannon"):
                base = max(1, int(base * 0.7))
            self.fire_cnt = base
            s = self.shots.get() if self.shots else None
            if s is not None:
                self._spawn_shot(s, 0.0, charge)
            if self.has_upgrade("spread") or self.spread_timer > 0:
                for off in (-0.12, 0.12):
                    s2 = self.shots.get()
                    if s2 is None:
                        break
                    self._spawn_shot(s2, off, charge)

    def trigger_dash(self):
        if self.dash_cd > 0 or self.is_game_over or self.cnt < -config.INVINCIBLE_CNT:
            return
        self.dash_cd = 90
        self.dash_timer = 15
        self.game.audio.play_se("charge.wav")

    def _spawn_shot(self, s, off, charge):
        star = (self.fire_shot_cnt % config.STAR_SHELL_INTERVAL) == 0
        s.set(charge=charge, star=star)
        if self.has_upgrade("power"):
            s.damage *= 2
        gx = self.rel_x + off + config.GUNPOINT_WIDTH * ((self.fire_shot_cnt % 2) * 2 - 1)
        s.update((gx, self.rel_y))
        self.fire_shot_cnt += 1
        # Muzzle flash at the gunpoint.
        if self.particles is not None:
            p = self.particles.get()
            if p is not None:
                p.set((gx, self.rel_y + 0.4), 0.0, 0.25, 6, 1.0, 0.9, 0.6, 4)

    def _add_rocket_particles(self, pos):
        for _ in range(2):
            p = self.particles.get()
            if p is None:
                break
            p.set((pos[0], pos[1] - 0.15), PI, 0.2, 16, 0.6, 0.85, 1.0, 2)

    # ---------------------------------------------------------------- camera
    def eye_center_up(self):
        """Return (eye, center, up) world-space vectors for the camera."""
        epos_deg = self.eye_x
        ey = -1.1 + self.rel_y * 0.3
        eye = self.tunnel.get_pos_v3((epos_deg, ey, 30.0))
        cy = 4.9 + self.rel_y * 0.6
        center = self.tunnel.get_pos_v3((epos_deg, cy, 0.0))
        deg = self.eye_x
        up = (math.sin(deg), -math.cos(deg), 0.0)
        ex, ey2, ez = eye.x, eye.y, eye.z
        if self.screen_shake_cnt > 0:
            it = self.screen_shake_intense * (self.screen_shake_cnt + 6)
            ex += it * 0.5
            ey2 += it * 0.5
            ez += it * 0.5
        return (ex, ey2, ez), (center.x, center.y, center.z), up

    # ---------------------------------------------------------------- draw
    def draw_gl(self):
        if self.cnt < -config.INVINCIBLE_CNT or (self.cnt < 0 and (-self.cnt % 32) < 16):
            return
        draw_mesh(self._mesh, (self.pos3.x, self.pos3.y, self.pos3.z),
                  rz=self.pos_x - self.bank, ry=self.d1, rx=self.d2, scale=1.6)
        # Shield bubble (translucent) when protected.
        if self.shields > 0:
            self._draw_shield_gl()

    def _draw_shield_gl(self):
        glrender.additive(True)
        cx, cy, cz = self.pos3.x, self.pos3.y, self.pos3.z
        t = self.cnt * 0.08
        r = 3.6
        glColor4f(0.35, 0.7, 1.0, 0.30)
        glBegin(GL_TRIANGLE_FAN)
        glVertex3f(cx, cy, cz)
        for k in range(17):
            a = k * TWO_PI / 16
            x = cx + math.sin(a) * r
            z = cz + math.cos(a) * r
            glVertex3f(x, cy, z)
        glEnd()
        glColor4f(0.5, 0.85, 1.0, 0.8)
        glBegin(GL_LINE_LOOP)
        for k in range(16):
            a = k * TWO_PI / 16 + t
            x = cx + math.sin(a) * r
            z = cz + math.cos(a) * r
            glVertex3f(x, cy, z)
        glEnd()

    # ---------------------------------------------------------------- hit
    def check_bullet_hit(self, px, py, ppx, ppy):
        if self.cnt <= 0:
            return False
        bmvx = ppx - px
        bmvy = ppy - py
        if bmvx > PI:
            bmvx -= TWO_PI
        elif bmvx < -PI:
            bmvx += TWO_PI
        inaa = bmvx * bmvx + bmvy * bmvy
        if inaa > 0.00001:
            sofsx = self.rel_x - px
            sofsy = self.rel_y - py
            if sofsx > PI:
                sofsx -= TWO_PI
            elif sofsx < -PI:
                sofsx += TWO_PI
            inab = bmvx * sofsx + bmvy * sofsy
            if 0 <= inab <= inaa:
                hd = sofsx * sofsx + sofsy * sofsy - inab * inab / inaa
                if 0 <= hd <= config.HIT_WIDTH:
                    self.destroyed()
                    return True
        return False

    def destroyed(self):
        if self.cnt <= 0:
            return
        if self.shields > 0:
            self.shields -= 1
            for _ in range(60):
                p = self.particles.get_forced() if self.particles else None
                if p is None:
                    break
                p.set((self.rel_x, self.rel_y), 0.4, 0.4, 20, 0.4, 0.9, 1.0, 3)
            self.screen_shake_cnt = 20
            self.screen_shake_intense = 0.03
            self.game.audio.play_se("hit.wav")
            self.restart()
            self.cnt = -config.RESTART_CNT
            return
        for _ in range(160):
            p = self.particles.get_forced() if self.particles else None
            if p is None:
                break
            p.set((self.rel_x, self.rel_y), 0.5, 0.5, 32, 1.0, 0.4, 0.2, 3)
        self.lives -= 1
        if self.lives <= 0:
            self.is_game_over = True
        self.game.ship_destroyed()
        self.screen_shake_cnt = 32
        self.screen_shake_intense = 0.05
        self.restart()
        self.cnt = -config.RESTART_CNT

    def has_collision(self):
        return self.cnt >= -config.INVINCIBLE_CNT

    # ---------------------------------------------------------------- rank
    def rank_up(self, is_boss):
        if (self.in_boss_mode and not is_boss) or self.is_game_over:
            return
        if self.in_boss_mode:
            self.boss_app_num -= 1
            if self.boss_app_num <= 0:
                self.rank += 1
                self.game.goto_next_zone()
                self.in_boss_mode = False
                self.is_boss_mode_end = True
                self.boss_app_rank = 9999999
                return
        self.rank += 1
        if self.rank >= self.boss_app_rank:
            self.in_boss_mode = True

    def goto_next_zone_forced(self):
        self.boss_app_num = 0
        self.in_boss_mode = False
        self.is_boss_mode_end = True
        self.boss_app_rank = 9999999

    def start_next_zone(self):
        self.is_boss_mode_end = False

    def rank_down(self):
        if self.in_boss_mode:
            return
        self.rank -= 1

    def set_boss_app(self, rank, num, zone_end_rank):
        self.boss_app_rank = rank
        self.boss_app_num = num
        self.zone_end_rank = zone_end_rank
        self.in_boss_mode = False

    def add_score(self, sc):
        self.game.add_score(sc)

    def clear_visible_bullets(self):
        self.game.clear_visible_bullets()

    # ---------------------------------------------------------------- accessors
    def rel_pos(self):
        return (self.rel_x, self.rel_y)

    def speed_kmh(self):
        return int(self.speed * 2500)
