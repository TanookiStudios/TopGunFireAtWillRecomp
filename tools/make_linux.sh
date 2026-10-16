#!/usr/bin/env bash
# Build the Linux version (64-bit Intel/AMD) in an Ubuntu 20.04 container under
# Colima, and pack dist/TopGunFireAtWill-Linux.tar.gz (copied to ~/Downloads).
# Needs: colima running (colima start --vm-type vz --vz-rosetta --arch aarch64),
# vendor/ from setup.sh, generated/ from tools/regen.sh, and your disc (only to
# scan the package for game bytes). SDL3 is built from source inside the
# container and linked in statically.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p work/docker-config; [ -f work/docker-config/config.json ] || echo '{}' > work/docker-config/config.json
export DOCKER_CONFIG="$PWD/work/docker-config" DOCKER_HOST="unix://$HOME/.colima/default/docker.sock"
docker image inspect topgunfaw-linux-build >/dev/null 2>&1 || docker build --platform linux/amd64 -t topgunfaw-linux-build tools/linux
docker run --rm --platform linux/amd64 -v "$PWD":/src topgunfaw-linux-build /src/tools/linux/build.sh > work/build-linux.log 2>&1 || { grep -E "error|FAILED|undefined" work/build-linux.log | head -20 >&2; exit 1; }

bash tools/stage_release.sh build-linux linux-x64
OUT=dist/TopGunFireAtWill-Linux
rm -rf "$OUT" "$OUT.tar.gz"
cp -R dist/stage-game-linux-x64 "$OUT"
cp assets/icon/topgunfaw-256.png "$OUT/topgunfaw.png"
cp tools/linux/topgunfaw.desktop tools/linux/README-Linux.txt tools/linux/install-shortcut.sh "$OUT/"

# Checks: 64-bit Intel/AMD, and no libraries beyond what any 2020+ desktop has.
# (SDL3 is inside the program; it opens the sound and window libraries itself at run time.
# zlib is a "required" package on Debian/Ubuntu, so every desktop has libz.so.1.)
file "$OUT/TopGunFireAtWill" | grep -q "ELF 64-bit.*x86-64" || { echo "FAIL: not a 64-bit Intel/AMD program" >&2; exit 1; }
NEEDED=$(docker run --rm --platform linux/amd64 -v "$PWD/$OUT":/pkg topgunfaw-linux-build sh -c 'ldd /pkg/TopGunFireAtWill' | awk '{print $1}')
echo "Libraries the program needs:"; echo "$NEEDED" | sed 's/^/  /'
BAD=$(echo "$NEEDED" | grep -v -E '^(linux-vdso\.so\.1|/lib64/ld-linux-x86-64\.so\.2|libc\.so\.6|libm\.so\.6|libdl\.so\.2|libpthread\.so\.0|librt\.so\.1|libGL\.so\.1|libGLdispatch\.so\.0|libGLX\.so\.0|libstdc\+\+\.so\.6|libgcc_s\.so\.1|libX11\.so\.6|libxcb\.so\.1|libXau\.so\.6|libXdmcp\.so\.6|libbsd\.so\.0|libmd\.so\.0|libz\.so\.1)$' || true)
[ -z "$BAD" ] || { echo "FAIL: unusual libraries needed:" >&2; echo "$BAD" >&2; exit 1; }
python3 -I tools/release_scan.py "$OUT"

tar -C dist -czf "$OUT.tar.gz" TopGunFireAtWill-Linux
# Finished games always go to Downloads (Maddie, 14 Oct 2026).
cp -f "$OUT.tar.gz" "$HOME/Downloads/"
echo "$HOME/Downloads/TopGunFireAtWill-Linux.tar.gz"
