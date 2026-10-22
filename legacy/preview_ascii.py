"""Dev tool: ASCII-visualize a rendered PNG + pixel statistics."""
import os
import sys

os.environ["SDL_VIDEODRIVER"] = "dummy"
os.environ["SDL_AUDIODRIVER"] = "dummy"
os.environ["PYGAME_HIDE_SUPPORT_PROMPT"] = "1"

import pygame  # noqa: E402
import numpy as np  # noqa: E402


def analyze(path, cols=64, rows=30):
    surf = pygame.image.load(path)
    w, h = surf.get_size()
    rgb = pygame.surfarray.array3d(surf).astype(np.float32)  # (w, h, 3)
    lum = (rgb.sum(axis=2) / 3.0).T  # -> (h, w)
    nonblack = (lum > 8).sum()
    total = w * h
    ys, xs = np.nonzero(lum > 8)
    print("== %s  (%dx%d)" % (path, w, h))
    print("non-black pixels: %.2f%%" % (100.0 * nonblack / total))
    if len(xs):
        print("bbox x: %d..%d  y: %d..%d" % (xs.min(), xs.max(), ys.min(), ys.max()))
    # downsample to ascii
    chars = " .:-=+*#%@"
    out = []
    for ry in range(rows):
        y0 = int(ry * h / rows)
        y1 = int((ry + 1) * h / rows)
        line = []
        for rx in range(cols):
            x0 = int(rx * w / cols)
            x1 = int((rx + 1) * w / cols)
            block = lum[y0:y1, x0:x1]
            v = float(block.max()) if block.size else 0.0
            idx = min(len(chars) - 1, int(v / 256.0 * len(chars)))
            line.append(chars[idx])
        out.append("".join(line))
    print("\n".join(out))


if __name__ == "__main__":
    for p in sys.argv[1:]:
        analyze(p)
        print()
