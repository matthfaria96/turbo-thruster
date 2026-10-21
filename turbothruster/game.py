"""Game manager: full state machine (menus, campaign, turbo) and main loop."""

import math
import os
import random
import sys

import numpy as np
import pygame
from .glrender import *  # noqa: F401,F403  (raw GL functions/constants)

from . import config
from . import campaign
from . import glrender
from .vec import Rand, TWO_PI, PI
from .torus import Torus
from .tunnel import Tunnel
from .ship import Ship, DIR_UP, DIR_DOWN, DIR_LEFT, DIR_RIGHT, BTN_A, BTN_B
from .entities import ShotPool, BulletPool, ParticlePool, PowerUpPool
from .enemy import EnemyPool
from .stage import StageManager
from .audio import SoundManager
from .hud import HudFonts, draw_hud
from .progress import Progress
from . import __version__

# States.
MENU = "menu"
SECTOR_SELECT = "sector_select"
SETTINGS = "settings"
LEADERBOARD = "leaderboard"
BRIEFING = "briefing"
PLAY = "play"
SECTOR_CLEAR = "sector_clear"
GAME_OVER = "game_over"
CAMPAIGN_COMPLETE = "campaign_complete"
PAUSED = "paused"
CONFIRM_QUIT = "confirm_quit"
ACHIEVEMENTS_SCREEN = "achievements"

# Resolution presets shown in Settings.
RESOLUTIONS = [
    ("1280x720", (1280, 720)),
    ("1600x900", (1600, 900)),
    ("1920x1080", (1920, 1080)),
    ("2560x1080", (2560, 1080)),
    ("2560x1440", (2560, 1440)),
    ("3440x1440", (3440, 1440)),
    ("1024x768", (1024, 768)),
]

EFFECTS = {"baixo": 0.0, "medio": 0.9, "alto": 1.6}

ACHIEVEMENTS = {
    "primeiro_abate": "PRIMEIRO ABATE",
    "cem_abates": "100 ABATES",
    "cacador_chefes": "CACADOR DE CHEFES",
    "primeira_morte": "PRIMEIRA MORTE",
    "bombardeiro": "BOMBARDEIRO",
    "conquistador": "CONQUISTADOR",
}

# Control actions (rebindable primary keys; WASD/Ctrl remain as alternates).
CONTROL_ORDER = ["up", "down", "left", "right", "shoot", "charge", "dash", "bomb", "pause"]
CONTROL_LABELS = {
    "up": "MOVER CIMA", "down": "MOVER BAIXO", "left": "MOVER ESQUERDA",
    "right": "MOVER DIREITA", "shoot": "ATIRAR", "charge": "CHARGE SHOT",
    "dash": "IMPULSO (DASH)", "bomb": "BOMBA", "pause": "PAUSAR",
}
DEFAULT_CONTROLS = {
    "up": pygame.K_w, "down": pygame.K_s, "left": pygame.K_a,
    "right": pygame.K_d, "shoot": pygame.K_z, "charge": pygame.K_x,
    "dash": pygame.K_e, "bomb": pygame.K_q, "pause": pygame.K_p,
}


def key_name(keycode):
    return pygame.key.name(keycode).upper()


class Game:
    def __init__(self, options):
        self.opts = options
        self.rand = Rand()
        self.fonts = HudFonts()
        self.progress = Progress()

        self.torus = Torus()
        self.tunnel = Tunnel()
        self.ship = Ship(self.tunnel)
        self.shots = ShotPool(64)
        self.bullets = BulletPool(512)
        self.enemies = EnemyPool(64)
        self.particles = ParticlePool(1024)
        self.powerups = PowerUpPool(16)
        self.stage = StageManager(self.tunnel, self.enemies, self.ship)
        self.stage.rand = self.rand
        self.particles.rand = self.rand
        self.ship.set_shots(self.shots)
        self.ship.set_particles(self.particles)
        self.ship.set_game(self)
        self.audio = SoundManager(options.asset_dir)

        # In-game state.
        self.state = MENU
        self.mode = "campaign"       # "campaign" | "turbo"
        self.score = 0
        self.next_extend = 0
        self.time = config.DEFAULT_TIME
        self.time_changed_show_cnt = -1
        self.time_changed_msg = ""
        self.pause_cnt = 0
        self.start_bgm_cnt = -1
        self.game_over_cnt = 0
        self.level = 1
        self.grade = config.GRADE_NORMAL
        self.seed = 0
        self.combo = 0
        self.combo_timer = 0
        self.bombs = 2
        self._powerup_timer = 0
        self.portal_dist = -1.0   # distance ahead of the finish portal (-1 = off)
        self.portal_anim = 0      # celebration frames after crossing it
        self.ach_msg = ""
        self.ach_timer = 0
        self.run_kills = 0        # kills in the current sector run
        self.max_combo = 0        # best combo this run
        self.run_deaths = 0       # lives lost this run
        self.pickup_msg = ""      # power-up pickup feedback
        self.pickup_timer = 0
        self.boss_warn = 0        # "CHEFE!" warning frames
        self._prev_dir = 0
        self._keys_down = set()   # robust keyboard state from KEYDOWN/KEYUP
        self._scans_down = set()  # layout-independent scancode state
        self._prev_btn = 0
        self.quit_requested = False
        self._recreate_window = False

        # Campaign / turbo state.
        self.sector = 0              # 0-based sector index
        self.sector_zone = 1         # 1-based zone within the sector
        self.zones_per_sector = 3
        self._upgrade_choices = []
        self._upgrade_cursor = 0

        # Menu state.
        self.menu_cursor = 0
        self.sector_select_cursor = 0
        self.settings_cursor = 0
        self.pause_cursor = 0
        self.quit_cursor = 1
        self.fade = 1.0

        # Mouse / click interaction.
        self.mouse_pos = (0, 0)
        self._hit_targets = []
        self._bg_cache = {}
        self._overlay = None
        self._hud_tex = None

        # Controls (rebindable).
        s = self.progress.data["settings"]
        if not s.get("controls"):
            s["controls"] = dict(DEFAULT_CONTROLS)
        # Migrate any old arrow-based movement defaults to WASD.
        for act, old in (("up", pygame.K_UP), ("down", pygame.K_DOWN),
                         ("left", pygame.K_LEFT), ("right", pygame.K_RIGHT)):
            if s["controls"].get(act) == old:
                s["controls"][act] = DEFAULT_CONTROLS[act]
        self.controls = s["controls"]
        self.settings_tab = 0
        self._listening_action = None

        # Apply persisted settings.
        self.apply_settings()

    # ---------------------------------------------------------------- audio
    def init_audio(self):
        self.audio.load(pygame)
        self.apply_audio_volumes()

    def apply_audio_volumes(self):
        mv = self.progress.get_setting("music_volume")
        sv = self.progress.get_setting("sfx_volume")
        if self.audio.enabled:
            try:
                pygame.mixer.music.set_volume(mv)
                for snd in self.audio.sounds.values():
                    snd.set_volume(sv)
            except Exception:
                pass

    # ---------------------------------------------------------------- settings
    def apply_settings(self):
        s = self.progress.data["settings"]
        self.opts.fullscreen = s.get("fullscreen", False)
        self.opts.vsync = s.get("vsync", True)
        self.opts.brightness = s.get("brightness", 1.0)
        res = s.get("resolution", [self.opts.width, self.opts.height])
        self.opts.width = int(res[0])
        self.opts.height = int(res[1])

    # ---------------------------------------------------------------- state
    def _set_state(self, new_state):
        self.state = new_state
        self.fade = 0.0
        self._hit_targets = []

    def _back(self):
        """Handle Esc/back: navigate up one level; pause in-game; confirm quit."""
        if self.state == MENU:
            self.quit_cursor = 1
            self._set_state(CONFIRM_QUIT)
        elif self.state == CONFIRM_QUIT:
            self._set_state(MENU)
        elif self.state == SECTOR_SELECT:
            self._set_state(MENU)
        elif self.state == SETTINGS:
            self.progress.save()
            self.apply_settings()
            self._recreate_window = True
            self._set_state(MENU)
        elif self.state == LEADERBOARD:
            self._set_state(SECTOR_SELECT)
        elif self.state == BRIEFING:
            self._set_state(SECTOR_SELECT)
        elif self.state == SECTOR_CLEAR:
            self._set_state(SECTOR_SELECT)
        elif self.state == PLAY:
            self.pause_cursor = 0
            self._set_state(PAUSED)
        elif self.state == PAUSED:
            self._set_state(PLAY)
        elif self.state == GAME_OVER:
            self._set_state(MENU if self.mode == "campaign" else LEADERBOARD)
        elif self.state == CAMPAIGN_COMPLETE:
            self._set_state(MENU)
        elif self.state == ACHIEVEMENTS_SCREEN:
            self._set_state(MENU)

    # ---------------------------------------------------------------- play start
    def _start_play(self, level, grade, sector_idx, theme):
        self.seed = self.rand.next_int32()
        self.ship.set_upgrades(self.progress.get_upgrades())
        self.ship.start(grade, self.seed)
        self.stage.start(level, grade, self.seed, sector_idx, theme)
        self.tunnel.set_ship_pos(0.0, 0.0, 0.0)
        self.tunnel.set_slices()
        self.shots.clear()
        self.bullets.clear()
        self.enemies.clear()
        self.particles.clear()
        self.powerups.clear()
        self.combo = 0
        self.combo_timer = 0
        self.bombs = 2
        self._powerup_timer = 240
        self.portal_dist = -1.0
        self.portal_anim = 0
        self.run_kills = 0
        self.max_combo = 0
        self.run_deaths = 0
        self.pickup_msg = ""
        self.pickup_timer = 0
        self.boss_warn = 0
        self.init_game_state()
        self.audio.enable_se()
        self.audio.play_bgm()
        self.start_bgm_cnt = -1
        self.game_over_cnt = 0
        self.pause_cnt = 0
        self._set_state(PLAY)

    def start_sector(self, sector_idx):
        sec = campaign.SECTORS[sector_idx]
        self.mode = "campaign"
        self.sector = sector_idx
        self.sector_zone = 1
        # One continuous run: the sector boss is the only boss (no internal zones).
        self.zones_per_sector = 1
        self.stage.final_zone = True
        self.level = sector_idx + 1
        self._start_play(1 + sector_idx * 0.5, config.GRADE_NORMAL,
                         sector_idx, (sec.poly, sec.line))

    def start_turbo(self):
        self.mode = "turbo"
        self.level = 1
        self.stage.final_zone = False
        self._start_play(1.0, config.GRADE_NORMAL, None, None)

    def _show_briefing(self, sector_idx):
        self.sector = sector_idx
        self._set_state(BRIEFING)

    # ---------------------------------------------------------------- scoring
    def init_game_state(self):
        self.score = 0
        self.next_extend = 0
        self.set_next_extend()
        self.time_changed_show_cnt = -1
        self.goto_next_zone(True)

    def _max_time(self):
        return config.MAX_TIME + (20000 if self.ship.has_upgrade("time") else 0)

    def goto_next_zone(self, is_first=False):
        self.clear_visible_bullets()
        if self.mode == "campaign" and not is_first:
            self.sector_zone += 1
            if self.sector_zone > self.zones_per_sector:
                self.sector_zone = self.zones_per_sector
                # Finish line: an explosive portal opens ahead of the ship.
                self.portal_dist = 32.0
                self.audio.play_se("boss_dest.wav")
                return
            self.stage.final_zone = (self.sector_zone == self.zones_per_sector)
        if is_first:
            self.time = self._max_time()
        else:
            if self.stage.middle_boss_zone:
                self.change_time(config.NEXT_ZONE_ADDITION_TIME, config.NEXT_ZONE_ADDITION_TIME_MSG)
            else:
                self.change_time(config.NEXT_LEVEL_ADDITION_TIME, config.NEXT_LEVEL_ADDITION_TIME_MSG)
                self.start_bgm_cnt = 90
                self.audio.fade_bgm()

    def set_next_extend(self):
        es = (int(self.stage.level * 0.5) + 10) * config.DEFAULT_EXTEND_SCORE // 10
        if es > config.MAX_EXTEND_SCORE:
            es = config.MAX_EXTEND_SCORE
        self.next_extend += es

    def extend_ship(self):
        self.change_time(config.EXTEND_TIME, config.EXTEND_TIME_MSG)
        self.audio.play_se("extend.wav")

    def change_time(self, ct, msg):
        self.time += ct
        if self.time > self._max_time():
            self.time = self._max_time()
        self.time_changed_show_cnt = 240
        self.time_changed_msg = msg

    def add_score(self, sc):
        if self.ship.is_game_over:
            return
        self.score += sc
        while self.score > self.next_extend:
            self.set_next_extend()
            self.extend_ship()

    def ship_destroyed(self):
        self.run_deaths += 1
        self._unlock_achievement("primeira_morte")
        self.clear_visible_bullets()
        self.change_time(config.SHIP_DESTROYED_PENALTY_TIME,
                         config.SHIP_DESTROYED_PENALTY_TIME_MSG)
        self.audio.play_se("myship_dest.wav")

    def clear_visible_bullets(self):
        self.bullets.clear_visible()

    def decrement_time(self):
        self.time -= config.TIME_DECREMENT_PER_FRAME
        if self.time_changed_show_cnt >= 0:
            self.time_changed_show_cnt -= 1

    # ---------------------------------------------------------------- upgrade
    def _roll_upgrades(self):
        chosen = set(self.progress.get_upgrades())
        pool = [u for u in campaign.UPGRADE_ORDER if u not in chosen]
        if len(pool) <= 3:
            return list(pool)
        return random.sample(pool, 3)

    def _apply_upgrade(self, uid):
        self.progress.add_upgrade(uid)
        self.progress.save()
        self.ship.set_upgrades(self.progress.get_upgrades())

    # ---------------------------------------------------------------- sector flow
    def _sector_cleared(self):
        self.audio.halt_bgm()
        self.audio.disable_se()
        self.audio.play_se("extend.wav")
        if self.sector >= campaign.SECTOR_COUNT - 1:
            self.progress.set_campaign_complete()
            self.progress.save()
            self._unlock_achievement("conquistador")
            self._set_state(CAMPAIGN_COMPLETE)
        else:
            self.progress.unlock_sector(self.sector + 1)
            self.progress.save()
            remaining = [u for u in campaign.UPGRADE_ORDER
                         if u not in self.progress.get_upgrades()]
            if remaining:
                self._upgrade_choices = self._roll_upgrades()
                self._upgrade_cursor = 0
                self._set_state(SECTOR_CLEAR)
            else:
                # All upgrades owned: skip straight to the next sector.
                self._show_briefing(self.sector + 1)

    # ---------------------------------------------------------------- update
    def update(self, dir_bits, btn_bits, pause_toggle, mouse_click=False):
        dir_press = dir_bits & ~self._prev_dir
        btn_press = btn_bits & ~self._prev_btn
        self._prev_dir = dir_bits
        self._prev_btn = btn_bits

        if self.state == MENU:
            self._menu_update(dir_press, btn_press, mouse_click)
        elif self.state == SECTOR_SELECT:
            self._sector_select_update(dir_press, btn_press, mouse_click)
        elif self.state == SETTINGS:
            self._settings_update(dir_press, btn_press, mouse_click)
        elif self.state == LEADERBOARD:
            self._leaderboard_update(dir_press, btn_press, mouse_click)
        elif self.state == BRIEFING:
            self._briefing_update(dir_press, btn_press, mouse_click)
        elif self.state == PLAY:
            self._play_update(dir_bits, btn_bits, pause_toggle)
        elif self.state == SECTOR_CLEAR:
            self._sector_clear_update(dir_press, btn_press, mouse_click)
        elif self.state == GAME_OVER:
            self._game_over_update(btn_press, mouse_click)
        elif self.state == CAMPAIGN_COMPLETE:
            self._campaign_complete_update(btn_press, mouse_click)
        elif self.state == ACHIEVEMENTS_SCREEN:
            self._achievements_update(btn_press, mouse_click)
        elif self.state == PAUSED:
            self._paused_update(dir_press, btn_press, mouse_click)
        elif self.state == CONFIRM_QUIT:
            self._confirm_quit_update(dir_press, btn_press, mouse_click)

    # ---- menu ----------------------------------------------------------
    def _menu_items(self):
        return [("INICIAR", "iniciar"), ("CONQUISTAS", "conquistas"),
                ("CONFIGURACOES", "config"), ("SAIR", "sair")]

    def _menu_activate(self, action):
        if action == "iniciar":
            self._set_state(SECTOR_SELECT)
        elif action == "conquistas":
            self._set_state(ACHIEVEMENTS_SCREEN)
        elif action == "config":
            self._set_state(SETTINGS)
        elif action == "sair":
            self.quit_cursor = 1
            self._set_state(CONFIRM_QUIT)

    def _menu_update(self, dir_press, btn_press, mouse_click):
        items = self._menu_items()
        if mouse_click:
            act = self._hit_test()
            if act:
                self._menu_activate(act)
                return
        if dir_press & DIR_UP:
            self.menu_cursor = (self.menu_cursor - 1) % len(items)
        if dir_press & DIR_DOWN:
            self.menu_cursor = (self.menu_cursor + 1) % len(items)
        if btn_press & BTN_A:
            self._menu_activate(items[self.menu_cursor][1])

    # ---- sector select -------------------------------------------------
    def _sector_select_activate(self, idx):
        if idx < campaign.SECTOR_COUNT:
            if idx < self.progress.unlocked_sector:
                self._show_briefing(idx)
        else:
            if self.progress.turbo_unlocked:
                self._set_state(LEADERBOARD)

    def _sector_select_update(self, dir_press, btn_press, mouse_click):
        total = campaign.SECTOR_COUNT + 1  # + MODO TURBO
        if mouse_click:
            act = self._hit_test()
            if act == "turbo":
                self._sector_select_activate(campaign.SECTOR_COUNT)
                return
            if act and act.startswith("sector_"):
                self._sector_select_activate(int(act.split("_")[1]))
                return
        if dir_press & DIR_LEFT:
            self.sector_select_cursor = (self.sector_select_cursor - 1) % total
        if dir_press & DIR_RIGHT:
            self.sector_select_cursor = (self.sector_select_cursor + 1) % total
        if dir_press & DIR_UP:
            self.sector_select_cursor = (self.sector_select_cursor - 4) % total
        if dir_press & DIR_DOWN:
            self.sector_select_cursor = (self.sector_select_cursor + 4) % total
        if btn_press & BTN_A:
            self._sector_select_activate(self.sector_select_cursor)

    # ---- settings ------------------------------------------------------
    def _change_setting(self, key, delta):
        s = self.progress.data["settings"]
        if key == "resolution":
            labels = [r[0] for r in RESOLUTIONS]
            cur = s.get("resolution", [1280, 720])
            cur_label = "%dx%d" % (cur[0], cur[1])
            i = labels.index(cur_label) if cur_label in labels else 0
            i = (i + delta) % len(RESOLUTIONS)
            s["resolution"] = list(RESOLUTIONS[i][1])
            self._recreate_window = True
        elif key == "fullscreen":
            s["fullscreen"] = not s["fullscreen"]
            self._recreate_window = True
        elif key == "effects":
            names = list(EFFECTS.keys())
            cur = s.get("effects", "alto")
            i = names.index(cur) if cur in names else 2
            i = (i + delta) % len(names)
            s["effects"] = names[i]
        elif key == "music_volume":
            s["music_volume"] = max(0.0, min(1.0, s["music_volume"] + delta * 0.1))
            self.apply_audio_volumes()
        elif key == "sfx_volume":
            s["sfx_volume"] = max(0.0, min(1.0, s["sfx_volume"] + delta * 0.1))
            self.apply_audio_volumes()
        elif key == "brightness":
            s["brightness"] = max(0.1, min(1.0, s["brightness"] + delta * 0.1))
            self.opts.brightness = s["brightness"]

    def _settings_tab_items(self):
        return [
            ("GRAFICOS", ["resolution", "fullscreen", "effects", "brightness"]),
            ("SOM", ["music_volume", "sfx_volume"]),
            ("CONTROLES", list(CONTROL_ORDER)),
        ]

    def _cycle_tab(self):
        if self._listening_action is not None:
            return
        self.settings_tab = (self.settings_tab + 1) % 3
        self.settings_cursor = 0

    def _settings_update(self, dir_press, btn_press, mouse_click):
        tabs = self._settings_tab_items()
        items = tabs[self.settings_tab][1]

        if self._listening_action is not None:
            # Waiting for a key press; handled in the event loop.
            return

        if mouse_click:
            act = self._hit_test()
            if act in ("tab_0", "tab_1", "tab_2"):
                self.settings_tab = int(act.split("_")[1])
                self.settings_cursor = 0
                return
            if act and act.startswith("setval_"):
                idx = int(act.split("_")[1])
                self.settings_cursor = idx
                if self.settings_tab == 2:
                    self._listening_action = items[idx]
                else:
                    self._change_setting(items[idx], 1)
                return
            if act and act.startswith("set_"):
                self.settings_cursor = int(act.split("_")[1])
                if self.settings_tab == 2:
                    self._listening_action = items[self.settings_cursor]
                return

        if dir_press & DIR_UP:
            self.settings_cursor = (self.settings_cursor - 1) % len(items)
        if dir_press & DIR_DOWN:
            self.settings_cursor = (self.settings_cursor + 1) % len(items)

        if self.settings_tab == 2:
            if btn_press & BTN_A:
                self._listening_action = items[self.settings_cursor]
            return

        delta = 0
        if dir_press & DIR_LEFT:
            delta = -1
        if dir_press & DIR_RIGHT:
            delta = 1
        if delta:
            self._change_setting(items[self.settings_cursor], delta)

    # ---- leaderboard ---------------------------------------------------
    def _leaderboard_update(self, dir_press, btn_press, mouse_click):
        if btn_press & BTN_A or (mouse_click and self._hit_test() == "jogar"):
            self.start_turbo()

    # ---- briefing ------------------------------------------------------
    def _briefing_update(self, dir_press, btn_press, mouse_click):
        if btn_press & BTN_A or (mouse_click and self._hit_test() == "iniciar"):
            self.start_sector(self.sector)

    # ---- play ----------------------------------------------------------
    def _play_update(self, dir_bits, btn_bits, pause_toggle):
        if pause_toggle:
            if self.pause_cnt <= 0 and not self.ship.is_game_over:
                self.pause_cnt = 1
            else:
                self.pause_cnt = 0
        if self.pause_cnt > 0:
            self.pause_cnt += 1
            return

        if self.start_bgm_cnt > 0:
            self.start_bgm_cnt -= 1
            if self.start_bgm_cnt <= 0:
                self.audio.next_bgm()

        self.ship.move(dir_bits, btn_bits)
        self.stage.move()
        self.enemies.move(self.tunnel, self.ship, self.bullets, self.rand)
        self.shots.move()
        self.bullets.move()
        self.particles.move()
        self.powerups.move()
        self._update_combo()
        self._update_powerups()
        self._update_portal()
        self._update_notices()
        self._check_collisions()
        self.decrement_time()

        if self.time < 0 or self.ship.lives <= 0:
            self.time = 0
            if not self.ship.is_game_over:
                self.ship.is_game_over = True
                self.audio.fade_bgm()
                self.audio.disable_se()
                self._on_game_over()
            self.game_over_cnt += 1
            if self.game_over_cnt > 60 and (btn_bits & BTN_A):
                self._finish_game_over()
        else:
            self.game_over_cnt = 0

    def _update_combo(self):
        if self.combo_timer > 0:
            self.combo_timer -= 1
            if self.combo_timer <= 0:
                self.combo = 0

    def _update_notices(self):
        if self.pickup_timer > 0:
            self.pickup_timer -= 1
        # Boss warning: fire once when a boss first appears.
        if self.boss_warn <= 0:
            for e in self.enemies.items:
                if e.exists and e.spec.is_boss:
                    self.boss_warn = 120
                    self.audio.play_se("charge.wav")
                    break
        else:
            self.boss_warn -= 1

    def _unlock_achievement(self, aid):
        if self.progress.unlock_achievement(aid):
            self.ach_msg = "CONQUISTA: " + ACHIEVEMENTS.get(aid, aid)
            self.ach_timer = 180

    def _update_powerups(self):
        self._powerup_timer -= 1
        if self._powerup_timer <= 0:
            self._powerup_timer = self.rand.next_int(400) + 300
            pu = self.powerups.get()
            if pu is not None:
                types = ["life", "spread", "time", "score"]
                t = types[self.rand.next_int(4)]
                y = config.IN_SIGHT_DEPTH_DEFAULT * 3
                sl = self.tunnel.get_slice(y)
                if sl.is_nearly_round():
                    x = self.rand.next_float(PI)
                else:
                    x = sl.left_edge_deg() + self.rand.next_float(0.5)
                pu.set(x, y, t)
        for pu in self.powerups.items:
            if not pu.exists:
                continue
            dx = abs(pu.pos_x - self.ship.rel_x)
            if dx > PI:
                dx = TWO_PI - dx
            if dx < 0.9 and abs(pu.pos_y - self.ship.rel_y) < 3.0:
                self._collect_powerup(pu)
                pu.exists = False

    def _collect_powerup(self, pu):
        if pu.type == "life":
            self.ship.lives = min(3, self.ship.lives + 1)
            self.pickup_msg = "VIDA +1!"
            self.pickup_timer = 90
        elif pu.type == "spread":
            self.ship.spread_timer = 900
            self.pickup_msg = "TIRO TRIPLO!"
            self.pickup_timer = 90
        elif pu.type == "time":
            self.change_time(15000, "+15 SEC.")
            self.pickup_msg = "+15 SEGUNDOS"
            self.pickup_timer = 90
        elif pu.type == "score":
            self.add_score(5000)
            self.pickup_msg = "+5000 PONTOS"
            self.pickup_timer = 90
        self.audio.play_se("extend.wav")

    def trigger_bomb(self):
        if self.bombs <= 0 or self.ship.is_game_over or self.state != PLAY:
            return
        self.bombs -= 1
        self._unlock_achievement("bombardeiro")
        self.bullets.clear_visible()
        self.ship.screen_shake_cnt = 30
        self.ship.screen_shake_intense = 0.05
        self.audio.play_se("charge_shot.wav")
        for _ in range(60):
            p = self.particles.get()
            if p is None:
                break
            p.set((self.ship.rel_x, self.ship.rel_y), 0.5, 0.5, 20, 0.8, 1.0, 1.0, 5)

    def _update_portal(self):
        if self.portal_dist > 0:
            self.portal_dist -= self.ship.speed
            if self.portal_dist <= 0:
                # Crossed the finish line — celebrate.
                self.portal_dist = 0.0
                self.portal_anim = 110
                self.ship.cnt = -110  # invincible during the celebration
                self.ship.screen_shake_cnt = 50
                self.ship.screen_shake_intense = 0.06
                self.audio.play_se("extend.wav")
        if self.portal_anim > 0:
            self.portal_anim -= 1
            self._portal_fireworks()
            if self.portal_anim <= 0:
                self._sector_cleared()

    def _portal_fireworks(self):
        cols = ((1.0, 0.5, 0.9), (0.4, 0.9, 1.0), (0.5, 1.0, 0.5),
                (1.0, 0.9, 0.4), (1.0, 1.0, 1.0))
        for _ in range(5):
            p = self.particles.get()
            if p is None:
                break
            ang = self.rand.next_float(TWO_PI)
            spd = 0.25 + self.rand.next_float(0.45)
            c = cols[self.rand.next_int(len(cols))]
            p.set((self.ship.rel_x + self.rand.next_signed_float(2.0),
                   self.ship.rel_y + self.rand.next_signed_float(2.0)),
                  math.cos(ang) * spd, math.sin(ang) * spd, 26,
                  c[0], c[1], c[2], 4)

    def _on_game_over(self):
        if self.mode == "turbo":
            self.progress.add_score(self.score)
            self.progress.save()

    def _finish_game_over(self):
        if self.mode == "turbo":
            self._set_state(LEADERBOARD)
        else:
            self._set_state(GAME_OVER)

    # ---- sector clear --------------------------------------------------
    def _confirm_upgrade(self):
        uid = self._upgrade_choices[self._upgrade_cursor]
        self._apply_upgrade(uid)
        self._show_briefing(self.sector + 1)

    def _sector_clear_update(self, dir_press, btn_press, mouse_click):
        if mouse_click:
            act = self._hit_test()
            if act and act.startswith("upgrade_"):
                self._upgrade_cursor = int(act.split("_")[1])
                self._confirm_upgrade()
                return
        if dir_press & (DIR_UP | DIR_LEFT):
            self._upgrade_cursor = (self._upgrade_cursor - 1) % len(self._upgrade_choices)
        if dir_press & (DIR_DOWN | DIR_RIGHT):
            self._upgrade_cursor = (self._upgrade_cursor + 1) % len(self._upgrade_choices)
        if btn_press & BTN_A:
            self._confirm_upgrade()

    # ---- game over / campaign complete ---------------------------------
    def _game_over_update(self, btn_press, mouse_click):
        act = None
        if mouse_click:
            act = self._hit_test()
        elif btn_press & BTN_A:
            act = "tentar_novo" if self.mode == "campaign" else "menu"
        if act == "tentar_novo":
            self.start_sector(self.sector)
        elif act == "menu":
            self._set_state(LEADERBOARD if self.mode == "turbo" else MENU)

    def _campaign_complete_update(self, btn_press, mouse_click):
        if btn_press & BTN_A or (mouse_click and self._hit_test() == "continuar"):
            self._set_state(MENU)

    def _achievements_update(self, btn_press, mouse_click):
        if btn_press & BTN_A or mouse_click:
            self._set_state(MENU)

    # ---- paused / confirm quit -----------------------------------------
    def _leave_phase(self):
        self.audio.halt_bgm()
        self.audio.disable_se()
        self._set_state(SECTOR_SELECT if self.mode == "campaign" else LEADERBOARD)

    def _paused_update(self, dir_press, btn_press, mouse_click):
        if mouse_click:
            act = self._hit_test()
            if act == "resume":
                self._set_state(PLAY)
                return
            if act == "sair_fase":
                self._leave_phase()
                return
        if dir_press & (DIR_UP | DIR_DOWN | DIR_LEFT | DIR_RIGHT):
            self.pause_cursor = 1 - self.pause_cursor
        if btn_press & BTN_A:
            if self.pause_cursor == 0:
                self._set_state(PLAY)
            else:
                self._leave_phase()

    def _confirm_quit_update(self, dir_press, btn_press, mouse_click):
        if mouse_click:
            act = self._hit_test()
            if act == "sim":
                self.quit_requested = True
                return
            if act == "nao":
                self._set_state(MENU)
                return
        if dir_press & (DIR_UP | DIR_DOWN | DIR_LEFT | DIR_RIGHT):
            self.quit_cursor = 1 - self.quit_cursor
        if btn_press & BTN_A:
            if self.quit_cursor == 0:
                self.quit_requested = True
            else:
                self._set_state(MENU)

    # ---------------------------------------------------------------- collisions
    def _check_collisions(self):
        shots = self.shots.items
        enemies = self.enemies.items
        bullets = self.bullets.items
        for shot in shots:
            if not shot.exists or shot.in_charge:
                continue
            for enemy in enemies:
                if not enemy.exists or enemy.passed:
                    continue
                hit_w = 2.0 if enemy.spec.is_boss else 1.2
                if enemy.spec.final:
                    hit_w = 2.6
                dx = abs(enemy.pos_x - shot.pos_x)
                if dx > PI:
                    dx = TWO_PI - dx
                dy = abs(enemy.pos_y - shot.pos_y)
                if dx <= hit_w and dy <= hit_w:
                    if enemy.hit(shot.damage):
                        self.combo += 1
                        self.combo_timer = 120
                        self.max_combo = max(self.max_combo, self.combo)
                        combo_mult = 1.0 + min(self.combo, 20) * 0.05
                        self.add_score(int(enemy.spec.score * shot.multiplier * combo_mult))
                        self._explode_enemy(enemy)
                        self.ship.rank_up(enemy.spec.is_boss)
                        self.run_kills += 1
                        self.progress.data["total_kills"] += 1
                        if self.progress.data["total_kills"] >= 1:
                            self._unlock_achievement("primeiro_abate")
                        if self.progress.data["total_kills"] >= 100:
                            self._unlock_achievement("cem_abates")
                        if enemy.spec.is_boss:
                            self._unlock_achievement("cacador_chefes")
                    else:
                        self.audio.play_se("hit.wav")
                    if shot.charge:
                        shot.multiplier += 1
                    else:
                        shot.exists = False
                    break
            if shot.exists and shot.charge:
                for b in bullets:
                    if not b.exists:
                        continue
                    dx = abs(b.pos_x - shot.pos_x)
                    if dx > PI:
                        dx = TWO_PI - dx
                    if dx < 0.4 and abs(b.pos_y - shot.pos_y) < 3.0:
                        b.exists = False
        for b in bullets:
            if b.exists and self.ship.check_bullet_hit(b.ppx, b.ppy, b.pos_x, b.pos_y):
                b.exists = False

    def _explode_enemy(self, enemy):
        col = enemy.spec.mesh_color or (1.0, 0.6, 0.3)
        # Fragment burst in the enemy's colour.
        for _ in range(36):
            p = self.particles.get()
            if p is None:
                break
            p.set((enemy.pos_x, enemy.pos_y),
                  self.rand.next_signed_float(0.5), self.rand.next_signed_float(0.5),
                  26, col[0], col[1], col[2], 4)
        # Bright white flash core.
        for _ in range(8):
            p = self.particles.get()
            if p is None:
                break
            p.set((enemy.pos_x, enemy.pos_y),
                  self.rand.next_signed_float(0.15), self.rand.next_signed_float(0.15),
                  12, 1.0, 1.0, 1.0, 6)
        if enemy.spec.kind == 0:
            self.audio.play_se("small_dest.wav")
        elif enemy.spec.kind == 1:
            self.audio.play_se("middle_dest.wav")
        else:
            self.audio.play_se("boss_dest.wav")
            self.ship.screen_shake_cnt = 56
            self.ship.screen_shake_intense = 0.064

    # ---------------------------------------------------------------- draw
    def _ensure_overlay(self, w, h):
        if self._overlay is None or self._overlay.get_size() != (w, h):
            self._overlay = pygame.Surface((w, h), pygame.SRCALPHA)
            if self._hud_tex is not None:
                buf = np.zeros(1, dtype=np.uint32)
                buf[0] = self._hud_tex.tex
                glDeleteTextures(1, buf)
            self._hud_tex = glrender.Texture2D(w, h)

    def draw(self, surface):
        self._hit_targets = []
        w, h = surface.get_size()
        self._ensure_overlay(w, h)
        glViewport(0, 0, w, h)
        glrender.clear()

        if self.state in (MENU, SECTOR_SELECT, SETTINGS, LEADERBOARD, BRIEFING,
                          CAMPAIGN_COMPLETE, ACHIEVEMENTS_SCREEN, CONFIRM_QUIT):
            # 2D screens over an animated 3D tunnel backdrop.
            self._draw_backdrop_3d(w, h)
            self._overlay.fill((0, 0, 0, 0))
            self._bg_gradient(self._overlay)
            self._draw_2d(self._overlay)
            glrender.set_ortho_2d(w, h)
            glrender.additive(False)
            self._hud_tex.upload(self._overlay)
            self._hud_tex.draw(w, h)
        else:
            # 3D scene (hardware-accelerated, anti-aliased, additive glow).
            glrender.set_projection(w, h)
            eye, center, up = self.ship.eye_center_up()
            glrender.set_modelview(eye, center, up)
            dim = config.TUNNEL_DIM
            lr = (self.stage.line_rgb[0] * dim, self.stage.line_rgb[1] * dim,
                  self.stage.line_rgb[2] * dim)
            pr = (self.stage.poly_rgb[0] * dim, self.stage.poly_rgb[1] * dim,
                  self.stage.poly_rgb[2] * dim)
            self.tunnel.draw_gl(lr, pr, self.stage.dark_line_ratio)
            self._draw_portal_gl()
            self.particles.draw_gl(self.tunnel)
            self.powerups.draw_gl(self.tunnel)
            self.enemies.draw_gl(self.tunnel)
            self.ship.draw_gl()
            self.bullets.draw_gl(self.tunnel)
            self.shots.draw_gl(self.tunnel)
            # HUD / overlays (software) drawn as a texture on top.
            self._overlay.fill((0, 0, 0, 0))
            draw_hud(self._overlay, pygame, self.fonts, self, self.ship, self.opts)
            if self.state == SECTOR_CLEAR:
                self._draw_sector_clear(self._overlay)
            elif self.state == GAME_OVER:
                self._draw_game_over(self._overlay)
            elif self.state == PAUSED:
                self._draw_paused(self._overlay)
            glrender.set_ortho_2d(w, h)
            glrender.additive(False)
            self._hud_tex.upload(self._overlay)
            self._hud_tex.draw(w, h)

        self._apply_brightness_fade_gl(w, h)

    def _draw_backdrop_3d(self, w, h):
        """Slow auto-pilot flight through the tunnel behind the 2D menus."""
        if self.tunnel.torus is None:
            self.stage.torus.create(12345)
            self.tunnel.start(self.stage.torus)
        self._menu_scroll = getattr(self, "_menu_scroll", 0.0) + 0.45
        deg = self._menu_scroll * 0.004
        self.tunnel.go_to_next_slice(1)
        self.tunnel.set_ship_pos(deg, 0.0, self._menu_scroll)
        self.tunnel.set_slices()
        glrender.set_projection(w, h)
        sx, sy, spx = self.ship.rel_x, self.ship.rel_y, self.ship.eye_x
        self.ship.rel_x = 0.0
        self.ship.rel_y = 4.0
        self.ship.eye_x = deg
        eye, center, up = self.ship.eye_center_up()
        self.ship.rel_x, self.ship.rel_y, self.ship.eye_x = sx, sy, spx
        glrender.set_modelview(eye, center, up)
        self.tunnel.draw_gl((0.10, 0.30, 0.55), (0.08, 0.24, 0.45), 0.5)

    def _draw_portal_gl(self):
        """Finish-line portal: a rotating vortex ring in front of the ship."""
        if self.portal_dist < 0 and self.portal_anim <= 0:
            return
        rel = self.portal_dist if self.portal_dist >= 0 else 0.0
        si, o = self.tunnel.calc_index(rel + self.tunnel.ship_idx + self.tunnel.ship_ofs)
        if si < 0 or si >= config.DEPTH_NUM - 1:
            return
        sl = self.tunnel.slices[si]
        ns = self.tunnel.slices[si + 1]
        d1 = sl.d1 * (1 - o) + ns.d1 * o
        d2 = sl.d2 * (1 - o) + ns.d2 * o
        cx = sl.center_pos.x * (1 - o) + ns.center_pos.x * o
        cy = sl.center_pos.y * (1 - o) + ns.center_pos.y * o
        cz = sl.center_pos.z * (1 - o) + ns.center_pos.z * o
        t = pygame.time.get_ticks() * 0.004
        r = 17.0
        lr_, lg_, lb_ = self.stage.line_rgb
        pulse = 0.55 + 0.45 * math.sin(pygame.time.get_ticks() * 0.01)
        cr = min(1.0, max(0.4, lr_) * pulse + 0.25)
        cg = min(1.0, max(0.4, lg_) * pulse + 0.25)
        cb = min(1.0, max(0.4, lb_) * pulse + 0.25)

        def pt(a, rad):
            x = math.sin(a) * rad
            y = math.cos(a) * rad
            z = 0.0
            cy1, sy1 = math.cos(d1), math.sin(d1)
            x, z = x * cy1 + z * sy1, -x * sy1 + z * cy1
            cx2, sx2 = math.cos(d2), math.sin(d2)
            y, z = y * cx2 - z * sx2, y * sx2 + z * cx2
            return (x + cx, y + cy, z + cz)

        glrender.additive(True)
        # Vortex disc (translucent fan).
        n = 20
        glColor4f(cr, cg, cb, 0.30)
        glBegin(GL_TRIANGLE_FAN)
        glVertex3f(cx, cy, cz)
        for k in range(n + 1):
            glVertex3f(*pt(k * TWO_PI / n + t, r))
        glEnd()
        # Rotating spokes.
        glColor4f(cr, cg, cb, 0.75)
        glBegin(GL_LINES)
        for k in range(4):
            a = k * PI / 4 + t * 1.5
            glVertex3f(*pt(a, r))
            glVertex3f(*pt(a + PI, r))
        glEnd()
        # Outer bright ring (counter-rotating).
        glColor4f(1.0, 1.0, 1.0, 0.9)
        glBegin(GL_LINE_LOOP)
        for k in range(n):
            glVertex3f(*pt(k * TWO_PI / n - t, r))
        glEnd()
        # Inner ring.
        glColor4f(cr, cg, cb, 1.0)
        glBegin(GL_LINE_LOOP)
        for k in range(16):
            glVertex3f(*pt(k * TWO_PI / 16 + t * 1.7, r * 0.55))
        glEnd()

    def _apply_brightness_fade_gl(self, w, h):
        glrender.set_ortho_2d(w, h)
        glrender.additive(False)
        b = self.opts.brightness
        if b < 0.999:
            glColor4f(0, 0, 0, 1.0 - b)
            glBegin(GL_QUADS)
            glVertex2f(0, 0)
            glVertex2f(w, 0)
            glVertex2f(w, h)
            glVertex2f(0, h)
            glEnd()
        # White flash when crossing the finish portal.
        if self.portal_anim >= 98:
            a = (self.portal_anim - 98) / 12.0 * 0.7
            glColor4f(1, 1, 1, a)
            glBegin(GL_QUADS)
            glVertex2f(0, 0)
            glVertex2f(w, 0)
            glVertex2f(w, h)
            glVertex2f(0, h)
            glEnd()
        # Red flash when the boss first appears.
        if self.boss_warn >= 105:
            a = (self.boss_warn - 105) / 15.0 * 0.5
            glColor4f(1, 0.25, 0.25, a)
            glBegin(GL_QUADS)
            glVertex2f(0, 0)
            glVertex2f(w, 0)
            glVertex2f(w, h)
            glVertex2f(0, h)
            glEnd()
        self.fade = min(1.0, self.fade + 0.06)
        if self.fade < 1.0:
            glColor4f(0, 0, 0, 1.0 - self.fade)
            glBegin(GL_QUADS)
            glVertex2f(0, 0)
            glVertex2f(w, 0)
            glVertex2f(w, h)
            glVertex2f(0, h)
            glEnd()

    # ---- 2D screens -----------------------------------------------------
    def _draw_2d(self, surface):
        fn = {
            MENU: self._draw_menu,
            SECTOR_SELECT: self._draw_sector_select,
            SETTINGS: self._draw_settings,
            LEADERBOARD: self._draw_leaderboard,
            BRIEFING: self._draw_briefing,
            CAMPAIGN_COMPLETE: self._draw_campaign_complete,
            ACHIEVEMENTS_SCREEN: self._draw_achievements,
            CONFIRM_QUIT: self._draw_confirm_quit,
        }.get(self.state)
        if fn:
            fn(surface)

    def _draw_menu(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        # Title with a soft pulse.
        pulse = 0.5 + 0.5 * math.sin(pygame.time.get_ticks() * 0.004)
        self._glow_text(surface, "TURBO THRUSTER", int(62 * s), cx, h * 0.12, "center",
                        (int(150 + 70 * pulse), 240, 255))
        self._t(surface, "Uma campanha pelo Coracao do Toro", int(17 * s), cx,
                h * 0.24, "center", (160, 200, 220))
        items = self._menu_items()
        y0 = h * 0.44
        for i, (label, action) in enumerate(items):
            selected = i == self.menu_cursor
            color = (255, 240, 140) if selected else (215, 222, 232)
            prefix = "> " if selected else "  "
            self._button(surface, prefix + label, int(30 * s), cx, y0 + i * 68 * s,
                         "center", color, action=action, boxed=True)
        self._t(surface, "MOUSE ou SETAS: escolher   Z/Enter ou CLIQUE: confirmar   Esc: sair",
                int(16 * s), cx, h * 0.90, "center", (130, 200, 235))
        self._t(surface, "v" + __version__, int(12 * s), w - 12 * s, h - 8 * s,
                "bottomright", (90, 100, 115))
        self._t(surface, "Abates totais: %d" % self.progress.data.get("total_kills", 0),
                int(12 * s), 12 * s, h - 8 * s, "bottomleft", (90, 100, 115))
        if not pygame.key.get_focused():
            self._t(surface, ">> CLIQUE NA JANELA PARA ATIVAR O TECLADO <<",
                    int(18 * s), cx, h * 0.95, "center", (255, 170, 90))

    def _draw_sector_select(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        self._glow_text(surface, "CAMPANHA", int(38 * s), cx, h * 0.08, "center",
                        (150, 240, 255))
        self._t(surface, "Escolha um setor desbloqueado", int(15 * s), cx, h * 0.15,
                "center", (150, 170, 190))
        unlocked = self.progress.unlocked_sector
        per_row = 4
        col_w = w / (per_row + 0.5)
        row_h = 82 * s
        for i in range(campaign.SECTOR_COUNT):
            row = i // per_row
            col = i % per_row
            x = cx + (col - (per_row - 1) / 2) * col_w
            y = h * 0.23 + row * row_h
            locked = i >= unlocked
            selected = i == self.sector_select_cursor
            if locked:
                self._t(surface, "[X]", int(18 * s), x, y, "center", (75, 80, 92))
                self._t(surface, "Setor %02d" % (i + 1), int(13 * s), x, y + 26 * s,
                        "center", (75, 80, 92))
            else:
                sec = campaign.SECTORS[i]
                colr = tuple(int(c * 255) for c in sec.line)
                label = "%02d  %s" % (i + 1, sec.name)
                if selected:
                    label = "> " + label
                self._button(surface, label, int(22 * s), x, y, "center", colr,
                             action="sector_%d" % i, boxed=True)
                # Accent dot in the sector's colour.
                pygame.draw.circle(surface, colr, (int(x - 108 * s), int(y)), int(5 * s))
        # Modo Turbo entry.
        ty = h * 0.80
        turbo_sel = self.sector_select_cursor == campaign.SECTOR_COUNT
        if self.progress.turbo_unlocked:
            color = (255, 200, 80) if turbo_sel else (230, 190, 90)
            label = ("> " if turbo_sel else "") + "MODO TURBO"
            self._button(surface, label, int(30 * s), cx, ty, "center", color,
                         action="turbo", boxed=True)
            self._t(surface, "Infinito — acumule pontos", int(13 * s), cx, ty + 36 * s,
                    "center", (150, 150, 150))
        else:
            self._t(surface, "MODO TURBO  [BLOQUEADO]", int(26 * s), cx, ty, "center",
                    (80, 85, 95))
            self._t(surface, "Conclua a campanha para desbloquear", int(13 * s), cx,
                    ty + 36 * s, "center", (100, 105, 115))
        self._t(surface, "SETAS ou MOUSE: escolher   Z/Enter ou CLIQUE: iniciar   Esc: voltar",
                int(15 * s), cx, h * 0.94, "center", (130, 200, 235))

    def _draw_settings(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        self._glow_text(surface, "CONFIGURACOES", int(32 * s), cx, h * 0.05, "center",
                        (150, 240, 255))

        # Tab bar.
        tabs = self._settings_tab_items()
        tab_names = [t[0] for t in tabs]
        n = len(tab_names)
        tab_w = 200 * s
        for i, name in enumerate(tab_names):
            x = cx + (i - (n - 1) / 2) * tab_w
            y = h * 0.13
            sel = i == self.settings_tab
            color = (255, 240, 140) if sel else (170, 185, 205)
            self._button(surface, name, int(22 * s), x, y, "center", color,
                         action="tab_%d" % i, boxed=True)

        st = self.progress.data["settings"]
        items = tabs[self.settings_tab][1]

        def value_of(key):
            if key == "resolution":
                r = st.get("resolution", [1280, 720])
                return "%dx%d" % (r[0], r[1])
            if key == "fullscreen":
                return "SIM" if st["fullscreen"] else "NAO"
            if key == "effects":
                return st.get("effects", "alto").upper()
            if key in ("music_volume", "sfx_volume"):
                return "%d%%" % int(st[key] * 100)
            if key == "brightness":
                return "%d%%" % int(st[key] * 100)
            return ""

        labels = {
            "resolution": "RESOLUCAO", "fullscreen": "TELA CHEIA",
            "effects": "EFEITOS", "music_volume": "VOL. MUSICA",
            "sfx_volume": "VOL. EFEITOS", "brightness": "BRILHO",
        }
        y0 = h * 0.28
        row_h = 54 * s
        for i, key in enumerate(items):
            selected = i == self.settings_cursor
            color = (255, 240, 140) if selected else (215, 222, 232)
            if self.settings_tab == 2:
                label = CONTROL_LABELS.get(key, key)
                if self._listening_action == key:
                    val = "PRESSIONE UMA TECLA..."
                else:
                    val = key_name(self.controls.get(key, pygame.K_UNKNOWN))
            else:
                label = labels.get(key, key)
                val = value_of(key)
            self._button(surface, label, int(22 * s), cx - 170 * s, y0 + i * row_h,
                         "midleft", color, action="set_%d" % i)
            self._button(surface, val, int(22 * s), cx + 170 * s, y0 + i * row_h,
                         "midright", color, action="setval_%d" % i)

        if self.settings_tab == 2:
            self._t(surface, "Selecione a acao e pressione Enter/CLIQUE, depois a tecla desejada",
                    int(14 * s), cx, h * 0.88, "center", (150, 160, 170))
        self._t(surface, "Tab: mudar aba   Cima/Baixo: escolher   Esq/Dir ou CLIQUE: mudar   Esc: voltar",
                int(14 * s), cx, h * 0.95, "center", (130, 200, 235))

    def _draw_leaderboard(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        self._glow_text(surface, "MODO TURBO", int(38 * s), cx, h * 0.10, "center",
                        (255, 200, 80))
        self._t(surface, "MELHORES PONTUACOES", int(18 * s), cx, h * 0.18, "center",
                (180, 190, 200))
        board = self.progress.get_leaderboard()
        y0 = h * 0.28
        if not board:
            self._t(surface, "Sem pontuacoes ainda.", int(18 * s), cx, y0, "center",
                    (150, 150, 150))
        else:
            for i, entry in enumerate(board[:8]):
                line = "%2d.  %s" % (i + 1, entry["score"])
                color = (255, 220, 120) if i == 0 else (210, 215, 225)
                self._t(surface, line, int(22 * s), cx, y0 + i * 44 * s, "center", color)
        self._button(surface, "JOGAR", int(26 * s), cx, h * 0.84, "center",
                     (255, 220, 120), action="jogar")
        self._t(surface, "Z/Enter ou CLIQUE para jogar   Esc: voltar", int(13 * s), cx,
                h * 0.92, "center", (130, 200, 235))

    def _draw_briefing(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        sec = campaign.SECTORS[self.sector]
        colr = tuple(int(c * 255) for c in sec.line)
        self._t(surface, "SETOR %d" % (self.sector + 1), int(24 * s), cx, h * 0.16,
                "center", (180, 200, 220))
        self._glow_text(surface, sec.name, int(52 * s), cx, h * 0.30, "center", colr)
        self._t(surface, '"%s"' % sec.subtitle, int(17 * s), cx, h * 0.44, "center",
                (200, 200, 210))
        # Boss preview.
        boss = sec.boss
        bcol = tuple(int(c * 255) for c in boss.get("color", (1.0, 1.0, 1.0)))
        self._t(surface, "CHEFE DO SETOR", int(14 * s), cx, h * 0.54, "center",
                (150, 160, 170))
        pygame.draw.circle(surface, bcol, (int(cx - 90 * s), int(h * 0.54)), int(8 * s))
        self._t(surface, "Resistencia %d" % boss.get("shield", 30), int(14 * s),
                cx - 70 * s, h * 0.54, "midleft", bcol)
        self._t(surface, "Corrida continua do inicio ao portal de chegada",
                int(14 * s), cx, h * 0.62, "center", (150, 160, 170))
        self._t(surface, "WASD move   Z/mouse atira   X/mouse-direito carrega   E dash   Q bomba",
                int(13 * s), cx, h * 0.70, "center", (140, 155, 170))
        self._button(surface, "INICIAR SETOR", int(28 * s), cx, h * 0.80, "center",
                     (255, 240, 140), action="iniciar", boxed=True)
        self._t(surface, "Z/Enter ou CLIQUE para comecar   Esc: voltar", int(13 * s), cx,
                h * 0.90, "center", (130, 200, 235))

    def _draw_sector_clear(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        sec = campaign.SECTORS[self.sector]
        colr = tuple(int(c * 255) for c in sec.line)
        ov = pygame.Surface((w, h), pygame.SRCALPHA)
        ov.fill((0, 0, 0, 150))
        surface.blit(ov, (0, 0))
        self._glow_text(surface, "SETOR %d CONCLUIDO!" % (self.sector + 1),
                        int(34 * s), cx, h * 0.12, "center", colr)
        secs = max(0, self.time // 1000)
        stats = [
            ("PONTOS", str(self.score)),
            ("TEMPO", "%d:%02d" % (secs // 60, secs % 60)),
            ("ABATES", str(self.run_kills)),
            ("MELHOR COMBO", "x%d" % self.max_combo),
        ]
        y0 = h * 0.22
        for i, (label, value) in enumerate(stats):
            x = cx + (i - 1.5) * 180 * s
            self._t(surface, label, int(13 * s), x, y0, "center", (150, 165, 185))
            self._t(surface, value, int(24 * s), x, y0 + 20 * s, "center",
                    (255, 255, 255))
        self._t(surface, "Escolha uma melhoria:", int(20 * s), cx, h * 0.40, "center",
                (255, 240, 140))
        y1 = h * 0.50
        for i, uid in enumerate(self._upgrade_choices):
            up = campaign.UPGRADES[uid]
            selected = i == self._upgrade_cursor
            color = (255, 240, 140) if selected else (215, 222, 232)
            label = ("> " if selected else "  ") + up["name"] + "  -  " + up["desc"]
            self._button(surface, label, int(21 * s), cx, y1 + i * 52 * s, "center",
                         color, action="upgrade_%d" % i, boxed=True)
        self._t(surface, "Esc: voltar a selecao de setores", int(13 * s), cx,
                h * 0.88, "center", (130, 200, 235))

    def _draw_game_over(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        ov = pygame.Surface((w, h), pygame.SRCALPHA)
        ov.fill((0, 0, 0, 160))
        surface.blit(ov, (0, 0))
        self._glow_text(surface, "FIM DE JOGO", int(44 * s), cx, h * 0.16, "center",
                        (255, 120, 120))
        secs = max(0, self.time // 1000)
        stats = [
            ("PONTOS", str(self.score)),
            ("TEMPO", "%d:%02d" % (secs // 60, secs % 60)),
            ("ABATES", str(self.run_kills)),
            ("MELHOR COMBO", "x%d" % self.max_combo),
        ]
        y0 = h * 0.28
        for i, (label, value) in enumerate(stats):
            x = cx + (i - 1.5) * 180 * s
            self._t(surface, label, int(13 * s), x, y0, "center", (150, 165, 185))
            self._t(surface, value, int(26 * s), x, y0 + 20 * s, "center",
                    (255, 255, 255))
        if self.mode == "campaign":
            opts = [("TENTAR DE NOVO", "tentar_novo"), ("MENU", "menu")]
        else:
            opts = [("PLACAR", "menu")]
        y1 = h * 0.52
        for i, (label, action) in enumerate(opts):
            self._button(surface, label, int(26 * s), cx, y1 + i * 62 * s, "center",
                         (255, 240, 140), action=action, boxed=True)
        self._t(surface, "Z/Enter ou CLIQUE para escolher", int(13 * s), cx,
                h * 0.78, "center", (130, 200, 235))

    def _draw_campaign_complete(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        self._glow_text(surface, "CAMPANHA CONCLUIDA!", int(40 * s), cx, h * 0.16,
                        "center", (255, 230, 120))
        self._t(surface, "Voce dominou o Coracao do Toro.", int(18 * s), cx, h * 0.28,
                "center", (210, 215, 225))
        self._t(surface, "MODO TURBO DESBLOQUEADO", int(24 * s), cx, h * 0.38, "center",
                (255, 170, 60))
        self._t(surface, "Corra sem fim e acumule pontos!", int(15 * s), cx, h * 0.46,
                "center", (170, 180, 190))
        total_kills = self.progress.data.get("total_kills", 0)
        n_ach = len(self.progress.get_achievements())
        self._t(surface, "Abates totais: %d    Conquistas: %d/%d" %
                (total_kills, n_ach, len(ACHIEVEMENTS)),
                int(16 * s), cx, h * 0.56, "center", (200, 205, 215))
        self._button(surface, "CONTINUAR", int(26 * s), cx, h * 0.70, "center",
                     (255, 240, 140), action="continuar", boxed=True)

    def _draw_paused(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        ov = pygame.Surface((w, h), pygame.SRCALPHA)
        ov.fill((0, 0, 0, 160))
        surface.blit(ov, (0, 0))
        self._glow_text(surface, "PAUSADO", int(42 * s), cx, h * 0.20, "center",
                        (255, 240, 140))
        if self.mode == "campaign":
            sec = campaign.SECTORS[self.sector]
            colr = tuple(int(c * 255) for c in sec.line)
            self._t(surface, "Setor %d - %s" % (self.sector + 1, sec.name),
                    int(16 * s), cx, h * 0.32, "center", colr)
        opts = [("CONTINUAR", "resume"), ("SAIR DA FASE", "sair_fase")]
        y0 = h * 0.44
        for i, (label, action) in enumerate(opts):
            selected = i == self.pause_cursor
            color = (255, 240, 140) if selected else (215, 222, 232)
            self._button(surface, ("> " if selected else "  ") + label, int(28 * s), cx,
                         y0 + i * 64 * s, "center", color, action=action, boxed=True)
        self._t(surface, "Setas ou mouse: escolher   Enter: confirmar   Esc: continuar",
                int(14 * s), cx, h * 0.74, "center", (130, 200, 235))

    def _draw_achievements(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        self._glow_text(surface, "CONQUISTAS", int(36 * s), cx, h * 0.10, "center",
                        (255, 220, 120))
        unlocked = set(self.progress.get_achievements())
        total_kills = self.progress.data.get("total_kills", 0)
        self._t(surface, "Abates totais: %d" % total_kills, int(15 * s), cx, h * 0.20,
                "center", (180, 190, 200))
        y0 = h * 0.30
        for i, (aid, title) in enumerate(ACHIEVEMENTS.items()):
            done = aid in unlocked
            color = (120, 255, 150) if done else (130, 140, 155)
            mark = "[OK]" if done else "[  ]"
            self._t(surface, "%s  %s" % (mark, title), int(22 * s), cx, y0 + i * 46 * s,
                    "center", color)
        self._t(surface, "Esc: voltar", int(14 * s), cx, h * 0.90, "center",
                (130, 200, 235))

    def _draw_confirm_quit(self, surface):
        w, h = surface.get_size()
        s = h / 480.0
        cx = w / 2
        self._t(surface, "SAIR DO JOGO?", int(40 * s), cx, h * 0.32, "center",
                (255, 180, 140))
        opts = [("SIM", "sim"), ("NAO", "nao")]
        for i, (label, action) in enumerate(opts):
            selected = i == self.quit_cursor
            color = (255, 240, 140) if selected else (215, 222, 232)
            self._button(surface, ("> " if selected else "  ") + label, int(28 * s),
                         cx + (i - 0.5) * 220 * s, h * 0.48, "center", color,
                         action=action, boxed=True)
        self._t(surface, "Setas ou mouse: escolher   Enter: confirmar   Esc: voltar",
                int(14 * s), cx, h * 0.66, "center", (130, 200, 235))

    # ---------------------------------------------------------------- text helper
    def _bg_gradient(self, surface, top=(10, 14, 34), bottom=(2, 2, 10)):
        w, h = surface.get_size()
        key = (w, h, top, bottom)
        grad = self._bg_cache.get(key)
        if grad is None:
            grad = pygame.Surface((w, h), pygame.SRCALPHA)
            step = max(1, h // 64)
            for y in range(0, h, step):
                t = y / max(1, h - 1)
                c = (int(top[0] * (1 - t) + bottom[0] * t),
                     int(top[1] * (1 - t) + bottom[1] * t),
                     int(top[2] * (1 - t) + bottom[2] * t),
                     208)
                pygame.draw.rect(grad, c, (0, y, w, step + 1))
            self._bg_cache[key] = grad
        surface.blit(grad, (0, 0))

    def _button(self, surface, txt, size, x, y, anchor="topleft", color=(255, 255, 255),
                hover_color=(255, 255, 170), action=None, pad=8, boxed=False):
        """Render a clickable button; register its hitbox and highlight on hover."""
        font = self.fonts.get(pygame, int(size))
        base = font.render(txt, True, color)
        rect = base.get_rect()
        setattr(rect, anchor, (int(x), int(y)))
        hit = rect.inflate(pad * 2, pad * 2)
        hover = action is not None and hit.collidepoint(self.mouse_pos)
        if hover:
            color = hover_color
        img = font.render(txt, True, color)
        rect2 = img.get_rect()
        setattr(rect2, anchor, (int(x), int(y)))
        if boxed:
            box = hit.inflate(16, 10)
            bg = pygame.Surface((box.width, box.height), pygame.SRCALPHA)
            if hover:
                glow = pygame.Surface((box.width + 10, box.height + 10), pygame.SRCALPHA)
                pygame.draw.rect(glow, (110, 165, 255, 70), glow.get_rect(), 3,
                                 border_radius=14)
                surface.blit(glow, (box.x - 5, box.y - 5))
                bg.fill((50, 68, 114, 195))
                pygame.draw.rect(bg, (175, 220, 255, 255), bg.get_rect(), 2,
                                 border_radius=10)
            else:
                bg.fill((22, 30, 52, 165))
                pygame.draw.rect(bg, (95, 125, 170, 205), bg.get_rect(), 1,
                                 border_radius=10)
            surface.blit(bg, box.topleft)
        elif hover:
            bg = pygame.Surface((hit.width, hit.height), pygame.SRCALPHA)
            bg.fill((70, 90, 130, 80))
            surface.blit(bg, hit.topleft)
        shadow = font.render(txt, True, (0, 0, 0))
        surface.blit(shadow, (rect2.x + 2, rect2.y + 2))
        surface.blit(img, rect2)
        if action is not None:
            self._hit_targets.append((hit, action))
        return rect2

    def _hit_test(self):
        for rect, action in self._hit_targets:
            if rect.collidepoint(self.mouse_pos):
                return action
        return None

    def _t(self, surface, txt, size, x, y, anchor="topleft", color=(255, 255, 255)):
        font = self.fonts.get(pygame, int(size))
        img = font.render(txt, True, color)
        rect = img.get_rect()
        setattr(rect, anchor, (int(x), int(y)))
        shadow = font.render(txt, True, (0, 0, 0))
        surface.blit(shadow, (rect.x + 2, rect.y + 2))
        surface.blit(img, rect)

    def _glow_text(self, surface, txt, size, x, y, anchor="center",
                   color=(150, 240, 255)):
        font = self.fonts.get(pygame, int(size))
        img = font.render(txt, True, color)
        rect = img.get_rect()
        setattr(rect, anchor, (int(x), int(y)))
        glow_col = (max(0, color[0] // 3), max(0, color[1] // 3), max(0, color[2] // 3))
        for off, alpha in ((3, 80), (2, 130), (1, 180)):
            layer = font.render(txt, True, glow_col)
            layer.set_alpha(alpha)
            for dx, dy in ((off, off), (-off, off), (off, -off), (-off, -off),
                           (off, 0), (-off, 0), (0, off), (0, -off)):
                surface.blit(layer, (rect.x + dx, rect.y + dy))
        shadow = font.render(txt, True, (0, 0, 0))
        surface.blit(shadow, (rect.x + 2, rect.y + 2))
        surface.blit(img, rect)
        return rect

    # ---------------------------------------------------------------- loop
    def _focus_window(self):
        """Bring the game window to the foreground so keyboard input works."""
        try:
            if sys.platform == "win32":
                import ctypes
                user32 = ctypes.windll.user32
                hwnd = pygame.display.get_wm_info()["window"]
                user32.ShowWindow(hwnd, 9)  # SW_RESTORE
                user32.BringWindowToTop(hwnd)
                user32.SetForegroundWindow(hwnd)
                user32.SetActiveWindow(hwnd)
                user32.SetFocus(hwnd)
        except Exception:
            pass

    def run(self):
        flags = pygame.OPENGL | pygame.DOUBLEBUF | pygame.RESIZABLE
        if self.opts.fullscreen:
            flags |= pygame.FULLSCREEN
        vsync = 1 if self.opts.vsync else 0
        screen = pygame.display.set_mode((self.opts.width, self.opts.height), flags, vsync=vsync)
        pygame.display.set_caption("Turbo Thruster")
        glrender.init_gl(self.opts.width, self.opts.height)
        self._focus_window()
        self.init_audio()
        pygame.mouse.set_visible(True)
        clock = pygame.time.Clock()

        def read_input():
            keys = pygame.key.get_pressed()
            c = self.controls
            down = self._keys_down
            scans = self._scans_down

            def is_down(k, scan=None):
                if keys[k] or k in down:
                    return True
                return scan is not None and scan in scans

            dir_bits = 0
            if (is_down(c.get("up", pygame.K_w), 26) or is_down(pygame.K_UP)
                    or is_down(pygame.K_w, 26)):
                dir_bits |= DIR_UP
            if (is_down(c.get("down", pygame.K_s), 22) or is_down(pygame.K_DOWN)
                    or is_down(pygame.K_s, 22)):
                dir_bits |= DIR_DOWN
            if (is_down(c.get("left", pygame.K_a), 4) or is_down(pygame.K_LEFT)
                    or is_down(pygame.K_a, 4)):
                dir_bits |= DIR_LEFT
            if (is_down(c.get("right", pygame.K_d), 7) or is_down(pygame.K_RIGHT)
                    or is_down(pygame.K_d, 7)):
                dir_bits |= DIR_RIGHT
            btn_bits = 0
            a_keys = (c.get("shoot", pygame.K_z), pygame.K_LCTRL, pygame.K_RCTRL,
                      pygame.K_PERIOD, pygame.K_RETURN, pygame.K_SPACE)
            b_keys = (c.get("charge", pygame.K_x), pygame.K_LALT, pygame.K_RALT,
                      pygame.K_LSHIFT, pygame.K_RSHIFT, pygame.K_SLASH)
            if self.opts.reverse_keys:
                a_keys, b_keys = b_keys, a_keys
            if any(is_down(k) for k in a_keys) or 29 in scans:
                btn_bits |= BTN_A
            if any(is_down(k) for k in b_keys) or 27 in scans:
                btn_bits |= BTN_B
            return dir_bits, btn_bits

        running = True
        while running:
            pause_toggle = False
            mouse_click = False
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    running = False
                elif event.type == pygame.KEYDOWN:
                    self._keys_down.add(event.key)
                    if getattr(event, "scancode", None) is not None:
                        self._scans_down.add(event.scancode)
                    if self._listening_action is not None:
                        if event.key != pygame.K_ESCAPE:
                            self.controls[self._listening_action] = event.key
                            self.progress.data["settings"]["controls"] = dict(self.controls)
                        self._listening_action = None
                        continue
                    if event.key == pygame.K_ESCAPE:
                        self._back()
                    elif event.key == pygame.K_TAB and self.state == SETTINGS:
                        self._cycle_tab()
                    elif event.key == self.controls.get("pause", pygame.K_p) and self.state == PLAY:
                        pause_toggle = True
                    elif event.key == self.controls.get("dash", pygame.K_e) and self.state == PLAY:
                        self.ship.trigger_dash()
                    elif event.key == self.controls.get("bomb", pygame.K_q) and self.state == PLAY:
                        self.trigger_bomb()
                    elif event.key == pygame.K_F11:
                        self.opts.fullscreen = not self.opts.fullscreen
                        self.progress.data["settings"]["fullscreen"] = self.opts.fullscreen
                        self._recreate_window = True
                elif event.type == pygame.KEYUP:
                    self._keys_down.discard(event.key)
                    if getattr(event, "scancode", None) is not None:
                        self._scans_down.discard(event.scancode)
                elif event.type == pygame.WINDOWFOCUSLOST:
                    self._keys_down.clear()
                    self._scans_down.clear()
                elif event.type == pygame.MOUSEBUTTONDOWN and event.button == 1:
                    mouse_click = True

            if self.quit_requested:
                running = False
            if self._recreate_window:
                self._recreate_window = False
                flags = pygame.OPENGL | pygame.DOUBLEBUF | pygame.RESIZABLE
                if self.opts.fullscreen:
                    flags |= pygame.FULLSCREEN
                vsync = 1 if self.opts.vsync else 0
                screen = pygame.display.set_mode((self.opts.width, self.opts.height),
                                                 flags, vsync=vsync)
                glrender.init_gl(self.opts.width, self.opts.height)

            self.mouse_pos = pygame.mouse.get_pos()
            dir_bits, btn_bits = read_input()
            # In-game: left mouse button shoots, right button charges.
            if self.state == PLAY:
                mb = pygame.mouse.get_pressed()
                if mb[0]:
                    btn_bits |= BTN_A
                if mb[2]:
                    btn_bits |= BTN_B
            self.update(dir_bits, btn_bits, pause_toggle, mouse_click)
            if self.ach_timer > 0:
                self.ach_timer -= 1
            self.draw(screen)
            pygame.display.flip()
            clock.tick(config.FPS)

        self.progress.save()
        pygame.quit()
