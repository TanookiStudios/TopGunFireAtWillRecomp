#!/usr/bin/env bash
# Gather one platform's release files with the engine's own packager (stage
# only, no zip): dist/stage-game-<artifact>/. Used by make_app.sh,
# make_windows_zip.sh and make_linux.sh.
#   tools/stage_release.sh <build-dir> <artifact>
set -euo pipefail
cd "$(dirname "$0")/.."
BUILD=$1 ART=$2
RELEASE_VERSION=$(tr -d '[:space:]' < VERSION) \
bash vendor/psxrecomp/tools/package_game_release.sh \
    --build-dir "$BUILD" \
    --artifact "$ART" \
    --zip-prefix TopGunFireAtWill \
    --exe-name TopGunFireAtWill \
    --display-name "Top Gun: Fire at Will" \
    --recompiler-build vendor/psxrecomp/recompiler/build \
    --no-overlay-toolchain \
    --ship-without-overlay-cache-because "an overlay cache is compiled from the disc, and nothing made from the disc ships" \
    --disc-hint "your own Top Gun: Fire at Will (USA) disc" \
    --stage-only >/dev/null
# Our own files the engine does not know about.
STAGE="dist/stage-game-$ART"
cp LICENSE THIRD_PARTY_NOTICES.md "$STAGE/"
echo "staged $STAGE"
