"""Checks that every tr("…") text has a Ukrainian and an English translation and that nothing Russian is left outside tr()."""
import os
import re
import sys

root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
read = lambda p: open(os.path.join(root, p), encoding="utf-8").read()
body = read("Shared/Translations.swift").split('#"""\n')[1].split('\n"""#')[0]
table, bad = {}, []
for line in body.split("\n"):
    p = line.split("‖")
    if len(p) != 3:
        bad.append("three parts expected: " + line)
        continue
    if p[0] in table:
        bad.append("twice: " + p[0])
    table[p[0]] = p[1:]
    for t in p[1:]:
        if not t.strip():
            bad.append("empty: " + line)
        if t.count("{}") != p[0].count("{}") or t.count("%") != p[0].count("%"):
            bad.append("different values: " + line)
        if t.startswith(" ") != p[0].startswith(" ") or (t.endswith(" ") and not p[0].endswith(" ")):
            bad.append("different spaces at the ends: " + line)
    if re.search("[а-яё]", p[2], re.I):
        bad.append("Russian letters in English: " + line)
    if re.search("[ыэъё]", p[1], re.I) and "Волне" not in p[1]:  # what is said to Siri stays Russian
        bad.append("Russian letters in Ukrainian: " + line)

# these are Russian on purpose: data, regular expressions, names translated where they are shown
DATA = {"Siri.swift", "MetadataReader.swift", "Demo.swift", "Covers.swift", "Translations.swift", "Lang.swift", "WidgetState.swift"}
LINES = re.compile(r'EQPreset\(id|Accent\(id|case songs = |"я"|"волна"|source: "|"синхр"|lyrics\?\.source|configurationDisplayName|\.description\(|^\s+\("(Аудио|Графика|Музыка|Прочее)"')
used = set()
for top in ("Sources", "Shared", "Widget"):
    for d, _, files in os.walk(os.path.join(root, top)):
        for f in files:
            if not f.endswith(".swift"):
                continue
            for n, l in enumerate(open(os.path.join(d, f), encoding="utf-8").read().split("\n"), 1):
                if f not in ("Translations.swift",):
                    used.update(re.findall(r'tr\("((?:[^"\\]|\\.)*)"', l))
                if f in DATA or LINES.search(l):
                    continue
                rest = re.sub(r'tr\("(?:[^"\\]|\\.)*"', "", l.split("//")[0] if "://" not in l else l)
                if re.search(r'"[^"]*[А-Яа-яЁё]', rest):
                    bad.append(f"not translated: {f}:{n} {l.strip()[:120]}")
for k in sorted(used - set(table)):
    if re.search("[А-Яа-яЁё]", k):
        bad.append("no translation: " + k)
# texts that iOS translates itself
siri = read("Sources/Volna/Siri.swift") + read("Shared/WidgetState.swift")
names = set(re.findall(r'(?:LocalizedStringResource = |shortTitle: |\(title: |\(name: )"([А-Яа-яЁё][^"]*)"', siri))
phrases = {re.sub(r"\\\(\.applicationName\)", "${applicationName}", re.sub(r"\\\(\\\.\$(\w+)\)", r"${\1}", x))
           for x in re.findall(r'^\s+"(.*applicationName\))",$', siri, re.M)}
for code in ("ru", "uk", "en"):
    for path, need in ((f"Shared/{code}.lproj/Localizable.strings", names), (f"Resources/{code}.lproj/AppShortcuts.strings", phrases)):
        have = set(re.findall(r'^"(.*?)" = ', read(path), re.M))
        bad += [f"no text in {path}: {k}" for k in sorted(need - have)]
if len(phrases) < 12 or len(names) < 10:
    bad.append(f"check-texts.py reads Siri.swift wrong: {len(phrases)} {len(names)}")
print(f"{len(table)} texts, {len(used)} used directly")
for b in bad:
    print("::error::" + b)
sys.exit(bool(bad))
