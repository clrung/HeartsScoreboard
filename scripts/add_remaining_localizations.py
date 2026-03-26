#!/usr/bin/env python3
"""
Adds missing App Store–style localizations: generates Localizable.strings + InfoPlist.strings
and updates project.pbxproj. Uses Google via deep-translator (requires network on first run).
Caches per-locale JSON under scripts/.locale_cache/ (gitignored).
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "HeartsScoreboard" / "Localizations"
EN = LOC / "en.lproj" / "Localizable.strings"
EN_INFO = LOC / "en.lproj" / "InfoPlist.strings"
PBX = ROOT / "HeartsScoreboard.xcodeproj" / "project.pbxproj"
CACHE_DIR = Path(__file__).resolve().parent / ".locale_cache"

ADD_LOCALES = [
    "uk",
    "he",
    "cs",
    "da",
    "fi",
    "el",
    "hu",
    "ro",
    "ms",
    "nb",
    "ca",
    "hr",
    "sk",
    "bg",
    "sl",
    "et",
    "lv",
    "lt",
    "sr-Latn",
    "bs",
    "is",
    "fil",
    "fa",
    "ur",
    "gu",
    "kn",
    "ml",
    "mr",
    "pa",
    "ta",
    "te",
    "bn",
    "am",
    "az",
    "eu",
    "gl",
    "mk",
    "sq",
    "sw",
    "hy",
    "ka",
    "km",
    "lo",
    "mn",
    "ne",
    "si",
    "uz",
    "kk",
    "cy",
    "zu",
    "af",
    "my",
    "pt-PT",
    "es-419",
    "sr",
]

LOCALE_TO_GOOGLE = {
    "nb": "no",
    "fil": "tl",
    "sr-Latn": "sr",
    "pt-PT": "pt",
    "es-419": "es",
    "he": "iw",  # Google uses legacy code for Hebrew
}


def simple_unescape(s: str) -> str:
    return s.replace("\\\\", "\x00").replace('\\"', '"').replace("\\n", "\n").replace("\x00", "\\")


def parse_strings(path: Path) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("/*") or line.startswith("//"):
            continue
        m = re.match(r'^"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)"\s*;\s*$', line)
        if not m:
            continue
        pairs.append((simple_unescape(m.group(1)), simple_unescape(m.group(2))))
    return pairs


def esc_strings(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def write_strings(path: Path, pairs: list[tuple[str, str]]) -> None:
    lines = [f'"{esc_strings(k)}" = "{esc_strings(v)}";' for k, v in pairs]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def google_code(locale: str) -> str:
    return LOCALE_TO_GOOGLE.get(locale, locale.split("-")[0])


def translate_values(values: list[str], target: str) -> list[str]:
    """One request per language (newline-separated values); falls back per line on mismatch."""
    from deep_translator import GoogleTranslator

    t = GoogleTranslator(source="en", target=target)
    blob = "\n".join(values)
    translated = t.translate(blob)
    if translated is None:
        raise RuntimeError("translate returned None")
    parts = translated.split("\n")
    if len(parts) == len(values):
        return parts
    # Rare: newlines inside a value or API changed line count
    out: list[str] = []
    for text in values:
        time.sleep(0.04)
        out.append(t.translate(text))
    return out


def load_or_translate(locale: str, keys: list[str], values: list[str]) -> list[str]:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    h = hashlib.sha256(repr(keys).encode()).hexdigest()[:16]
    cache_path = CACHE_DIR / f"{locale}_{h}.json"
    if cache_path.exists():
        data = json.loads(cache_path.read_text(encoding="utf-8"))
        if data.get("keys") == keys:
            return data["values"]

    gc = google_code(locale)
    print(f"  Translating {locale} (google={gc})...", flush=True)
    try:
        translated = translate_values(values, gc)
    except Exception as e:
        print(f"  ERROR {locale}: {e}; using English fallback", flush=True)
        translated = list(values)

    if len(translated) != len(values):
        print(f"  Mismatch length for {locale}; padding with English", flush=True)
        translated = translated[: len(values)]
        while len(translated) < len(values):
            translated.append(values[len(translated)])

    cache_path.write_text(
        json.dumps({"keys": keys, "values": translated}, ensure_ascii=False, indent=0),
        encoding="utf-8",
    )
    return translated


def translate_single(text: str, target: str) -> str:
    from deep_translator import GoogleTranslator

    t = GoogleTranslator(source="en", target=target)
    return t.translate(text) or text


def patch_pbxproj(new_locales: list[str]) -> None:
    import uuid

    pbx = PBX.read_text(encoding="utf-8")
    if not pbx.endswith("\n"):
        pbx += "\n"

    refs: dict[str, tuple[str, str]] = {}
    for loc in new_locales:
        refs[loc] = (uuid.uuid4().hex[:24].upper(), uuid.uuid4().hex[:24].upper())

    lt = "text.plist.strings"
    insert_block = []
    for loc in new_locales:
        uid_i, uid_l = refs[loc]
        if "-" in loc:
            insert_block.append(
                f'\t\t{uid_i} /* {loc} */ = {{isa = PBXFileReference; lastKnownFileType = {lt}; name = "{loc}"; path = "{loc}.lproj/InfoPlist.strings"; sourceTree = "<group>"; }};'
            )
            insert_block.append(
                f'\t\t{uid_l} /* {loc} */ = {{isa = PBXFileReference; lastKnownFileType = {lt}; name = "{loc}"; path = "{loc}.lproj/Localizable.strings"; sourceTree = "<group>"; }};'
            )
        else:
            insert_block.append(
                f"\t\t{uid_i} /* {loc} */ = {{isa = PBXFileReference; lastKnownFileType = {lt}; name = {loc}; path = {loc}.lproj/InfoPlist.strings; sourceTree = \"<group>\"; }};"
            )
            insert_block.append(
                f"\t\t{uid_l} /* {loc} */ = {{isa = PBXFileReference; lastKnownFileType = {lt}; name = {loc}; path = {loc}.lproj/Localizable.strings; sourceTree = \"<group>\"; }};"
            )

    marker = (
        "\t\tF2000000000000000000010A /* hi */ = {isa = PBXFileReference; "
        'lastKnownFileType = text.plist.strings; name = hi; path = hi.lproj/Localizable.strings; sourceTree = "<group>"; };\n'
    )
    if marker not in pbx:
        sys.exit("pbxproj: could not find hi Localizable anchor")
    pbx = pbx.replace(marker, marker + "\n".join(insert_block) + "\n", 1)

    inf_anchor = "\t\t\t\tF2000000000000000000000A /* hi */,\n"
    loc_anchor = "\t\t\t\tF2000000000000000000010A /* hi */,\n"
    if inf_anchor not in pbx or loc_anchor not in pbx:
        sys.exit("pbxproj: variant group anchor missing")

    inf_children = "\n".join(f"\t\t\t\t{refs[loc][0]} /* {loc} */," for loc in new_locales)
    loc_children = "\n".join(f"\t\t\t\t{refs[loc][1]} /* {loc} */," for loc in new_locales)
    pbx = pbx.replace(inf_anchor, inf_anchor + inf_children + "\n", 1)
    pbx = pbx.replace(loc_anchor, loc_anchor + loc_children + "\n", 1)

    proj_anchor = "\t\t\t\thi,\n\t\t\t);\n\t\t\tmainGroup"
    if proj_anchor not in pbx:
        sys.exit("pbxproj: PBXProject knownRegions anchor missing")
    extra_lines = [
        f'\t\t\t\t"{loc}",' if "-" in loc else f"\t\t\t\t{loc}," for loc in new_locales
    ]
    pbx = pbx.replace(
        proj_anchor,
        "\t\t\t\thi,\n" + "\n".join(extra_lines) + "\n\t\t\t);\n\t\t\tmainGroup",
        1,
    )

    def merge_build_regions(m: re.Match) -> str:
        parts = m.group(1).split()
        for loc in new_locales:
            if loc not in parts:
                parts.append(loc)
        return 'knownRegions = "' + " ".join(parts) + '";'

    pbx = re.sub(r'knownRegions = "([^"]+)";', merge_build_regions, pbx)

    PBX.write_text(pbx, encoding="utf-8")
    print(f"Updated {PBX}")


def main() -> None:
    pairs = parse_strings(EN)
    keys = [k for k, _ in pairs]
    values = [v for _, v in pairs]

    display_en = "Scoreboard"
    if EN_INFO.exists():
        m = re.search(
            r'"CFBundleDisplayName"\s*=\s*"((?:\\.|[^"])*)"\s*;',
            EN_INFO.read_text(encoding="utf-8"),
        )
        if m:
            display_en = simple_unescape(m.group(1))

    existing = {
        p.name.replace(".lproj", "")
        for p in LOC.iterdir()
        if p.is_dir() and p.name.endswith(".lproj")
    }
    to_add = [loc for loc in ADD_LOCALES if loc not in existing]
    if not to_add:
        print("No new locales to add (all present).")
        return

    print(f"Adding {len(to_add)} locales: {', '.join(to_add)}")

    for loc in to_add:
        tvals = load_or_translate(loc, keys, values)
        loc_pairs = list(zip(keys, tvals))
        base = LOC / f"{loc}.lproj"
        write_strings(base / "Localizable.strings", loc_pairs)
        gc = google_code(loc)
        try:
            short = translate_single(display_en, gc)
        except Exception:
            short = display_en
        time.sleep(0.08)
        if not short:
            short = display_en
        if len(short) > 22:
            short = short[:22].rstrip()
        info = '/* App name on home screen */\n' f'"CFBundleDisplayName" = "{esc_strings(short)}";\n'
        (base / "InfoPlist.strings").write_text(info, encoding="utf-8")
        print(f"  Wrote {loc}.lproj")

    patch_pbxproj(to_add)
    print("Done.")


if __name__ == "__main__":
    main()
