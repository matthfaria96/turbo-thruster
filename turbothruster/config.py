"""Global constants and runtime options.

Values marked ``(original)`` are ported from the Torus Trooper source so the
feel and look stay faithful.  The widescreen behaviour is the one intentional
improvement: the vertical field of view is fixed to the classic 4:3 look and
the horizontal field of view expands with the aspect ratio ("hor+").
"""

import os
import sys

# ---------------------------------------------------------------------------
# Window / projection
# ---------------------------------------------------------------------------
DEFAULT_WIDTH = 1280
DEFAULT_HEIGHT = 720
MIN_WIDTH = 640
MIN_HEIGHT = 480

NEAR_PLANE = 0.1
FAR_PLANE = 1000.0

# The original uses glFrustum(-near, near, -near*h/w, near*h/w, ...), i.e. a
# fixed 90-degree *horizontal* FOV.  At the classic 4:3 aspect this yields
# tan(vertical-half-fov) = h/w = 0.75.  We fix that vertical FOV and let the
# horizontal FOV grow with the aspect ratio (correct widescreen "hor+").
TAN_HALF_FOV_V = 0.75

# Logical HUD resolution (the original draws the HUD in a fixed 640x480 view).
HUD_W = 640
HUD_H = 480

# ---------------------------------------------------------------------------
# Tunnel geometry (original)
# ---------------------------------------------------------------------------
DEPTH_NUM = 72
SHIP_IDX_OFS = 5
RAD_RATIO = 1.05
SLICE_DEPTH = 5.0
DEPTH_CHANGE_RATIO = 1.15
DEPTH_RATIO_MAX = 80.0
TORUS_LENGTH = 5000

MAX_POINT_NUM = 36
DEFAULT_POINT_NUM = 24
DEFAULT_RAD = 21.0

# Tunnel palette (original TUNNEL_COLOR_PATTERN_*).
TUNNEL_COLOR_PATTERN_POLY = [
    (0.7, 0.9, 1.0),
    (0.6, 1.0, 0.8),
    (0.9, 0.7, 0.6),
    (0.8, 0.8, 0.8),
    (0.5, 0.9, 0.9),
    (0.7, 0.9, 0.6),
    (0.8, 0.5, 0.9),
]
TUNNEL_COLOR_PATTERN_LINE = [
    (0.6, 0.7, 1.0),
    (0.4, 0.8, 0.6),
    (0.7, 0.5, 0.6),
    (0.6, 0.6, 0.6),
    (0.4, 0.7, 0.7),
    (0.6, 0.7, 0.5),
    (0.6, 0.4, 1.0),
]
TUNNEL_COLOR_CHANGE_INTERVAL = 60
# The tunnel is drawn darker than the entities so ships/enemies read clearly.
TUNNEL_DIM = 0.5

# ---------------------------------------------------------------------------
# Ship (original)
# ---------------------------------------------------------------------------
SPEED_DEFAULT = [0.4, 0.6, 0.8]
SPEED_MAX = [0.8, 1.2, 1.6]
ACCEL_RATIO = [0.002, 0.003, 0.004]
BANK_MAX_DEFAULT = [0.8, 1.0, 1.2]
OUT_OF_COURSE_BANK = 1.0
RELPOS_Y_MOVE = 0.1
RELPOS_MAX_Y = 10.0
IN_SIGHT_DEPTH_DEFAULT = 35.0
EYE_HEIGHT = 0.8
LOOKAT_HEIGHT = 0.9
HIT_WIDTH = 0.00025
FIRE_INTERVAL = 2
STAR_SHELL_INTERVAL = 7
GUNPOINT_WIDTH = 0.05

RESTART_CNT = 268
INVINCIBLE_CNT = 228

GRADE_NORMAL = 0
GRADE_HARD = 1
GRADE_EXTREME = 2
GRADE_NUM = 3
GRADE_LETTER = ["N", "H", "E"]
GRADE_STR = ["NORMAL", "HARD", "EXTREME"]

# ---------------------------------------------------------------------------
# In-game state / scoring (original InGameState)
# ---------------------------------------------------------------------------
DEFAULT_EXTEND_SCORE = 100000
MAX_EXTEND_SCORE = 500000
DEFAULT_TIME = 120000          # milliseconds of "time" (== your fuel/clock)
MAX_TIME = 120000
SHIP_DESTROYED_PENALTY_TIME = -15000
SHIP_DESTROYED_PENALTY_TIME_MSG = "-15 SEC."
EXTEND_TIME = 15000
EXTEND_TIME_MSG = "+15 SEC."
NEXT_ZONE_ADDITION_TIME = 30000
NEXT_ZONE_ADDITION_TIME_MSG = "+30 SEC."
NEXT_LEVEL_ADDITION_TIME = 45000
NEXT_LEVEL_ADDITION_TIME_MSG = "+45 SEC."
BEEP_START_TIME = 15000

# Frames-per-second target.  Original decrements time by 17 "ms" per frame at
# 60 Hz (~1020 ms of time per real second).
FPS = 60
TIME_DECREMENT_PER_FRAME = 17

# ---------------------------------------------------------------------------
# Enemy / stage (original)
# ---------------------------------------------------------------------------
# Rank at which a boss appears.  Lowered from the original [100, 160, 250] so
# each campaign sector's zones resolve quickly (a full 12-sector campaign stays
# ~30-40 minutes rather than hours).
BOSS_APP_RANK = [35, 55, 80]
LEVEL_UP_RATIO = 0.5
SPEED_CHANGE_RATIO = 0.2

# ---------------------------------------------------------------------------
# Shot (original)
# ---------------------------------------------------------------------------
SHOT_SPEED = 0.75
SHOT_RANGE_MIN = 2.0
SHOT_SIZE_MIN = 0.1
MAX_CHARGE = 90
SHOT_SIZE_RATIO = 0.15
SHOT_RANGE_RATIO = 0.5
CHARGE_RELEASE_RATIO = 0.25
MAX_MULTIPLIER = 100

# ---------------------------------------------------------------------------
# Runtime options
# ---------------------------------------------------------------------------
class Options:
    """Mutable runtime settings (parsed from argv and in-game keys)."""

    def __init__(self):
        self.width = DEFAULT_WIDTH
        self.height = DEFAULT_HEIGHT
        self.fullscreen = False
        self.brightness = 1.0      # 0..1
        self.sound = True
        self.reverse_keys = False  # swap shot / charge-shot keys
        self.vsync = True

    @property
    def asset_dir(self):
        # assets/ lives next to the package.  When frozen (PyInstaller), the
        # assets are bundled under the extraction dir (sys._MEIPASS).
        if getattr(sys, "frozen", False):
            base = getattr(sys, "_MEIPASS", os.path.dirname(sys.executable))
        else:
            base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        return os.path.join(base, "assets")
