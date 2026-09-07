#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Acceso directo al Generador Procedural 3D (Blender Python).
Redirige o ejecuta la suite completa ubicada en tools/procedural_phone_stand/generate_phone_stand_blender.py
"""
import os
import sys

script_dir = os.path.join(os.path.dirname(__file__), "tools", "procedural_phone_stand")
script_path = os.path.join(script_dir, "generate_phone_stand_blender.py")

if os.path.isfile(script_path):
    with open(script_path, "r", encoding="utf-8") as f:
        code = f.read()
    exec(compile(code, script_path, 'exec'), globals(), globals())
else:
    raise FileNotFoundError(f"No se encontró el script en: {script_path}")
