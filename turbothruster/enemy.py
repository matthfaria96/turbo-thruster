"""Enemies and their specifications — ported from ``enemy.d`` / ``stagemanager.d``.

BulletML is replaced by a few direct firing patterns (straight / aimed /
spread), which preserves the feel while keeping the code portable and small.
"""

import math

from . import config
from .vec import PI, TWO_PI, wrap_two_pi
from .shapes import enemy_mesh, draw_mesh

DISAP_DEPTH = -5.0


class ShipSpec:
    def __init__(self):
        self.shield = 1
        self.base_speed = 0.1
        self.ship_speed_ratio = 0.3
        self.bank_max = 0.5
        self.base_bank = 0.0
        self.score = 100
        self.kind = 0            # 0 small, 1 middle, 2 large
        self.aim_ship = False
        self.has_limit_y = False
        self.is_boss = False
        self.mesh_color = None   # (r,g,b) override for unique bosses
        self.final = False       # final boss (bigger + more score)
        self.kamikaze = False    # fast rammer that never shoots
        # Simplified barrage.
        self.fire_interval = 999999
        self.fire_timer = 0
        self.bullet_kind = 0
        self.aimed = False
        self.spread = 0
        self.bullet_size = 1.0
        self.bullet_speed = 0.5

    def create_small(self, rand, level, grade):
        self.shield = 3
        self.base_speed = 0.05 + rand.next_float(0.1)
        self.ship_speed_ratio = 0.25 + rand.next_float(0.25)
        self.bank_max = 0.3 + rand.next_float(0.7)
        self.base_bank = (0.1 + rand.next_float(0.2)) if rand.next_int(3) == 0 else 0.0
        self.score = 100
        self.kind = 0
        self.aim_ship = False
        self.has_limit_y = False
        self.is_boss = False
        self._fire(rand, level, grade, 160.0, 1, 80, 1.0, 0.45)

    def create_middle(self, rand, level):
        self.shield = 8
        self.base_speed = 0.1 + rand.next_float(0.1)
        self.ship_speed_ratio = 0.4 + rand.next_float(0.4)
        self.bank_max = 0.2 + rand.next_float(0.5)
        self.base_bank = (0.05 + rand.next_float(0.1)) if rand.next_int(4) == 0 else 0.0
        self.score = 500
        self.kind = 1
        self.aim_ship = True
        self.has_limit_y = False
        self.is_boss = False
        self._fire(rand, level, 0, 120.0, 2, 60, 1.2, 0.55)

    def create_boss(self, rand, level, speed, middle_boss, theme=None):
        if theme is not None:
            self.shield = int(theme.get("shield", 30))
            self.ship_speed_ratio = theme.get("speed", speed)
            self.mesh_color = theme.get("color")
            self.final = bool(theme.get("final", False))
            bits = int(theme.get("bits", 2))
            fire_mul = theme.get("fire", 1.0)
        else:
            self.shield = 30
            self.ship_speed_ratio = speed
            self.mesh_color = None
            self.final = False
            bits = 2
            fire_mul = 1.0
        self.base_speed = 0.1 + rand.next_float(0.1)
        self.bank_max = 0.8 + rand.next_float(0.4)
        self.base_bank = 0.0
        self.score = 5000 if self.final else 2000
        self.kind = 2
        self.aim_ship = True
        self.has_limit_y = True
        self.is_boss = True
        self._fire(rand, level, 0, 90.0, 3, 40, 1.5, 0.6,
                   spread_n=bits, fire_mul=fire_mul)

    def create_kamikaze(self, rand, level, grade):
        """Fast rammer: dives at the ship, never shoots, worth a lot of points."""
        self.shield = 4
        self.base_speed = 0.3 + rand.next_float(0.2)
        self.ship_speed_ratio = 0.6 + rand.next_float(0.2)
        self.bank_max = 0.6
        self.base_bank = 0.0
        self.score = 150
        self.kind = 3
        self.aim_ship = True
        self.has_limit_y = False
        self.is_boss = False
        self.kamikaze = True
        self.mesh_color = (1.0, 0.45, 0.1)
        self.fire_interval = 999999  # never shoots
        self.spread = 0

    def _fire(self, rand, level, grade, base, bullet_kind, max_interval, size, speed,
              spread_n=0, fire_mul=1.0):
        bi_min = int(base / max(1.0, level) * fire_mul)
        if bi_min > max_interval:
            bi_min = max_interval
        elif bi_min < 20:
            bi_min = 20
        if grade is not None:
            bi_min += (config.GRADE_NUM - 1 - grade) * 6
        self.fire_interval = bi_min + rand.next_int(max(1, 60 - bi_min) + 1)
        self.bullet_kind = bullet_kind
        self.bullet_size = size
        self.bullet_speed = speed
        r = rand.next_int(3)
        self.aimed = (r == 0) or self.aim_ship
        if spread_n > 0:
            self.spread = spread_n
        else:
            self.spread = 3 if r == 2 else 0

    def set_speed(self, speed, ship_speed=None):
        if ship_speed is not None:
            aim = max(self.base_speed, ship_speed * self.ship_speed_ratio)
        else:
            aim = self.base_speed
        speed += (aim - speed) * config.SPEED_CHANGE_RATIO
        return speed


class Enemy:
    def __init__(self):
        self.spec = None
        self.pos_x = 0.0
        self.pos_y = 0.0
        self.speed = 0.0
        self.bank = 0.0
        self.base_bank = 0.0
        self.d1 = 0.0
        self.d2 = 0.0
        self.cnt = 0
        self.high_order = True
        self.passed = False
        self.exists = False
        self.fire_timer = 0
        self.max_shield = 1
        self.hit_flash = 0

    def set(self, spec, x, y, rand, passed=False, base_bank=0.0):
        self.spec = spec
        self.max_shield = spec.shield
        self.hit_flash = 0
        self.pos_x = x
        self.pos_y = y
        self.speed = 0.0
        self.d1 = self.d2 = 0.0
        self.cnt = 0
        self.bank = 0.0
        self.base_bank = spec.create_base_bank(rand) if (rand and not passed) else base_bank
        self.high_order = True
        self.passed = passed
        self.exists = True
        self.fire_timer = spec.fire_interval // 2

    def move(self, tunnel, ship, bullets, rand):
        if not self.exists:
            return
        if not self.passed:
            if self.high_order:
                if self.pos_y <= ship.rel_y:
                    ship.rank_up(self.spec.is_boss)
                    self.high_order = False
            else:
                if self.pos_y > ship.rel_y:
                    ship.rank_down()
                    self.high_order = True

        if ship.is_boss_mode_end:
            self.speed += (0 - self.speed) * 0.05
        elif not ship.has_collision():
            self.speed += (1.5 - self.speed) * 0.15

        if self.spec.has_limit_y:
            self.speed = self.spec.set_speed(self.speed, ship.speed)
        elif 5 < self.pos_y < config.IN_SIGHT_DEPTH_DEFAULT * 2:
            self.speed = self.spec.set_speed(self.speed, ship.speed)
        else:
            self.speed = self.spec.set_speed(self.speed)

        my = self.speed - ship.speed
        if self.passed and my > 0:
            my = 0
        self.pos_y += my

        # Steer toward the ship if it aims (light homing).
        if self.spec.aim_ship and not self.passed and not ship.is_boss_mode_end:
            ox = self.pos_x - ship.rel_x
            if ox > PI:
                ox -= TWO_PI
            elif ox < -PI:
                ox += TWO_PI
            if abs(ox) > PI / 3:
                target = ship.rel_x
                d = target - self.pos_x
                if d > PI:
                    d -= TWO_PI
                elif d < -PI:
                    d += TWO_PI
                d = max(-self.spec.bank_max, min(self.spec.bank_max, d))
                self.bank += (d - self.bank) * 0.1
            else:
                self.bank += (self.base_bank - self.bank) * 0.2
        else:
            self.bank += (self.base_bank - self.bank) * 0.2
        self.bank *= 0.9
        self.pos_x += self.bank * 0.08 * (config.DEFAULT_RAD / tunnel.get_radius(self.pos_y))
        self.pos_x = wrap_two_pi(self.pos_x)

        sl = tunnel.get_slice(self.pos_y)
        co = tunnel.check_in_course((self.pos_x, self.pos_y))
        if co != 0.0:
            bm = max(-1.0, min(1.0, (-config.OUT_OF_COURSE_BANK * co - self.bank) * 0.075))
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

        self.d1 += (sl.d1 - self.d1) * 0.1
        self.d2 += (sl.d2 - self.d2) * 0.1

        # Fire.  Bosses fire faster (and enrage) as their HP drops.
        if not self.passed and not ship.is_boss_mode_end and not ship.is_game_over:
            self.fire_timer -= 1
            interval = self.spec.fire_interval
            if self.spec.is_boss and self.max_shield > 1:
                r = self.spec.shield / max(1, self.max_shield)
                if r < 0.5:
                    interval = max(14, int(interval * 0.6))
            if self.fire_timer <= 0 and self.pos_y < ship.in_sight_depth + 10:
                self._fire(tunnel, ship, bullets, rand)
                self.fire_timer = interval

        # Cull.
        if not self.passed:
            if (not self.spec.has_limit_y and self.pos_y > config.IN_SIGHT_DEPTH_DEFAULT * 5) \
                    or self.pos_y < DISAP_DEPTH:
                self.exists = False
        else:
            if self.pos_y < -config.IN_SIGHT_DEPTH_DEFAULT * 3:
                self.exists = False
        if self.hit_flash > 0:
            self.hit_flash -= 1
        self.cnt += 1

    def _fire(self, tunnel, ship, bullets, rand):
        bx, by = self.pos_x, self.pos_y
        if self.spec.spread:
            n = self.spec.spread
            base = math.atan2(ship.rel_x - bx, ship.rel_y - by)
            for i in range(n):
                ang = base + (i - (n - 1) / 2) * 0.12
                b = bullets.get()
                if b is None:
                    return
                b.set(bx, by, math.sin(ang) * self.spec.bullet_speed,
                      math.cos(ang) * self.spec.bullet_speed,
                      life=400, size=self.spec.bullet_size, kind=self.spec.bullet_kind % 2)
        else:
            dx = ship.rel_x - bx
            if dx > PI:
                dx -= TWO_PI
            elif dx < -PI:
                dx += TWO_PI
            dy = ship.rel_y - by
            if self.spec.aimed:
                ln = math.hypot(dx, dy) or 1.0
                vx = dx / ln * self.spec.bullet_speed
                vy = dy / ln * self.spec.bullet_speed
            else:
                vx, vy = 0.0, -self.spec.bullet_speed
            b = bullets.get()
            if b is None:
                return
            b.set(bx, by, vx, vy, life=400, size=self.spec.bullet_size, kind=self.spec.bullet_kind % 2)

    def draw_gl(self, tunnel):
        if not self.exists:
            return
        sp = tunnel.get_pos_2((self.pos_x, self.pos_y))
        scale = 1.3
        if sp.z > 200:
            scale = 1.3 - (sp.z - 200) * 0.0025
        if scale <= 0.05:
            return
        if self.spec.final:
            scale *= 1.45
        mesh = enemy_mesh(self.spec.kind, self.spec.mesh_color)
        if self.hit_flash > 0:
            mesh.line_color = (1.0, 1.0, 1.0)
            mesh.poly_color = (0.8, 0.8, 0.8)
        elif self.spec.is_boss and self.max_shield > 1:
            r = self.spec.shield / max(1, self.max_shield)
            if r < 0.5:
                lc = mesh.line_color
                mesh.line_color = (1.0, lc[1] * 0.5, lc[2] * 0.5)
                mesh.poly_color = (0.75, lc[1] * 0.4, lc[2] * 0.4)
        draw_mesh(mesh, (sp.x, sp.y, sp.z), rz=self.pos_x - self.bank, ry=self.d1, rx=self.d2,
                  scale=scale)


class EnemyPool:
    def __init__(self, n):
        self.items = [Enemy() for _ in range(n)]

    def get(self):
        for e in self.items:
            if not e.exists:
                return e
        return None

    def get_num(self):
        return sum(1 for e in self.items if e.exists)

    def clear(self):
        for e in self.items:
            e.exists = False

    def move(self, tunnel, ship, bullets, rand):
        for e in self.items:
            if e.exists:
                e.move(tunnel, ship, bullets, rand)

    def draw_gl(self, tunnel):
        for e in self.items:
            if e.exists:
                e.draw_gl(tunnel)

    def check_shot_hit(self, shot):
        """Return True if a shot hit an enemy (and score it)."""
        for e in self.items:
            if not e.exists:
                continue
            if e.spec.is_boss:
                # Boss hit width (rough).
                hit_w = 2.0
            else:
                hit_w = 1.2
            dx = abs(e.pos_x - shot.pos_x)
            if dx > PI:
                dx = TWO_PI - dx
            dy = abs(e.pos_y - shot.pos_y)
            if dx <= hit_w and dy <= hit_w:
                e.hit(shot.damage)
                return e
        return None


# Add hit handling to Enemy.
def _enemy_hit(self, damage):
    self.spec.shield -= damage
    self.hit_flash = 8
    if self.spec.shield <= 0:
        self.exists = False
        return True
    return False


Enemy.hit = _enemy_hit


def _spec_base_bank(self, rand):
    return rand.next_signed_float(self.base_bank)


ShipSpec.create_base_bank = _spec_base_bank
