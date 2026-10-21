"""Campaign definition: sectors, unique bosses, and ship upgrades."""


class Sector:
    def __init__(self, name, subtitle, poly, line, boss, zones=3):
        self.name = name
        self.subtitle = subtitle
        self.poly = tuple(poly)   # road fill colour (0..1)
        self.line = tuple(line)   # wireframe colour (0..1)
        self.boss = boss          # dict: colour / shield / speed / bits / fire
        self.zones = zones        # internal zones before the sector boss


# The 12-sector campaign.  Colours are intentionally saturated; each sector
# has a distinct palette and a unique (themed) boss.
SECTORS = [
    Sector("NEON GATE",
           "Um portal de luz na borda do Toro. Entre e acelere.",
           (0.05, 0.35, 1.0), (0.3, 0.85, 1.0),
           {"color": (0.2, 0.9, 1.0), "shield": 40, "speed": 0.86, "bits": 2, "fire": 1.0},
           zones=2),
    Sector("CRIMSON RUN",
           "A pista sangra energia. Não pare.",
           (0.9, 0.05, 0.35), (1.0, 0.35, 0.55),
           {"color": (1.0, 0.3, 0.4), "shield": 52, "speed": 0.89, "bits": 3, "fire": 0.9},
           zones=3),
    Sector("SOLAR WINDS",
           "Ventos solares varrem o anel dourado.",
           (1.0, 0.55, 0.05), (1.0, 0.8, 0.3),
           {"color": (1.0, 0.75, 0.2), "shield": 64, "speed": 0.92, "bits": 3, "fire": 0.85},
           zones=3),
    Sector("VERDANT MAZE",
           "Vinhas de dados crescem nas paredes.",
           (0.1, 0.9, 0.3), (0.4, 1.0, 0.55),
           {"color": (0.4, 1.0, 0.4), "shield": 78, "speed": 0.95, "bits": 4, "fire": 0.8},
           zones=3),
    Sector("AZURE DEEP",
           "Profundezas azuis, silêncio absoluto.",
           (0.1, 0.3, 1.0), (0.4, 0.6, 1.0),
           {"color": (0.35, 0.6, 1.0), "shield": 92, "speed": 0.98, "bits": 4, "fire": 0.78},
           zones=3),
    Sector("VIOLET STORM",
           "Uma tempestade roxa dobra o espaço.",
           (0.6, 0.1, 1.0), (0.85, 0.4, 1.0),
           {"color": (0.8, 0.45, 1.0), "shield": 108, "speed": 1.01, "bits": 5, "fire": 0.75},
           zones=4),
    Sector("GOLDEN CIRCUIT",
           "Circuitos de ouro pulsando em alta tensão.",
           (1.0, 0.7, 0.1), (1.0, 0.9, 0.35),
           {"color": (1.0, 0.85, 0.3), "shield": 124, "speed": 1.04, "bits": 5, "fire": 0.72},
           zones=4),
    Sector("MAGENTA PULSE",
           "O pulso magenta acelera o seu coração.",
           (1.0, 0.1, 0.7), (1.0, 0.4, 0.85),
           {"color": (1.0, 0.4, 0.8), "shield": 142, "speed": 1.07, "bits": 6, "fire": 0.7},
           zones=4),
    Sector("ICE RING",
           "Um anel de gelo cristalino e implacável.",
           (0.6, 0.85, 1.0), (0.85, 0.95, 1.0),
           {"color": (0.8, 0.95, 1.0), "shield": 160, "speed": 1.10, "bits": 6, "fire": 0.68},
           zones=4),
    Sector("EMBER CORE",
           "O núcleo incandescente do Toro desperta.",
           (1.0, 0.25, 0.05), (1.0, 0.6, 0.25),
           {"color": (1.0, 0.5, 0.2), "shield": 180, "speed": 1.13, "bits": 7, "fire": 0.65},
           zones=4),
    Sector("OBSIDIAN SPIRE",
           "A torre de obsidiana guarda o segredo final.",
           (0.5, 0.1, 0.8), (0.75, 0.35, 1.0),
           {"color": (0.7, 0.35, 1.0), "shield": 200, "speed": 1.16, "bits": 8, "fire": 0.62},
           zones=4),
    Sector("CORAÇÃO DO TORO",
           "O coração do Toro. A fonte de todo o poder.",
           (1.0, 1.0, 1.0), (0.6, 1.0, 1.0),
           {"color": (1.0, 0.9, 1.0), "shield": 260, "speed": 1.22, "bits": 10, "fire": 0.55,
            "final": True},
           zones=4),
]

SECTOR_COUNT = len(SECTORS)

# Ship upgrades: picked one of three after each cleared sector.
UPGRADES = {
    "cannon":  {"name": "CANHÃO",    "desc": "Cadência de tiro +30%"},
    "power":   {"name": "POTÊNCIA",  "desc": "Tiros causam o dobro de dano"},
    "spread":  {"name": "DISPARO",   "desc": "Dois tiros laterais extras"},
    "speed":   {"name": "TURBO",     "desc": "+15% de velocidade máxima"},
    "charge":  {"name": "CARGA",     "desc": "Charge shot 35% mais rápido"},
    "shield":  {"name": "ESCUDO",    "desc": "+1 proteção contra dano"},
    "time":    {"name": "CRONO",     "desc": "+20s de tempo máximo"},
}

# Order in which upgrades appear in the selection pool.
UPGRADE_ORDER = ["cannon", "power", "spread", "speed", "charge", "shield", "time"]
