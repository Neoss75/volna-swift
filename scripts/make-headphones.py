"""Makes Resources/headphones.txt from a copy of https://github.com/jaakkopasanen/AutoEq (MIT licence).

usage: make-headphones.py <git folder of AutoEq> <commit>
One measurement per model is kept: the best known source wins. A line of the result:
name TAB source TAB preamp TAB filters, each "<L|P|H><hertz>,<dB>,<Q>", separated by ";".
"""
import os
import re
import subprocess
import sys

repo, commit = sys.argv[1:3]
RANK = ["oratory1990", "crinacle", "Rtings", "Super Review", "Regan Cipher", "HypetheSonics", "Innerfidelity", "Headphone.com Legacy"]
KIND = {"LSC": "L", "LS": "L", "PK": "P", "HSC": "H", "HS": "H"}


def git(*a, data=None):
    return subprocess.run(["git", "-C", repo, *a], input=data, capture_output=True, check=True).stdout


def short(x):
    return f"{float(x):g}"


paths = []
for line in git("ls-tree", "-r", "-z", commit, "--", "results").decode().split("\0"):
    if line.endswith(" ParametricEQ.txt"):
        meta, path = line.split("\t", 1)
        paths.append((meta.split()[2], path))
out = git("cat-file", "--batch", data="".join(o + "\n" for o, _ in paths).encode())
best, skipped, at = {}, 0, 0
for oid, path in paths:
    end = out.index(b"\n", at)
    size = int(out[at:end].split()[2])
    text = out[end + 1:end + 1 + size].decode()
    at = end + 2 + size
    parts = path.split("/")
    source, kind, name = parts[1], parts[2], parts[-2]
    pre = re.search(r"Preamp:\s*(-?[\d.]+)", text)
    filters = re.findall(r"ON (\w+) Fc ([\d.]+) Hz Gain (-?[\d.]+) dB Q ([\d.]+)", text)
    filters = [f for f in filters if float(f[2]) != 0]
    if not pre or not filters or any(f[0] not in KIND for f in filters) or "\t" in name:
        skipped += 1
        continue
    rank = RANK.index(source) if source in RANK else len(RANK)
    # measurements of the same source on several rigs: the first in the alphabet, every time the same one
    key, order = name.lower(), (rank, source, kind)
    if key not in best or order < best[key][0]:
        row = ";".join(f"{KIND[k]}{short(f)},{short(g)},{short(q)}" for k, f, g, q in filters)
        best[key] = (order, f"{name}\t{source}\t{short(pre.group(1))}\t{row}")
lines = [best[k][1] for k in sorted(best)]
target = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Resources", "headphones.txt")
with open(target, "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")
print(len(lines), "models,", os.path.getsize(target), "bytes, skipped", skipped)
