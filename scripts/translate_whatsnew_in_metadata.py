#!/usr/bin/env python3
"""Replace a key (default whatsNew) in each AppStoreMetadata.strings with a translation of the English source.

Usage: scripts/.venv/bin/python scripts/translate_whatsnew_in_metadata.py [whatsNew|description]
"""
from __future__ import annotations

import json
import re
import sys
import time
from pathlib import Path

KEY = sys.argv[1] if len(sys.argv) > 1 else "whatsNew"
ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "HeartsScoreboard" / "Localizations"
CACHE_DIR = Path(__file__).resolve().parent / ".locale_cache"
CACHE_DIR.mkdir(parents=True, exist_ok=True)

# Map Xcode .lproj name -> deep-translator Google target code
LOCALE_TO_GOOGLE = {
    "nb": "no",
    "fil": "tl",
    "bs": "hr",
    "sr-Latn": "sr",
    "pt-PT": "pt",
    "es-419": "es",
    "he": "iw",
    "zh-Hans": "zh-CN",
    "zh-Hant": "zh-TW",
}


def google_code(locale: str) -> str:
    if locale in LOCALE_TO_GOOGLE:
        return LOCALE_TO_GOOGLE[locale]
    return locale.split("-")[0]


def esc_strings(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")


def read_whats_new(path: Path) -> str | None:
    text = path.read_text(encoding="utf-8")
    m = re.search(rf'"{KEY}"\s*=\s*"((?:\\.|[^"])*)"\s*;', text, re.DOTALL)
    if not m:
        return None
    raw = m.group(1)
    return (
        raw.replace("\\\\", "\x00")
        .replace('\\"', '"')
        .replace("\\n", "\n")
        .replace("\x00", "\\")
    )


def replace_whats_new(content: str, new_value: str) -> str:
    esc = esc_strings(new_value)
    return re.sub(
        rf'"{KEY}"\s*=\s*"(?:\\.|[^"])*"\s*;',
        lambda _: f'"{KEY}" = "{esc}";',
        content,
        count=1,
    )


def translate(text: str, target: str) -> str:
    from deep_translator import GoogleTranslator

    t = GoogleTranslator(source="en", target=target)
    out = t.translate(text)
    if not out:
        raise RuntimeError("empty translation")
    return out


def main() -> None:
    en_path = LOC / "en.lproj" / "AppStoreMetadata.strings"
    source = read_whats_new(en_path)
    if not source or not source.strip():
        raise SystemExit(f"English {KEY} missing or empty")

    lprojs = sorted(p for p in LOC.glob("*.lproj") if (p / "AppStoreMetadata.strings").is_file())
    for lproj in lprojs:
        loc = lproj.name.removesuffix(".lproj")
        meta = lproj / "AppStoreMetadata.strings"
        if loc == "en":
            continue

        cache_file = CACHE_DIR / f"{KEY.lower()}_meta_{loc}.json"
        if cache_file.exists():
            data = json.loads(cache_file.read_text(encoding="utf-8"))
            if data.get("source") == source:
                translated = data["translated"]
            else:
                translated = None
        else:
            translated = None

        if translated is None:
            gc = google_code(loc)
            print(f"  {loc} (google={gc})…", flush=True)
            translated = None
            for attempt in range(5):
                try:
                    translated = translate(source, gc)
                    break
                except Exception as e:
                    print(f"    retry {attempt + 1} {loc}: {e}", flush=True)
                    time.sleep(10 * (attempt + 1))
            if translated is None:
                # Don't cache or write English over the existing translation.
                print(f"    FAIL {loc}", flush=True)
                continue
            cache_file.write_text(
                json.dumps({"source": source, "translated": translated}, ensure_ascii=False),
                encoding="utf-8",
            )
            time.sleep(1.5)

        body = meta.read_text(encoding="utf-8")
        if f'"{KEY}"' not in body:
            body = body.rstrip() + f'\n"{KEY}" = "{esc_strings(translated)}";\n'
        else:
            body = replace_whats_new(body, translated)
        meta.write_text(body, encoding="utf-8")
        print(f"  OK {loc}")

    print("Done.")


if __name__ == "__main__":
    main()
