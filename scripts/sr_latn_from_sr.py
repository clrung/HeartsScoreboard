#!/usr/bin/env python3
"""Regenerate sr-Latn Localizable/InfoPlist .strings from sr (Cyrillic) by standard Serbian
transliteration of the values. Run after editing sr.lproj:
    python3 scripts/sr_latn_from_sr.py HeartsScoreboard/Localizations"""
import re, sys, pathlib
L = pathlib.Path(sys.argv[1])
M = dict(zip("абвгдђежзијклљмнњопрстћуфхцчџш",
  ["a","b","v","g","d","đ","e","ž","z","i","j","k","l","lj","m","n","nj","o","p","r","s","t","ć","u","f","h","c","č","dž","š"]))
def tr(s):
    out=[]
    for i,ch in enumerate(s):
        lo=ch.lower()
        if lo not in M: out.append(ch); continue
        t=M[lo]
        if ch!=lo:
            nxt=s[i+1] if i+1<len(s) else ""
            t = t.upper() if (len(t)>1 and nxt.isupper()) else t[0].upper()+t[1:]
        out.append(t)
    return "".join(out)
line=re.compile(r'^(\s*"(?:[^"\\]|\\.)*"\s*=\s*")((?:[^"\\]|\\.)*)("\s*;.*)$')
for name in ["Localizable.strings","InfoPlist.strings"]:
    src=(L/"sr.lproj"/name).read_text(encoding="utf-8").splitlines(keepends=True)
    res=[]
    for ln in src:
        m=line.match(ln.rstrip("\n"))
        res.append(m.group(1)+tr(m.group(2))+m.group(3)+"\n" if m else ln)
    (L/"sr-Latn.lproj"/name).write_text("".join(res),encoding="utf-8")
print("ok")
