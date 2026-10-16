#!/usr/bin/env bash
# Make the 12 release screenshots in docs/screenshots/ with nobody at the
# keyboard. Everything runs in a HIDDEN window (never shown on screen) from
# build-test/ (made with -DPSX_DEBUG_TOOLS=ON), whose settings live in that
# build folder, never in the player's own settings folder.
# Needs: build-test/ and build/, your disc at disc/topgunfaw.cue.
# Fails loudly if any of the 12 pictures is missing.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT=docs/screenshots
TMP=work/shots
rm -rf "$TMP"; mkdir -p "$TMP" "$OUT"

# Gameplay and the Esc menu: scripted routes driving the real game.
python3 -I tests/psx_tcp.py route tests/route_screenshots.txt "$TMP/a" --window
TGFAW_START=5 python3 -I tests/psx_tcp.py route tests/route_screenshots_ocean.txt "$TMP/b" --window
cp "$TMP"/a/*.png "$TMP"/b/*.png "$OUT/"

# Launcher pages: the launcher's own script hook, hidden window.
( cd build && LNG_TEST_HIDDEN=1 LNG_SCRIPT="wait:30;shot:../$OUT/launcher-main.png;view:game;wait:10;shot:../$OUT/launcher-game.png;view:settings;wait:10;shot:../$OUT/launcher-settings.png;view:about;wait:10;shot:../$OUT/launcher-about.png;quit" \
    ./TopGunFireAtWill --launcher --disc ../disc/topgunfaw.cue >/dev/null 2>&1 ) || true

MISSING=""
for n in gameplay-1 gameplay-2 gameplay-3 gameplay-4 gameplay-5 gameplay-6 gameplay-7 \
         launcher-main launcher-game launcher-settings launcher-about ingame-menu; do
    [ -s "$OUT/$n.png" ] && [ "$OUT/$n.png" -nt "$TMP" ] || MISSING="$MISSING $n"
done
[ -z "$MISSING" ] || { echo "FAIL: screenshots missing or stale:$MISSING" >&2; exit 1; }
echo "12 screenshots in $OUT"
