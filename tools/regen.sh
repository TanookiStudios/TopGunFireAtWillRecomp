#!/usr/bin/env bash
# Translate your disc's game code into C (generated/, never committed).
# Checks the disc against the digests in game.toml, builds the engine's
# translators the first time, makes the OpenBIOS C, then the game C.
set -euo pipefail
cd "$(dirname "$0")/.."
DISC=$(tr -d '\n' < disc.cfg 2>/dev/null || echo disc/topgunfaw.cue)
[ -f "$DISC" ] || { echo "No disc at $DISC (see README: Building it yourself)" >&2; exit 1; }
python3 vendor/psxrecomp/psxrecomp_cli.py generate \
    --config game.toml --project-root . --disc "$DISC" --no-toolchain-download "$@"
