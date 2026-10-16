#!/usr/bin/env python3
"""Find PlayStation main-RAM values that behave a given way across snapshots
(the 2 MB .ram dumps a route's `ram <name>` step saves). Used to build
notes/ram-map.md; not part of the game build.

    tools/ram_find.py <dir> a=50 b=49 c=49 [--size 1|2|4]
        addresses whose value is 50 in a.ram, 49 in b.ram, 49 in c.ram
    tools/ram_find.py <dir> a=? b=-1 [--size N]
        '?' any value; '-N' / '+N' relative to the previous snapshot's value
    tools/ram_find.py <dir> a=same b=same c=diff
        'same' / 'diff' compared with the previous snapshot

Addresses print as PlayStation addresses (0x80xxxxxx).
"""
import os
import sys


def main():
    args = sys.argv[1:]
    size = 1
    if "--size" in args:
        i = args.index("--size")
        size = int(args[i + 1])
        del args[i:i + 2]
    if len(args) < 2:
        sys.exit(__doc__)
    folder, rules = args[0], [a.split("=", 1) for a in args[1:]]
    snaps = [open(os.path.join(folder, name + ".ram"), "rb").read() for name, _ in rules]
    n = min(len(s) for s in snaps)
    hits = []
    for addr in range(0, n - size + 1, size):
        vals = [int.from_bytes(s[addr:addr + size], "little") for s in snaps]
        ok = True
        for k, (_, rule) in enumerate(rules):
            v = vals[k]
            prev = vals[k - 1] if k else None
            if rule == "?":
                continue
            if rule == "same":
                ok = prev is not None and v == prev
            elif rule == "diff":
                ok = prev is not None and v != prev
            elif rule[0] in "+-" and k:
                ok = v == prev + int(rule)
            else:
                ok = v == int(rule, 0)
            if not ok:
                break
        if ok:
            hits.append((addr, vals))
    for addr, vals in hits[:60]:
        print(f"0x{0x80000000 + addr:08X}  " + " ".join(str(v) for v in vals))
    print(f"{len(hits)} match(es)")


if __name__ == "__main__":
    main()
