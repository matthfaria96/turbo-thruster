#!/usr/bin/env python3
"""Turbo Thruster — cross-platform campaign + Turbo remake of Torus Trooper.

Usage:
    python tt.py [-res WIDTH HEIGHT] [-window] [-fullscreen] [-nosound]
                 [-brightness 0-100] [-reverse] [-vsync 0|1]

Controls:
    Move:        Arrow keys / WASD
    Shot:        Z / Left-Ctrl / .   (hold for auto-fire)
    Charge shot: X / Left-Alt / Shift / /   (hold, release to fire)
    Confirm:     Z / Enter / Space
    Back:        Esc
    Pause:       P
    Fullscreen:  F11
"""

import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")

import pygame  # noqa: E402

from turbothruster import config  # noqa: E402
from turbothruster.game import Game  # noqa: E402


def parse_args(argv):
    p = argparse.ArgumentParser(description="Turbo Thruster")
    p.add_argument("-res", nargs=2, type=int, metavar=("W", "H"),
                   help="window size")
    p.add_argument("-window", action="store_true", help="run in a window")
    p.add_argument("-fullscreen", action="store_true", help="run fullscreen")
    p.add_argument("-nosound", action="store_true", help="disable sound")
    p.add_argument("-brightness", type=int, default=None, metavar="N",
                   help="screen brightness 0-100")
    p.add_argument("-reverse", action="store_true",
                   help="swap shot and charge-shot keys")
    p.add_argument("-vsync", type=int, default=None, choices=(0, 1),
                   help="enable/disable vsync")
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv if argv is not None else sys.argv[1:])
    opts = config.Options()
    if args.res:
        opts.width = max(config.MIN_WIDTH, args.res[0])
        opts.height = max(config.MIN_HEIGHT, args.res[1])

    pygame.init()
    pygame.display.set_caption("Turbo Thruster")
    if args.nosound:
        opts.sound = False
    else:
        try:
            pygame.mixer.pre_init(44100, -16, 2, 512)
            pygame.mixer.init()
        except Exception:
            opts.sound = False

    game = Game(opts)

    # Apply explicit CLI overrides on top of the persisted settings.
    s = game.progress.data["settings"]
    if args.res:
        s["resolution"] = [opts.width, opts.height]
    if args.fullscreen:
        s["fullscreen"] = True
    elif args.window:
        s["fullscreen"] = False
    if args.brightness is not None:
        s["brightness"] = max(0, min(100, args.brightness)) / 100.0
    if args.vsync is not None:
        s["vsync"] = bool(args.vsync)
    game.opts.reverse_keys = args.reverse
    game.opts.sound = opts.sound
    game.apply_settings()

    game.run()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except SystemExit:
        raise
    except Exception:
        import traceback
        try:
            log = os.path.join(os.path.expanduser("~"), "turbo-thruster-crash.log")
            with open(log, "w") as f:
                traceback.print_exc(file=f)
        except Exception:
            pass
        traceback.print_exc()
        raise
