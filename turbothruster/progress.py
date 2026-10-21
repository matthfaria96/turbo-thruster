"""Persistence: campaign progress, settings, and the Turbo leaderboard."""

import datetime
import json
import os


DEFAULT_SETTINGS = {
    "fullscreen": False,
    "vsync": True,
    "effects": "alto",      # baixo / medio / alto
    "music_volume": 0.8,
    "sfx_volume": 0.8,
    "brightness": 1.0,
}

DEFAULT_DATA = {
    "unlocked_sector": 1,        # highest sector the player can enter (1-based)
    "campaign_complete": False,
    "turbo_unlocked": False,
    "upgrades": [],              # chosen upgrade ids (persist across sectors)
    "leaderboard": [],           # [{"score": int, "date": str}, ...]
    "settings": dict(DEFAULT_SETTINGS),
    "achievements": [],          # unlocked achievement ids
    "total_kills": 0,            # lifetime kill counter
}


class Progress:
    def __init__(self, path=None):
        if path is None:
            new_path = os.path.join(os.path.expanduser("~"), ".turbo_thruster.json")
            old_path = os.path.join(os.path.expanduser("~"), ".torus_thruster.json")
            # Migrate the old profile name on first run.
            if not os.path.exists(new_path) and os.path.exists(old_path):
                try:
                    os.replace(old_path, new_path)
                except Exception:
                    pass
            path = new_path
        self.path = path
        self.data = json.loads(json.dumps(DEFAULT_DATA))
        self.load()

    def load(self):
        try:
            with open(self.path, "r") as f:
                saved = json.load(f)
        except Exception:
            return
        for key in DEFAULT_DATA:
            if key in saved:
                if key == "settings":
                    for skey in DEFAULT_SETTINGS:
                        if skey in saved["settings"]:
                            self.data["settings"][skey] = saved["settings"][skey]
                else:
                    self.data[key] = saved[key]

    def save(self):
        try:
            with open(self.path, "w") as f:
                json.dump(self.data, f)
        except Exception:
            pass

    # -- progress ---------------------------------------------------------
    @property
    def unlocked_sector(self):
        return self.data["unlocked_sector"]

    @property
    def turbo_unlocked(self):
        return self.data["turbo_unlocked"]

    @property
    def campaign_complete(self):
        return self.data["campaign_complete"]

    def unlock_sector(self, n):
        if n > self.data["unlocked_sector"]:
            self.data["unlocked_sector"] = n

    def set_campaign_complete(self):
        self.data["campaign_complete"] = True
        self.data["turbo_unlocked"] = True

    # -- upgrades ---------------------------------------------------------
    def add_upgrade(self, uid):
        if uid not in self.data["upgrades"]:
            self.data["upgrades"].append(uid)

    def get_upgrades(self):
        return list(self.data["upgrades"])

    # -- leaderboard ------------------------------------------------------
    def add_score(self, score):
        entry = {"score": int(score), "date": datetime.date.today().isoformat()}
        self.data["leaderboard"].append(entry)
        self.data["leaderboard"].sort(key=lambda e: -e["score"])
        self.data["leaderboard"] = self.data["leaderboard"][:10]

    def get_leaderboard(self):
        return list(self.data["leaderboard"])

    # -- settings ---------------------------------------------------------
    def get_setting(self, key):
        return self.data["settings"].get(key, DEFAULT_SETTINGS.get(key))

    def set_setting(self, key, value):
        self.data["settings"][key] = value

    # -- achievements -----------------------------------------------------
    def unlock_achievement(self, aid):
        if aid not in self.data["achievements"]:
            self.data["achievements"].append(aid)
            self.save()
            return True
        return False

    def has_achievement(self, aid):
        return aid in self.data["achievements"]

    def get_achievements(self):
        return list(self.data["achievements"])
