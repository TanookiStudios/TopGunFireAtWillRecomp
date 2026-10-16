#!/usr/bin/env python3
"""Catch the moment something changes on screen and keep the RAM from just
before and just after it (for notes/ram-map.md work).

    tests/catch_event.py <route.txt> <out-dir> x0 y0 x1 y1 [max-seconds] [events]

events (default 1): how many jumps to catch; each saves beforeN/afterN.
TGFAW_WTRACE=lo-hi (hex): also log every game write in that range and, at
each jump, save the writes from the frames around it to writesN.json.

Plays the route, then keeps snapshotting: screenshot + full RAM every few
frames. Inside the rectangle (320x240 picture coordinates) it counts warm
pixels (the HUD's damage orange). When that count jumps, it saves before.ram/.png and
after.ram/.png and stops. Uses build-test (debug port).
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import psx_tcp  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))


def png_rows(path):
    import zlib, struct
    d = open(path, "rb").read()
    i, idat, w, h = 8, b"", 0, 0
    while i < len(d):
        n, t = struct.unpack(">I4s", d[i:i + 8])
        if t == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", d[i + 8:i + 18])
            bpp = 3 if ctype == 2 else 4
        elif t == b"IDAT":
            idat += d[i + 8:i + 8 + n]
        i += 12 + n
    raw = zlib.decompress(idat)
    rows, prev, stride, p = [], bytearray(w * bpp), w * bpp, 0
    for _ in range(h):
        f, line = raw[p], bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        rows.append(bytes(line))
        prev = line
    return w, h, bpp, rows


def warm(path, box):
    w, h, bpp, rows = png_rows(path)
    sx, sy = w / 320, h / 240
    x0, y0, x1, y1 = (int(box[0] * sx), int(box[1] * sy), int(box[2] * sx), int(box[3] * sy))
    n = 0
    for y in range(y0, y1):
        r = rows[y]
        for x in range(x0, x1):
            R, G, B = r[x * bpp], r[x * bpp + 1], r[x * bpp + 2]
            if R >= 90 and R > G + 15 and B < 40:   # the HUD's damage orange
                n += 1
    return n


def main():
    if len(sys.argv) < 7:
        sys.exit(__doc__)
    route, out = sys.argv[1], sys.argv[2]
    box = [int(v) for v in sys.argv[3:7]]
    limit = float(sys.argv[7]) if len(sys.argv) > 7 else 240
    events = int(sys.argv[8]) if len(sys.argv) > 8 else 1
    caught = 0
    os.makedirs(out, exist_ok=True)
    psx_tcp.route(route, out, keep_running=True)
    g = psx_tcp.LAST_GAME
    wt = os.environ.get("TGFAW_WTRACE")
    if wt:
        lo, hi = wt.split("-")
        g.cmd("wtrace_range", lo=lo, hi=hi)
        g.cmd("wtrace_clear")
    try:
        prev_png, prev_ram, base, t0, k = None, None, None, time.time(), 0
        while time.time() - t0 < limit:
            png = os.path.join(out, f"s{k % 2}.png")
            try:
                g.cmd("screenshot", path=png)
            except RuntimeError:
                time.sleep(0.05)
                continue
            ram = bytes.fromhex(g.cmd("read_ram", addr="0x80000000", len=0x200000)["hex"])
            n = warm(png, box)
            if base is None:
                base = n
            elif n > base + 60 and prev_ram is not None:
                caught += 1
                sfx = "" if events == 1 else str(caught)
                open(os.path.join(out, f"before{sfx}.ram"), "wb").write(prev_ram)
                open(os.path.join(out, f"after{sfx}.ram"), "wb").write(ram)
                os.replace(prev_png, os.path.join(out, f"before{sfx}.png"))
                os.replace(png, os.path.join(out, f"after{sfx}.png"))
                fr = g.frame()
                print(f"caught at frame {fr}: warm pixels {base} -> {n}")
                if wt:
                    import json
                    lo, hi = (int(v, 16) for v in wt.split("-"))
                    allw = []
                    for a in range(lo, hi, 0x400):   # the dump returns at most 2048 per call
                        d = g.cmd("wtrace_dump", addr_lo=f"0x{a:08X}", addr_hi=f"0x{a + 0x3FF:08X}",
                                  count=2048, newest=1)
                        allw += d.get("entries", [])
                    json.dump(allw, open(os.path.join(out, f"writes{sfx}.json"), "w"))
                    print(f"  saved {len(allw)} writes")
                if caught == events:
                    return
                base, prev_png, prev_ram = n, None, None
                k += 1
                continue
            prev_png, prev_ram, k = png, ram, k + 1
        print("nothing happened within the time limit")
    finally:
        g.close()


if __name__ == "__main__":
    main()
