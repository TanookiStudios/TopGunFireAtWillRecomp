#!/usr/bin/env python3
"""Fail loudly if a staged release folder holds the game disc, or anything made from it.

    tools/release_scan.py <staged-folder>     scan one package folder
    tools/release_scan.py --self-test         prove the scan can fail

The three make_* scripts run this on the folder BEFORE it is zipped. It checks:
  - no disc/BIOS/memory-card/state files, no disc.cfg (names a path on this
    machine), no overlay_captures.json (holds game code), no generated .c/.h
    source, no generated/disc/src folder;
  - no file is byte-for-byte the disc image or the game's boot program;
  - no file contains any of several 32-byte samples cut from the boot program
    (the game's code) or from the disc image.
"""
import hashlib
import os
import re
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DISC_BIN = os.path.join(ROOT, "disc", "topgunfaw.bin")
BOOT_EXE = os.path.join(ROOT, "disc", "SLUS_000.32")
GAME_TOML = os.path.join(ROOT, "game.toml")

BAD_EXT = {".bin", ".cue", ".iso", ".img", ".chd", ".sub", ".ccd", ".mcd", ".mcr",
           ".state", ".c", ".cpp", ".h", ".32"}
BAD_NAMES = {"disc.cfg", "bios.cfg", "overlay_captures.json"}
BAD_DIRS = {"generated", "disc", "src", "overlay_cache"}
# The engine ships a small C compiler so overlays can turn native on the
# player's machine. Its standard headers are not game code; its folder is
# still searched for game bytes, only the file-type rule is relaxed there.
TOOLCHAIN_DIR = "overlay_toolchain"
SAMPLE_LEN = 32


def expected_sha1():
    with open(GAME_TOML, encoding="utf-8") as f:
        m = re.search(r'known_sha1\s*=\s*\[\s*"([0-9a-f]{40})"', f.read())
    if not m:
        sys.exit("release_scan: no known_sha1 in game.toml")
    return m.group(1)


def pick_samples(blob):
    """Several 32-byte windows with plenty of distinct bytes (not blank runs)."""
    out = []
    for i in range(1, 8):
        base = len(blob) * i // 8
        for off in range(base, min(base + 65536, len(blob) - SAMPLE_LEN)):
            w = blob[off:off + SAMPLE_LEN]
            if len(set(w)) >= 20:
                out.append(w)
                break
    if len(out) < 5:
        sys.exit("release_scan: could not pick game samples")
    return out


def scan(folder, game):
    disc, exe = game
    whole = {hashlib.sha256(disc).hexdigest(), hashlib.sha256(exe).hexdigest()}
    samples = pick_samples(exe) + pick_samples(disc)
    problems, nfiles, nbytes = [], 0, 0
    for dirpath, dirnames, filenames in os.walk(folder):
        in_toolchain = TOOLCHAIN_DIR in os.path.relpath(dirpath, folder).split(os.sep)
        for d in dirnames:
            if d in BAD_DIRS:
                problems.append(f"forbidden folder: {os.path.join(dirpath, d)}")
        for name in filenames:
            p = os.path.join(dirpath, name)
            nfiles += 1
            ext = os.path.splitext(name)[1].lower()
            if name.lower() in BAD_NAMES or (ext in BAD_EXT and not (in_toolchain and ext == ".h")):
                problems.append(f"forbidden file type: {p}")
            if os.path.islink(p):
                problems.append(f"symlink (not scanned): {p}")
                continue
            with open(p, "rb") as f:
                data = f.read()
            nbytes += len(data)
            if hashlib.sha256(data).hexdigest() in whole:
                problems.append(f"IS THE DISC OR BOOT PROGRAM: {p}")
            for i, s in enumerate(samples):
                if s in data:
                    problems.append(f"contains game bytes (sample {i}): {p}")
                    break
    return problems, nfiles, nbytes, len(samples)


def load_game():
    for path in (DISC_BIN, BOOT_EXE):
        if not os.path.isfile(path):
            sys.exit(f"release_scan: {path} not found; cannot prove the package is clean "
                     "(run ./setup.sh and tools/regen.sh with your disc)")
    with open(DISC_BIN, "rb") as f:
        disc = f.read()
    if hashlib.sha1(disc).hexdigest() != expected_sha1():
        sys.exit("release_scan: disc/topgunfaw.bin is not the expected disc (SHA-1 mismatch)")
    with open(BOOT_EXE, "rb") as f:
        exe = f.read()
    return disc, exe


def self_test(game):
    """Each bad package must be caught; a clean one must pass."""
    disc, exe = game
    code = pick_samples(exe)[2]
    data = pick_samples(disc)[4]
    cases = {
        "game code inside a binary": lambda d: open(os.path.join(d, "prog"), "wb").write(b"x" * 99 + code + b"y" * 99),
        "disc bytes inside a data file": lambda d: open(os.path.join(d, "pack.dat"), "wb").write(b"x" * 99 + data),
        "a .cue file": lambda d: open(os.path.join(d, "game.cue"), "w").write("x"),
        "disc.cfg": lambda d: open(os.path.join(d, "disc.cfg"), "w").write("disc/x.cue"),
        "overlay_captures.json": lambda d: open(os.path.join(d, "overlay_captures.json"), "w").write("{}"),
        "a generated .c file": lambda d: open(os.path.join(d, "SLUS_000.32_full_00.c"), "w").write("int x;"),
        "game code hidden in the compiler folder": lambda d: (os.makedirs(os.path.join(d, TOOLCHAIN_DIR)),
            open(os.path.join(d, TOOLCHAIN_DIR, "x.h"), "wb").write(code)),
        "the boot program renamed": lambda d: open(os.path.join(d, "data.dat"), "wb").write(exe),
    }
    for label, make in cases.items():
        with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as d:
            make(d)
            problems = scan(d, game)[0]
            if not problems:
                sys.exit(f"SELF-TEST FAILED: scan did not catch {label}")
            print(f"  caught {label}: {problems[0].split(':')[0]}")
    with tempfile.TemporaryDirectory(dir=os.environ.get("TMPDIR")) as d:
        open(os.path.join(d, "prog"), "wb").write(os.urandom(4096))
        os.makedirs(os.path.join(d, TOOLCHAIN_DIR))
        open(os.path.join(d, TOOLCHAIN_DIR, "stdio.h"), "w").write("int printf(const char*, ...);")
        if scan(d, game)[0]:
            sys.exit("SELF-TEST FAILED: clean folder was flagged")
    print("  clean folder passes")
    print("release_scan self-test OK")


def main():
    if len(sys.argv) == 2 and sys.argv[1] == "--self-test":
        self_test(load_game())
        return
    if len(sys.argv) != 2 or not os.path.isdir(sys.argv[1]):
        sys.exit(__doc__)
    problems, nfiles, nbytes, ns = scan(sys.argv[1], load_game())
    if problems:
        print("DISC SAFETY SCAN FAILED, do not ship this package:", file=sys.stderr)
        for p in problems:
            print("  " + p, file=sys.stderr)
        sys.exit(1)
    print(f"Disc safety scan passed: {nfiles} files, {nbytes} bytes, {ns} game samples, "
          "SHA-256 compared, no disc-type files")


if __name__ == "__main__":
    main()
