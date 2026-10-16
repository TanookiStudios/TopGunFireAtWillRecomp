#!/usr/bin/env bash
# Fetch psxrecomp and recomp-ui into vendor/ at the versions this port was
# tested with, then apply our local changes to them (patches/).
# vendor/ is not committed: anything changed there must live in patches/.
set -euo pipefail
cd "$(dirname "$0")"
PSXRECOMP_COMMIT=379565a6ffc2d399dcb53441dfb0e881ad39b043
RECOMP_UI_COMMIT=0546fbcb0126bb14bf88d2128b4fe8a4229570a3
fetch() {  # fetch <url> <dir> <commit>
    if [ ! -d "vendor/$2/.git" ]; then
        git clone -q "$1" "vendor/$2"
        git -C "vendor/$2" checkout -q "$3"
        git -C "vendor/$2" submodule update -q --init --recursive
    fi
}
fetch https://github.com/mstan/psxrecomp.git psxrecomp "$PSXRECOMP_COMMIT"
fetch https://github.com/RetroPortingToolKit/recomp-ui.git recomp-ui "$RECOMP_UI_COMMIT"
# The engine's own tools look for psxrecomp/ at the project root.
[ -e psxrecomp ] || ln -s vendor/psxrecomp psxrecomp
apply() {  # apply <dir> <patch>
    if git -C "vendor/$1" apply --check "../../$2" 2>/dev/null; then
        git -C "vendor/$1" apply "../../$2" && echo "applied $(basename "$2")"
    else
        echo "$(basename "$2") already applied (or does not fit: check vendor/$1)"
    fi
}
for p in patches/recomp-ui-*.patch; do [ -f "$p" ] && apply recomp-ui "$p"; done
for p in patches/0*.patch; do [ -f "$p" ] && apply psxrecomp "$p"; done
[ -f disc/topgunfaw.cue ] || echo "Put your Top Gun: Fire at Will! (USA) disc at disc/topgunfaw.cue + disc/topgunfaw.bin"
true
