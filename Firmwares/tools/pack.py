#!/usr/bin/env python3
"""Pack a firmware package folder into a single-file .fm1fw bundle.

usage: python3 Firmwares/tools/pack.py Firmwares/<package> [more packages…] [-o OUTDIR]

The bundle is JSON: {"fm1fw": 1, "files": {"manifest.json": "...", "<script>": "..."}}.
Install it in FM Pocket from Firmware → Install from URL… (host it anywhere) or from Files.
"""
import json, os, sys

def pack(folder, outdir):
    with open(os.path.join(folder, "manifest.json"), encoding="utf-8") as f:
        manifest_text = f.read()
    man = json.loads(manifest_text)
    if man.get("runtime") != "script":
        raise SystemExit(f"{folder}: only script firmwares can be packed (runtime is {man.get('runtime')!r})")
    files = {"manifest.json": manifest_text}
    for name in man.get("scripts", []):
        if "/" in name or name.startswith("."):
            raise SystemExit(f"{folder}: bad script name {name!r}")
        with open(os.path.join(folder, name), encoding="utf-8") as f:
            files[name] = f.read()
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, man["id"] + ".fm1fw")
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"fm1fw": 1, "files": files}, f, ensure_ascii=False)
    print(f"{out}  ({os.path.getsize(out)} bytes, {len(files) - 1} scripts)")

if __name__ == "__main__":
    args = sys.argv[1:]
    outdir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "dist")
    if "-o" in args:
        i = args.index("-o"); outdir = args[i + 1]; del args[i:i + 2]
    if not args:
        raise SystemExit(__doc__)
    for a in args:
        pack(a.rstrip("/"), os.path.normpath(outdir))
