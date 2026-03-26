#!/usr/bin/env python3
"""Fill English stragglers: AppStoreMetadata description/keywords, Localizable keys still == en."""
from __future__ import annotations

import re
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "HeartsScoreboard" / "Localizations"

LOCALE_TO_GOOGLE = {
    "nb": "no",
    "fil": "tl",
    # Google frequently returns English for short UI phrases when target is "bs".
    "bs": "hr",
    "sr-Latn": "sr",
    "pt-PT": "pt",
    "es-419": "es",
    "he": "iw",
    "zh-Hans": "zh-CN",
    "zh-Hant": "zh-TW",
}


def google_code(locale: str) -> str:
    return LOCALE_TO_GOOGLE.get(locale, locale.split("-")[0])


def unesc(s: str) -> str:
    return (
        s.replace("\\\\", "\x00")
        .replace('\\"', '"')
        .replace("\\n", "\n")
        .replace("\x00", "\\")
    )


def esc(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")


def parse_localizable(path: Path) -> tuple[list[str], dict[str, str]]:
    """Preserve key order from file."""
    order: list[str] = []
    d: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("/*") or line.startswith("//"):
            continue
        m = re.match(r'^"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)"\s*;\s*$', line)
        if m:
            k = unesc(m.group(1))
            order.append(k)
            d[k] = unesc(m.group(2))
    return order, d


def write_localizable(path: Path, order: list[str], d: dict[str, str]) -> None:
    lines = [f'"{esc(k)}" = "{esc(d[k])}";' for k in order if k in d]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def parse_metadata(path: Path) -> dict[str, str]:
    text = path.read_text(encoding="utf-8")
    d: dict[str, str] = {}
    m = re.search(r'"description"\s*=\s*"(.*?)";\s*\n"keywords"', text, re.DOTALL)
    if m:
        d["description"] = unesc(m.group(1))
    m = re.search(r'"keywords"\s*=\s*"((?:\\.|[^"])*)"\s*;', text)
    if m:
        d["keywords"] = unesc(m.group(1))
    m = re.search(r'"supportUrl"\s*=\s*"((?:\\.|[^"])*)"\s*;', text)
    if m:
        d["supportUrl"] = unesc(m.group(1))
    m = re.search(r'"whatsNew"\s*=\s*"((?:\\.|[^"])*)"\s*;', text)
    if m:
        d["whatsNew"] = unesc(m.group(1))
    return d


def write_metadata(path: Path, locale: str, data: dict[str, str]) -> None:
    body = f'''/* App Store Metadata for {locale} */

"description" = "{esc(data["description"])}";
"keywords" = "{esc(data["keywords"])}";
"supportUrl" = "{esc(data["supportUrl"])}";
"whatsNew" = "{esc(data["whatsNew"])}";
'''
    path.write_text(body, encoding="utf-8")


# When Google returns English (game jargon / short labels), paraphrase for translation.
_UI_FALLBACK: dict[str, str] = {
    "Shoot the Moon Preference": "Preference for the shoot-the-moon scoring rule in Hearts",
    "Hearts Scoreboard": "Scoreboard for the Hearts card game",
    "Pass Across": "Passing cards to the opposite player in Hearts",
    "Dealer": "Player who deals the cards",
    "Pass: Hold ✋": "Keep all cards — no passing this round (Hearts) ✋",
    "Round %d": "Round number %d",
    "Reset": "Restore defaults",
}


def translate_text(text: str, target: str) -> str:
    from deep_translator import GoogleTranslator

    t = GoogleTranslator(source="en", target=target)
    out = t.translate(text) or text
    if out.strip() == text.strip():
        fb = _UI_FALLBACK.get(text)
        if fb:
            out2 = t.translate(fb)
            if out2 and out2.strip() != text.strip():
                out = out2
    return out if out else text


def translate_lines(lines: list[str], target: str) -> list[str]:
    """Translate one line at a time so fallbacks apply."""
    out: list[str] = []
    for i, line in enumerate(lines):
        out.append(translate_text(line, target))
        if i:
            time.sleep(0.06)
    return out


def main() -> None:
    en_meta_path = LOC / "en.lproj" / "AppStoreMetadata.strings"
    en_meta = parse_metadata(en_meta_path)
    en_desc = en_meta.get("description", "").strip()
    en_kw = en_meta.get("keywords", "").strip()

    en_loc_path = LOC / "en.lproj" / "Localizable.strings"
    en_order, en_loc = parse_localizable(en_loc_path)

    # --- App Store metadata ---
    for lproj in sorted(LOC.glob("*.lproj")):
        loc = lproj.name.removesuffix(".lproj")
        if loc == "en":
            continue
        mp = lproj / "AppStoreMetadata.strings"
        if not mp.is_file():
            continue
        data = parse_metadata(mp)
        if not data.get("supportUrl"):
            data["supportUrl"] = en_meta.get("supportUrl", "https://christopherrung.com")
        if not data.get("whatsNew"):
            data["whatsNew"] = ""

        changed = False
        gc = google_code(loc)
        if data.get("description", "").strip() == en_desc:
            print(f"metadata description: {loc}", flush=True)
            try:
                data["description"] = translate_text(data["description"], gc)
            except Exception as e:
                print(f"  ERR description {loc}: {e}", flush=True)
            changed = True
            time.sleep(0.12)
        if data.get("keywords", "").strip() == en_kw:
            print(f"metadata keywords: {loc}", flush=True)
            try:
                data["keywords"] = translate_text(data["keywords"], gc)
            except Exception as e:
                print(f"  ERR keywords {loc}: {e}", flush=True)
            changed = True
            time.sleep(0.12)
        if changed:
            write_metadata(mp, loc, data)

    # --- Localizable stragglers (value still equals English) ---
    for lproj in sorted(LOC.glob("*.lproj")):
        loc = lproj.name.removesuffix(".lproj")
        if loc == "en":
            continue
        lp = lproj / "Localizable.strings"
        if not lp.is_file():
            continue
        order, ld = parse_localizable(lp)
        stale = [k for k in en_order if k in en_loc and ld.get(k) == en_loc[k] and len(en_loc[k]) > 3]
        if not stale:
            continue
        print(f"Localizable {loc}: {len(stale)} keys", flush=True)
        gc = google_code(loc)
        try:
            src_vals = [en_loc[k] for k in stale]
            new_vals = translate_lines(src_vals, gc)
            for k, v in zip(stale, new_vals):
                ld[k] = v
        except Exception as e:
            print(f"  batch ERR {loc}: {e}; per-key", flush=True)
            for k in stale:
                try:
                    ld[k] = translate_text(en_loc[k], gc)
                    time.sleep(0.08)
                except Exception as e2:
                    print(f"    skip {k}: {e2}", flush=True)
        write_localizable(lp, order, ld)
        time.sleep(0.12)

    print("Done.")


if __name__ == "__main__":
    main()
