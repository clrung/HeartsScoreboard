#!/usr/bin/env python3
"""Append en-only Localizable.strings keys to every other locale (Google via deep-translator).

Only keys missing from a locale are translated/appended; existing lines are untouched.
Format specifiers and 10♦/−10/26 are protected with {n} tokens and validated.
Short ambiguous labels are translated with a disambiguating "(context)" suffix that is stripped
afterwards; "Round"/"Rounds" are derived from the locale's existing "Round %d"/"%d rounds".
Left/Right/Across/Hold are derived from the locale's existing Pass: X strings.
Cache: scripts/.locale_cache/newkeys_<locale>.json (gitignored). Run with scripts/.venv/bin/python.
Usage: translate_new_en_keys.py [locale ...]
"""
from __future__ import annotations
import json, re, sys, time
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOC = ROOT / "HeartsScoreboard" / "Localizations"
CACHE = Path(__file__).resolve().parent / ".locale_cache"
LOCALE_TO_GOOGLE = {"nb": "no", "fil": "tl", "bs": "hr", "sr-Latn": "sr", "pt-PT": "pt",
                    "es-419": "es", "he": "iw", "zh-Hans": "zh-CN", "zh-Hant": "zh-TW"}
# English source sent to Google (context in parentheses is stripped from the result).
CONTEXT = {
    "Left": "Left (pass direction)", "Right": "Right (pass direction)",
    "Across": "Across (pass direction)", "Hold": "Hold (no passing)",
    "Moons": "Moons (shoot the moon)", "Redo": "Redo (undo again)",
    "More": "More (more actions)", "View": "View (display mode)", "Save": "Save (button)",
    "Close": "Close (button)", "Played": "Played (games)", "Wins": "Wins (games won)",
    "Games": "Games (played)", "Results": "Results (final)", "Rematch": "Rematch (play again)",
    "Avg score": "Average score", "Round": "Round (hand of cards)",
    "Rounds": "Rounds (hands of cards)",
}
SOURCE_OVERRIDE = {
    "Total %d": "Total score: %d",
    "Moon adds 26 to others": "Shooting the moon adds 26 to the others",
    "Moon subtracts 26 from shooter": "Shooting the moon subtracts 26 from the shooter",
}
SPEC = re.compile(r"%(?:\d+\$)?(?:l{0,2})[@dDuUfs]")
LITERAL = ["10♦", "−10", "26"]


def unesc(s): return s.replace("\\\\", "\x00").replace('\\"', '"').replace("\\n", "\n").replace("\x00", "\\")
def esc(s): return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n").replace("\r", "")


def parse(path):
    d, order = {}, []
    for line in path.read_text(encoding="utf-8").splitlines():
        m = re.match(r'^"((?:\\.|[^"])*)"\s*=\s*"((?:\\.|[^"])*)"\s*;\s*$', line.strip())
        if m:
            k = unesc(m.group(1)); d[k] = unesc(m.group(2)); order.append(k)
    return order, d


def norm_specs(s): return Counter(re.sub(r"%\d+\$", "%", x) for x in SPEC.findall(s))


def protect(text):
    toks = []
    def sub(m):
        toks.append(m.group(0)); return "{%d}" % (len(toks) - 1)
    pat = "|".join([SPEC.pattern] + [re.escape(l) for l in LITERAL])
    return re.sub(pat, sub, text), toks


def google_code(l): return LOCALE_TO_GOOGLE.get(l, l.split("-")[0])


class T:
    """Google Translate via the gtx endpoint (same engine deep-translator uses; its /m
    endpoint gets captcha-blocked far sooner)."""
    def __init__(self, code):
        self.code = code
    def __call__(self, text):
        import urllib.parse, urllib.request
        url = ("https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl="
               + self.code + "&dt=t&q=" + urllib.parse.quote(text))
        for i in range(30):
            time.sleep(0.5)
            try:
                with urllib.request.urlopen(url, timeout=30) as r:
                    data = json.loads(r.read().decode("utf-8"))
                return "".join(seg[0] for seg in data[0] if seg[0])
            except Exception:
                time.sleep(min(10 * (i + 1), 120))
        raise RuntimeError("rate limited")


def strip_ctx(s):
    return re.sub(r"\s*[\(（\[][^)）\]]*[\)）\]]\s*$", "", s).strip()


def restore(out, toks, variants):
    """Put tokens back. Returns string or None if tokens got mangled."""
    for op, cl in variants:
        res = out
        ok = True
        for i, tok in enumerate(toks):
            pat = re.compile(re.escape(op) + r"\s*" + str(i) + r"\s*" + re.escape(cl))
            if len(pat.findall(res)) != 1: ok = False; break
            res = pat.sub(lambda _m: tok, res)
        if ok: return res
    return None


def positionalize(res, en):
    """If specifier order differs from English, number them (%1$@) so semantics hold."""
    a = [re.sub(r"%\d+\$", "%", x) for x in SPEC.findall(res)]
    b = [re.sub(r"%\d+\$", "%", x) for x in SPEC.findall(en)]
    if a == b or len(a) < 2: return res
    # map each English spec index (by order) to the result's order
    pos = {}; used = set()
    for i, x in enumerate(a):
        for j, y in enumerate(b):
            if j not in used and x == y:
                used.add(j); pos[i] = j + 1; break
    it = iter(range(len(a)))
    def sub(m):
        i = next(it); s = re.sub(r"%\d+\$", "%", m.group(0))
        return "%" + str(pos[i]) + "$" + s[1:]
    return SPEC.sub(sub, res)


def valid(res, en):
    if not res or not res.strip(): return False
    if norm_specs(res) != norm_specs(en): return False
    for l in LITERAL + ["♦", "♠"]:
        if res.count(l) != en.count(l) and l in en and not (l in LITERAL and False): return False
    return True


def source_for(key, en_val):
    return protect(SOURCE_OVERRIDE.get(key, CONTEXT.get(key, en_val)))


def translate_key(tr, key, en_val, loc_d, pre=None):
    # derive Round/Rounds from existing locale strings
    if key in ("Round", "Rounds"):
        src = loc_d.get("Round %d" if key == "Round" else "%d rounds")
        if src:
            r = re.sub(r"^\s*%d\s*|\s*%d\s*$", "", src).strip(" :：")
            if "%" not in r and r and r != src and not re.search(r"[0-9]", r) and len(r) < len(src) + 3:
                return r[0].upper() + r[1:], "derived"
    if key in ("Left", "Right", "Across", "Hold"):
        src = loc_d.get(f"Pass: {key} " + {"Left": "←", "Right": "→", "Across": "↔", "Hold": "✋"}[key])
        if src and re.search(r"[:：]", src):
            r = re.split(r"[:：]", src, 1)[1].strip().rstrip("←→↔✋ ").strip()
            if r and "%" not in r:
                return r, "derived"
    base = SOURCE_OVERRIDE.get(key, CONTEXT.get(key, en_val))
    if key not in CONTEXT:
        pass
    prot, toks = protect(base)
    for op, cl, form in [("{", "}", None), ("[", "]", None), ("<", ">", None)]:
        txt = prot.replace("{", op).replace("}", cl) if op != "{" else prot
        out = pre.get(key) if (pre and op == "{" and pre.get(key)) else tr(txt)
        if not out: continue
        res = restore(out, toks, [(op, cl)])
        if res is None: continue
        if key in CONTEXT: res = strip_ctx(res)
        res = positionalize(res, en_val)
        if valid(res, en_val): return res, "google"
    return en_val, "fallback"


def main():
    CACHE.mkdir(exist_ok=True)
    en_order, en = parse(LOC / "en.lproj" / "Localizable.strings")
    only = sys.argv[1:]
    for d in sorted(LOC.glob("*.lproj")):
        loc = d.name[:-6]
        if loc == "en" or (only and loc not in only): continue
        path = d / "Localizable.strings"
        _, cur = parse(path)
        missing = [k for k in en_order if k not in cur]
        if not missing: continue
        cp = CACHE / f"newkeys_{loc}.json"
        cache = json.loads(cp.read_text()) if cp.exists() else {}
        tr = T(google_code(loc))
        print(loc, len(missing), flush=True)
        lines = []
        todo = [k for k in missing if k not in cache]
        pre = {}
        if todo:  # one batched request per locale; per-key fallback if the line count mismatches
            srcs = [source_for(k, en[k])[0] for k in todo]
            try:
                parts = tr("\n".join(srcs)).split("\n")
                if len(parts) == len(todo):
                    pre = dict(zip(todo, [x.strip() for x in parts]))
            except Exception as e:
                print("  batch failed", e, flush=True)
        for k in missing:
            if k not in cache:
                v, how = translate_key(tr, k, en[k], cur, pre)
                cache[k] = [v, how]
                cp.write_text(json.dumps(cache, ensure_ascii=False, indent=1))
            lines.append(f'"{esc(k)}" = "{esc(cache[k][0])}";')
        txt = path.read_text(encoding="utf-8")
        if not txt.endswith("\n"): txt += "\n"
        path.write_text(txt + "\n".join(lines) + "\n", encoding="utf-8")
        fb = [k for k in missing if cache[k][1] == "fallback"]
        if fb: print("  FALLBACK", loc, fb, flush=True)


if __name__ == "__main__":
    main()
