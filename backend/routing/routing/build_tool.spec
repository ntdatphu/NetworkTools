# -*- mode: python ; coding: utf-8 -*-
from PyInstaller.utils.hooks import collect_all

datas = [('templates', 'templates')]
binaries = []
hiddenimports = []

# 1. Ép gom toàn bộ Nornir Core
tmp_nornir = collect_all('nornir')
datas += tmp_nornir[0]; binaries += tmp_nornir[1]; hiddenimports += tmp_nornir[2]

# 2. Ép gom toàn bộ Plugin Nornir Netmiko
tmp_n_netmiko = collect_all('nornir_netmiko')
datas += tmp_n_netmiko[0]; binaries += tmp_n_netmiko[1]; hiddenimports += tmp_n_netmiko[2]

# 3. Ép gom toàn bộ thư viện Netmiko lõi
tmp_netmiko = collect_all('netmiko')
datas += tmp_netmiko[0]; binaries += tmp_netmiko[1]; hiddenimports += tmp_netmiko[2]

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=binaries,
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='RoutingAutomationTool',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)