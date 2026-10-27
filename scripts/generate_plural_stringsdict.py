#!/usr/bin/env python3
"""Generate <locale>.lproj/Localizable.stringsdict for the plural-aware keys.

Currently one key: "%lld rounds" (HistoryView row badge and ResultCardView). Call sites use
String(localized: "\\(n) rounds"), whose key is "%lld rounds"; the .stringsdict entry replaces any
.strings entry for that key, so the key must NOT also be in Localizable.strings.

Usage (from the repo root; offline, no dependencies):
    python3 scripts/generate_plural_stringsdict.py [HeartsScoreboard/Localizations]

Each locale below lists only the CLDR plural categories that integer round counts can reach
(plus "other", which is mandatory and the fallback for any category left out). "%lld" is the
count. Translations were LLM-generated from each locale's earlier "%lld rounds" / "1 round"
strings, then adjusted to its CLDR rules; have native speakers check them. To add a plural key or
fix a form, edit PLURALS and rerun; the output is deterministic. sr-Latn is written from the
Latin forms below (independent of sr_latn_from_sr.py, which only touches .strings).
"""
import pathlib
import plistlib
import sys

KEY = "%lld rounds"
N = "%lld"

# locale -> {category: format}
PLURALS = {
    "en": {"one": "%lld round", "other": "%lld rounds"},
    "af": {"one": "%lld rondte", "other": "%lld rondtes"},
    "am": {"one": "%lld ዙር", "other": "%lld ዙሮች"},
    "ar": {"zero": "%lld جولة", "one": "جولة واحدة", "two": "جولتان", "few": "%lld جولات",
           "many": "%lld جولة", "other": "%lld جولة"},
    "az": {"one": "%lld raund", "other": "%lld raund"},
    "bg": {"one": "%lld кръг", "other": "%lld кръга"},
    "bn": {"one": "%lld রাউন্ড", "other": "%lldটি রাউন্ড"},
    "bs": {"one": "%lld runda", "few": "%lld runde", "other": "%lld rundi"},
    "ca": {"one": "%lld ronda", "other": "%lld rondes"},
    "cs": {"one": "%lld kolo", "few": "%lld kola", "many": "%lld kola", "other": "%lld kol"},
    "cy": {"other": "%lld rownd"},  # Welsh nouns stay singular after numerals
    "da": {"one": "%lld runde", "other": "%lld runder"},
    "de": {"one": "%lld Runde", "other": "%lld Runden"},
    "el": {"one": "%lld γύρος", "other": "%lld γύροι"},
    "es": {"one": "%lld ronda", "other": "%lld rondas"},
    "es-419": {"one": "%lld ronda", "other": "%lld rondas"},
    "et": {"one": "%lld ring", "other": "%lld ringi"},
    "eu": {"one": "%lld txanda", "other": "%lld txanda"},
    "fa": {"one": "%lld دور", "other": "%lld دور"},
    "fi": {"one": "%lld kierros", "other": "%lld kierrosta"},
    "fil": {"one": "%lld round", "other": "%lld round"},
    "fr": {"one": "%lld donne", "other": "%lld donnes"},
    "gl": {"one": "%lld rolda", "other": "%lld roldas"},
    "gu": {"one": "%lld રાઉન્ડ", "other": "%lld રાઉન્ડ"},
    "he": {"one": "סיבוב אחד", "two": "שני סיבובים", "other": "%lld סיבובים"},
    "hi": {"one": "%lld राउंड", "other": "%lld राउंड"},
    "hr": {"one": "%lld runda", "few": "%lld runde", "other": "%lld rundi"},
    "hu": {"one": "%lld kör", "other": "%lld kör"},
    "hy": {"one": "%lld փուլ", "other": "%lld փուլ"},
    "id": {"other": "%lld babak"},
    "is": {"one": "%lld umferð", "other": "%lld umferðir"},
    "it": {"one": "%lld giro", "other": "%lld giri"},
    "ja": {"other": "%lldラウンド"},
    "ka": {"one": "%lld რაუნდი", "other": "%lld რაუნდი"},
    "kk": {"one": "%lld раунд", "other": "%lld раунд"},
    "km": {"other": "%lld ជុំ"},
    "kn": {"one": "%lld ಸುತ್ತು", "other": "%lld ಸುತ್ತುಗಳು"},
    "ko": {"other": "%lld라운드"},
    "lo": {"other": "%lld ຮອບ"},
    "lt": {"one": "%lld turas", "few": "%lld turai", "many": "%lld turo", "other": "%lld turų"},
    "lv": {"zero": "%lld kārtu", "one": "%lld kārta", "other": "%lld kārtas"},
    "mk": {"one": "%lld круг", "other": "%lld круга"},
    "ml": {"one": "%lld റൗണ്ട്", "other": "%lld റൗണ്ടുകൾ"},
    "mn": {"one": "%lld тойрог", "other": "%lld тойрог"},
    "mr": {"one": "%lld फेरी", "other": "%lld फेऱ्या"},
    "ms": {"other": "%lld pusingan"},
    "my": {"other": "%lld အချီ"},
    "nb": {"one": "%lld runde", "other": "%lld runder"},
    "ne": {"one": "%lld राउन्ड", "other": "%lld राउन्ड"},
    "nl": {"one": "%lld ronde", "other": "%lld rondes"},
    "pa": {"one": "%lld ਦੌਰ", "other": "%lld ਦੌਰ"},
    "pl": {"one": "%lld runda", "few": "%lld rundy", "many": "%lld rund", "other": "%lld rundy"},
    "pt": {"one": "%lld rodada", "other": "%lld rodadas"},
    "pt-PT": {"one": "%lld ronda", "other": "%lld rondas"},
    "ro": {"one": "%lld rundă", "few": "%lld runde", "other": "%lld de runde"},
    "ru": {"one": "%lld раунд", "few": "%lld раунда", "many": "%lld раундов", "other": "%lld раунда"},
    "si": {"one": "%lld වටයක්", "other": "වට %lldක්"},
    "sk": {"one": "%lld kolo", "few": "%lld kolá", "many": "%lld kola", "other": "%lld kôl"},
    "sl": {"one": "%lld krog", "two": "%lld kroga", "few": "%lld krogi", "other": "%lld krogov"},
    "sq": {"one": "%lld raund", "other": "%lld raunde"},
    "sr": {"one": "%lld рунда", "few": "%lld рунде", "other": "%lld рунди"},
    "sr-Latn": {"one": "%lld runda", "few": "%lld runde", "other": "%lld rundi"},
    "sv": {"one": "%lld runda", "other": "%lld rundor"},
    "sw": {"one": "%lld raundi", "other": "%lld raundi"},
    "ta": {"one": "%lld சுற்று", "other": "%lld சுற்றுகள்"},
    "te": {"one": "%lld రౌండ్", "other": "%lld రౌండ్లు"},
    "th": {"other": "%lld รอบ"},
    "tr": {"one": "%lld tur", "other": "%lld tur"},
    "uk": {"one": "%lld раунд", "few": "%lld раунди", "many": "%lld раундів", "other": "%lld раунду"},
    "ur": {"one": "%lld راؤنڈ", "other": "%lld راؤنڈز"},
    "uz": {"one": "%lld tur", "other": "%lld tur"},
    "vi": {"other": "%lld vòng"},
    "zh-Hans": {"other": "%lld 轮"},
    "zh-Hant": {"other": "%lld 輪"},
    "zu": {"one": "%lld umjikelezo", "other": "%lld imijikelezo"},
}


def entry(forms):
    d = {"NSStringFormatSpecTypeKey": "NSStringPluralRuleType", "NSStringFormatValueTypeKey": "lld"}
    d.update(forms)
    return {"NSStringLocalizedFormatKey": "%#@count@", "count": d}


def main():
    root = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "HeartsScoreboard/Localizations")
    locales = sorted(p.name[:-len(".lproj")] for p in root.glob("*.lproj") if (p / "Localizable.strings").exists())
    missing = [l for l in locales if l not in PLURALS]
    extra = [l for l in PLURALS if l not in locales]
    if missing or extra:
        sys.exit(f"locale mismatch: missing {missing}, extra {extra}")
    for loc, forms in PLURALS.items():
        assert "other" in forms and N in forms["other"], loc
        path = root / f"{loc}.lproj" / "Localizable.stringsdict"
        with open(path, "wb") as f:
            plistlib.dump({KEY: entry(forms)}, f, sort_keys=True)
    print(f"wrote {len(PLURALS)} files")


if __name__ == "__main__":
    main()
