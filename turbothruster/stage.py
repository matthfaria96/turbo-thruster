"""Stage manager: enemy spawning and tunnel colour cycling (``stagemanager.d``)."""

import math

from . import config
from .vec import PI, TWO_PI
from .torus import Torus
from .enemy import ShipSpec
from . import campaign


class StageManager:
    def __init__(self, tunnel, enemies, ship):
        self.tunnel = tunnel
        self.enemies = enemies
        self.ship = ship
        self.rand = None
        self.torus = Torus()
        self.level = 0.0
        self.grade = config.GRADE_NORMAL
        self.small_specs = []
        self.middle_specs = []
        self.boss_specs = []
        self.next_small_app_dist = 0.0
        self.next_middle_app_dist = 0.0
        self.next_boss_app_dist = 9999999.0
        self.boss_num = 0
        self.boss_spec_idx = 0
        self.zone_end_rank = 0
        self.middle_boss_zone = False
        self.boss_mode_end_cnt = -1
        self.sector_index = None
        self.final_zone = False

        # Tunnel colour state.
        self.dark_line = True
        self.dark_line_ratio = 1.0
        self.poly_rgb = list(config.TUNNEL_COLOR_PATTERN_POLY[0])
        self.line_rgb = list(config.TUNNEL_COLOR_PATTERN_LINE[0])
        self._target_poly = list(self.poly_rgb)
        self._target_line = list(self.line_rgb)
        self._theme_poly = None
        self._theme_line = None

    def start(self, level, grade, seed, sector_index=None, theme=None):
        self.rand.set_seed(seed)
        self.torus.create(seed)
        self.tunnel.start(self.torus)
        self.level = level - config.LEVEL_UP_RATIO
        self.grade = grade
        self.zone_end_rank = 0
        self.middle_boss_zone = False
        self.dark_line = True
        self.dark_line_ratio = 1.0
        self.boss_mode_end_cnt = -1
        self.sector_index = sector_index
        if theme is not None:
            self._theme_poly = list(theme[0])
            self._theme_line = list(theme[1])
        else:
            self._theme_poly = None
            self._theme_line = None
        self._set_color_target()
        self.create_next_zone()

    def _set_color_target(self):
        if self._theme_poly is not None:
            self._target_poly = list(self._theme_poly)
            self._target_line = list(self._theme_line)
        else:
            n = len(config.TUNNEL_COLOR_PATTERN_POLY)
            idx = (int(self.level) + 1) % n
            self._target_poly = list(config.TUNNEL_COLOR_PATTERN_POLY[idx])
            self._target_line = list(config.TUNNEL_COLOR_PATTERN_LINE[idx])
        if self.dark_line_ratio >= 1.0:
            self.poly_rgb = list(self._target_poly)
            self.line_rgb = list(self._target_line)

    def create_next_zone(self):
        self.level += config.LEVEL_UP_RATIO
        self.middle_boss_zone = not self.middle_boss_zone
        self.dark_line = not self.dark_line
        self._set_color_target()
        self.enemies.clear()
        self.small_specs = []
        for _ in range(2 + self.rand.next_int(2)):
            s = ShipSpec()
            s.create_small(self.rand, self.level * 1.8, self.grade)
            self.small_specs.append(s)
        self.middle_specs = []
        for _ in range(2 + self.rand.next_int(2)):
            s = ShipSpec()
            s.create_middle(self.rand, self.level * 1.9)
            self.middle_specs.append(s)
        self.next_small_app_dist = 0.0
        self.next_middle_app_dist = 0.0
        self.set_next_small_app_dist()
        self.set_next_middle_app_dist()

        self.boss_specs = []
        if self.final_zone and self.sector_index is not None:
            self.boss_num = 1
        elif self.middle_boss_zone and self.level > 5 and self.rand.next_int(3) != 0:
            self.boss_num = 1 + self.rand.next_int(int(math.sqrt(self.level / 5)) + 1)
            if self.boss_num > 4:
                self.boss_num = 4
        else:
            self.boss_num = 1
        for _ in range(self.boss_num):
            s = ShipSpec()
            lv = self.level * 2.0 / self.boss_num
            if self.middle_boss_zone:
                lv *= 1.33
            if self.final_zone and self.sector_index is not None:
                theme = campaign.SECTORS[self.sector_index].boss
                s.create_boss(self.rand, lv, theme.get("speed", 0.9),
                              self.middle_boss_zone, theme)
            else:
                s.create_boss(self.rand, lv,
                              0.8 + self.grade * 0.04 + self.rand.next_float(0.03),
                              self.middle_boss_zone)
            self.boss_specs.append(s)

        boss_app_rank = config.BOSS_APP_RANK[self.grade] - self.boss_num + self.zone_end_rank
        self.zone_end_rank += config.BOSS_APP_RANK[self.grade]
        self.ship.set_boss_app(boss_app_rank, self.boss_num, self.zone_end_rank)
        self.boss_spec_idx = 0
        self.next_boss_app_dist = 9999999.0
        self.boss_mode_end_cnt = -1

    def move(self):
        ship = self.ship
        if ship.in_boss_mode:
            if self.next_boss_app_dist > 99999:
                self.next_boss_app_dist = self.rand.next_int(50) + 100
                self.next_small_app_dist = self.next_middle_app_dist = 9999999.0
            self.next_boss_app_dist -= ship.speed
            if self.boss_num > 0 and self.next_boss_app_dist <= 0:
                self.add_enemy(self.boss_specs[self.boss_spec_idx],
                               config.IN_SIGHT_DEPTH_DEFAULT * 4)
                self.boss_num -= 1
                self.next_boss_app_dist = self.rand.next_int(30) + 60
                self.boss_spec_idx += 1
            if self.boss_num <= 0 and self.enemies.get_num() <= 0:
                ship.goto_next_zone_forced()
            self._update_colors()
            return

        if self.next_boss_app_dist < 99999:
            self.boss_mode_end_cnt = 60
            self.next_small_app_dist = self.next_middle_app_dist = self.next_boss_app_dist = 9999999.0
        if self.boss_mode_end_cnt >= 0:
            self.boss_mode_end_cnt -= 1
            ship.clear_visible_bullets()
            if self.boss_mode_end_cnt < 0:
                self.create_next_zone()
                ship.start_next_zone()

        self.next_small_app_dist -= ship.speed
        if self.next_small_app_dist <= 0:
            if self.rand.next_int(4) == 0:
                # Kamikaze: a fast rammer instead of a regular enemy.
                spec = ShipSpec()
                spec.create_kamikaze(self.rand, self.level, self.grade)
                self.add_enemy(spec,
                               config.IN_SIGHT_DEPTH_DEFAULT * (4 + self.rand.next_float(0.5)))
            else:
                self.add_enemy(self.small_specs[self.rand.next_int(len(self.small_specs))],
                               config.IN_SIGHT_DEPTH_DEFAULT * (4 + self.rand.next_float(0.5)))
            self.set_next_small_app_dist()
        self.next_middle_app_dist -= ship.speed
        if self.next_middle_app_dist <= 0:
            self.add_enemy(self.middle_specs[self.rand.next_int(len(self.middle_specs))],
                           config.IN_SIGHT_DEPTH_DEFAULT * (4 + self.rand.next_float(0.5)))
            self.set_next_middle_app_dist()
        self._update_colors()

    def _update_colors(self):
        step = 1.0 / config.TUNNEL_COLOR_CHANGE_INTERVAL
        target = 1.0 if self.dark_line else 0.0
        d = self.dark_line_ratio
        if d < target:
            d = min(target, d + step)
        elif d > target:
            d = max(target, d - step)
        self.dark_line_ratio = d
        # Ease colours toward the zone target.
        k = 0.05
        for i in range(3):
            self.poly_rgb[i] += (self._target_poly[i] - self.poly_rgb[i]) * k
            self.line_rgb[i] += (self._target_line[i] - self.line_rgb[i]) * k

    def set_next_small_app_dist(self):
        self.next_small_app_dist += self.rand.next_int(8) + 3

    def set_next_middle_app_dist(self):
        self.next_middle_app_dist += self.rand.next_int(120) + 20

    def add_enemy(self, spec, y):
        en = self.enemies.get()
        if en is None:
            return
        sl = self.tunnel.get_slice(y)
        if sl.is_nearly_round():
            x = self.rand.next_float(PI)
        else:
            ld = sl.left_edge_deg()
            rd = sl.right_edge_deg()
            wd = rd - ld
            if wd < 0:
                wd += TWO_PI
            x = ld + self.rand.next_float(wd)
        if x < 0:
            x += TWO_PI
        elif x >= TWO_PI:
            x -= TWO_PI
        en.set(spec, x, y, self.rand)
