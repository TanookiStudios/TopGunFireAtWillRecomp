#!/usr/bin/env python3
"""Drive a headless test build over its debug port (needs build-test/, made with
-DPSX_DEBUG_TOOLS=ON; release builds have no port).

    tests/psx_tcp.py shots <out-dir> [seconds] [every-frames]
        boot the game headless and save a PNG every N frames
    tests/psx_tcp.py route <route.txt> <out-dir> [--window]
        boot, play a scripted route, save the shots it asks for
        --window: a hidden real window (OpenGL, the Esc menu works) instead
        of headless; still never shown on screen

Route file: one step per line, '#' comments.
    hold <buttons> <frames>     buttons: up down left right cross circle square
                                triangle l1 l2 r1 r2 start select, joined by '+', or 'none'
    shot <name>                 PNG of the current frame
    ram <name>                  full 2 MB main RAM dump (for tools/ram_find.py)
    wait <frames>               same as 'hold none'
    sleep <ms>                  wall-clock wait (the game is paused while a menu is open)
    key <SDL key name>          press and release a keyboard key (Escape, Down, Return)
    pshot <name>                PNG of the window as the player sees it, menu
                                included (--window runs only)
    poke <hex addr> <hex byte>  write one byte of main RAM
    audio <name>                print the sound output's audible-sample count and peak
    spu <name>                  print the sound chip's reverb / CD / voice-echo settings
    include <route.txt>         run another route's steps here (path relative to this file)
"""
import json
import os
import socket
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXE = os.path.join(ROOT, "build-test", "TopGunFireAtWill")
PORT = 4370
# PS1 pad bits (pressed = 0 in the inverted mask the runtime takes).
BITS = {"select": 0, "l3": 1, "r3": 2, "start": 3, "up": 4, "right": 5, "down": 6, "left": 7,
        "l2": 8, "r2": 9, "l1": 10, "r1": 11, "triangle": 12, "circle": 13, "cross": 14, "square": 15}


class Game:
    def __init__(self, log_path, window=False):
        self.proc = subprocess.Popen(
            [EXE, "--hidden-window" if window else "--headless", "--debug-port", str(PORT),
             "--disc", "../disc/topgunfaw.cue"],
            cwd=os.path.dirname(EXE), stdout=open(log_path, "w"), stderr=subprocess.STDOUT)
        for _ in range(300):
            try:
                socket.create_connection(("127.0.0.1", PORT), timeout=30).close()
                break
            except OSError:
                if self.proc.poll() is not None:
                    sys.exit(f"game exited early (code {self.proc.returncode}); see {log_path}")
                time.sleep(0.1)
        else:
            self.proc.kill()
            sys.exit("debug port never opened (is build-test built with -DPSX_DEBUG_TOOLS=ON?)")
        self.n = 0

    def cmd(self, c, **k):
        # The server answers one JSON object per request and may close the
        # connection afterwards, so each command gets its own connection.
        self.n += 1
        with socket.create_connection(("127.0.0.1", PORT), timeout=60) as s:
            s.sendall((json.dumps({"id": self.n, "cmd": c, **k}) + "\n").encode())
            buf = b""
            while True:
                chunk = s.recv(1 << 20)
                if chunk:
                    buf += chunk
                if buf.rstrip().endswith(b"}") or not chunk:
                    try:
                        r = json.loads(buf)
                        break
                    except ValueError:
                        if not chunk:
                            raise RuntimeError(f"{c}: connection closed mid-reply ({len(buf)} bytes)")
        if not r.get("ok"):
            raise RuntimeError(f"{c}: {r.get('error')}")
        return r

    def frame(self):
        return self.cmd("frame")["frame"]

    def wait_frames(self, n):
        target = self.frame() + n
        while self.frame() < target:
            if self.proc.poll() is not None:
                sys.exit("game exited during the route")
            time.sleep(0.01)

    def close(self):
        try:
            self.cmd("quit")
        except Exception:
            pass
        try:
            self.proc.wait(5)
        except subprocess.TimeoutExpired:
            self.proc.kill()


def mask(buttons):
    m = 0xFFFF
    if buttons != "none":
        for b in buttons.split("+"):
            m &= ~(1 << BITS[b])
    return m


def shots(out, seconds=90, every=300):
    os.makedirs(out, exist_ok=True)
    g = Game(os.path.join(out, "run.log"))
    t0, k = time.time(), 0
    try:
        while time.time() - t0 < seconds:
            fr = g.frame()
            if fr >= k * every:
                g.cmd("screenshot", path=os.path.join(out, f"f{k:03d}_{fr}.png"))
                k += 1
            time.sleep(0.2)
        print(f"reached frame {g.frame()}, {k} shots in {out}")
    finally:
        g.close()


def present_shot(g, path):
    seq = g.cmd("present_shot_seq")["seq"]
    g.cmd("present_shot", path=path)
    for _ in range(500):
        r = g.cmd("present_shot_seq")
        if r["seq"] != seq:
            if not r.get("wrote"):
                raise RuntimeError(f"present_shot wrote nothing for {path}")
            return
        time.sleep(0.01)
    raise RuntimeError("present_shot never completed")


def steps(path):
    for line in open(path):
        w = line.split("#")[0].split()
        if w and w[0] == "include":
            yield from steps(os.path.join(os.path.dirname(path), w[1]))
        else:
            yield line


LAST_GAME = None


def route(path, out, window=False, keep_running=False):
    """Every hold/wait is queued up front in the runtime's input route, which
    counts the game's own pad reads, so inputs land on the same game frame in
    every run. Captures (shot, ram, ...) run as the route reaches them, a
    frame or two late at most; key/sleep/pshot are for the paused menu."""
    os.makedirs(out, exist_ok=True)
    inputs, actions = [], []          # actions: (input index reached, step words)
    for line in steps(path):
        w = line.split("#")[0].split()
        if not w:
            continue
        if w[0] in ("hold", "wait"):
            buttons, n = ("none", int(w[1])) if w[0] == "wait" else (w[1], int(w[2]))
            inputs.append((mask(buttons), n))
        else:
            actions.append((len(inputs), w))
    g = Game(os.path.join(out, "run.log"), window)
    try:
        g.cmd("input_route_clear")
        for b, n in inputs:
            g.cmd("input_route_append", buttons=b, frames=n)
        if inputs:
            g.cmd("input_route_start", at_frame=30)   # same guest frame every run

        def reached(k):          # all inputs before position k are done
            if k == 0:
                return True
            st = g.cmd("input_route_status")
            return not st["active"] or st["index"] >= k

        for k, w in actions:
            while not reached(k):
                if g.proc.poll() is not None:
                    sys.exit("game exited during the route")
                time.sleep(0.005)
            do_action(g, w, out)
        while not reached(len(inputs)):
            time.sleep(0.01)
        print(f"route done at frame {g.frame()}")
    finally:
        if keep_running:
            global LAST_GAME
            LAST_GAME = g
        else:
            g.close()


def do_action(g, w, out):
    if w[0] == "shot":
        for tries in range(60):   # the game blanks the display between screens
            try:
                g.cmd("screenshot", path=os.path.join(out, w[1] + ".png"))
                return
            except RuntimeError as e:
                if "display disabled" not in str(e):
                    raise
                g.wait_frames(5)
        print(f"shot {w[1]}: display stayed off (blank screen), no picture")
    elif w[0] == "ram":
        data = bytes.fromhex(g.cmd("read_ram", addr="0x80000000", len=0x200000)["hex"])
        open(os.path.join(out, w[1] + ".ram"), "wb").write(data)
    elif w[0] == "poke":
        g.cmd("write_ram", addr=w[1], val=w[2])
    elif w[0] == "audio":
        taps = {x["name"]: x for x in g.cmd("audio_stats")["taps"]}
        o = taps["spu_out"]
        print(f"audio {w[1]}: frames={o['frames']} audible={o.get('audible')} peak={o.get('peak')}")
    elif w[0] == "spu":
        r = g.cmd("spu_status")
        print(f"spu {w[1]}: ctrl={r['ctrl']} reverb_on={r['reverb_on']} eon={r['eon']} "
              f"mbase={r['reverb_mbase']} cd_vol={r['cd_l']}")
    elif w[0] == "sleep":
        time.sleep(int(w[1]) / 1000)
    elif w[0] == "key":
        g.cmd("host_key", name=w[1])
        time.sleep(0.15)
    elif w[0] == "pshot":
        present_shot(g, os.path.join(out, w[1] + ".png"))
    else:
        sys.exit(f"unknown route step: {' '.join(w)}")


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["shots"] and len(a) >= 2:
        shots(a[1], *(int(x) for x in a[2:4]))
    elif a[:1] == ["route"] and len(a) in (3, 4):
        route(a[1], a[2], window=a[3:] == ["--window"])
    else:
        sys.exit(__doc__)
