#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ["ar", "es", "fa", "fr", "pt"]
TABLES = {
    language: json.loads((ROOT / "Resources" / f"{language}.json").read_text(encoding="utf-8"))
    for language in LANGUAGES
}

CORE = [
    "Whitegram",
    "Appearance",
    "Notifications",
    "Liquid Glass",
    "Messages",
    "Camera",
    "Search settings",
    "Icons, bubbles, font",
    "Glass, blur and sections",
    "Sending, format, media",
    "Zoom, HD, video msgs",
    "Privacy",
    "Ghost Mode",
    "Plugins",
    "Language",
]

for source in CORE:
    for language in LANGUAGES:
        target = TABLES[language].get(source)
        if not target:
            raise SystemExit(f"Missing {language} translation for {source!r}")

# Every translation map must use exactly the same canonical English keys.
canonical = set(TABLES["ar"])
for language, table in TABLES.items():
    if set(table) != canonical:
        raise SystemExit(f"Key mismatch in {language}")

print(f"Language switching data OK: {len(canonical)} strings × {len(LANGUAGES)} translated languages + English source")
for source in CORE[:6]:
    print(source, "=>", " | ".join(TABLES[language][source] for language in LANGUAGES))
