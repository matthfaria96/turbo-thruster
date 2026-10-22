"""Audio: background music and sound effects (reuses the original assets)."""

import os

from .vec import Rand


class SoundManager:
    MUSIC = ["tt1.ogg", "tt2.ogg", "tt3.ogg", "tt4.ogg"]
    SFX = [
        "boss_dest.wav", "charge.wav", "charge_shot.wav", "extend.wav", "hit.wav",
        "middle_dest.wav", "myship_dest.wav", "shot.wav", "small_dest.wav",
        "timeup_beep.wav",
    ]

    def __init__(self, asset_dir):
        self.asset_dir = asset_dir
        self.sounds = {}
        self.enabled = False
        self.se_enabled = True
        self.music_idx = 0
        self.mixer = None
        self.music_paths = []
        self.rand = Rand()

    def load(self, pygame):
        self.mixer = pygame.mixer
        self.enabled = bool(pygame.mixer.get_init())
        if not self.enabled:
            return
        musics = os.path.join(self.asset_dir, "sounds", "musics")
        chunks = os.path.join(self.asset_dir, "sounds", "chunks")
        for name in self.SFX:
            path = os.path.join(chunks, name)
            if os.path.exists(path):
                try:
                    self.sounds[name] = pygame.mixer.Sound(path)
                except Exception:
                    pass
        self.music_paths = [os.path.join(musics, m) for m in self.MUSIC
                            if os.path.exists(os.path.join(musics, m))]

    def play_se(self, name):
        if not self.enabled or not self.se_enabled:
            return
        snd = self.sounds.get(name)
        if snd is not None:
            snd.play()

    def enable_se(self):
        self.se_enabled = True

    def disable_se(self):
        self.se_enabled = False

    def play_bgm(self):
        if not self.enabled or not self.music_paths:
            return
        self.music_idx = 0
        self._play(self.music_paths[0])

    def _play(self, path):
        try:
            self.mixer.music.load(path)
            self.mixer.music.play(-1)
        except Exception:
            pass

    def next_bgm(self):
        if not self.enabled or not self.music_paths:
            return
        self.music_idx = (self.music_idx + 1) % len(self.music_paths)
        self._play(self.music_paths[self.music_idx])

    def fade_bgm(self):
        if self.enabled:
            try:
                self.mixer.music.fadeout(600)
            except Exception:
                pass

    def halt_bgm(self):
        if self.enabled:
            try:
                self.mixer.music.stop()
            except Exception:
                pass
