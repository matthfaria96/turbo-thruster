# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for Turbo Thruster.
# Builds a self-contained executable (Windows .exe / Linux binary / macOS app).
#   pip install pyinstaller
#   pyinstaller tt.spec

import sys

a = Analysis(
    ['tt.py'],
    pathex=[],
    binaries=[],
    datas=[('assets', 'assets')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='turbo-thruster',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
)

if sys.platform == 'darwin':
    app = BUNDLE(
        exe,
        name='Turbo Thruster.app',
        icon='assets/icon.png' if False else None,
        bundle_identifier='com.example.turbothruster',
        info_plist={
            'CFBundleName': 'Turbo Thruster',
            'CFBundleDisplayName': 'Turbo Thruster',
        },
    )
