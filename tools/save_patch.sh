#!/usr/bin/env bash
# Save the changes made in a vendor/ checkout as the NEXT patch file, on top of
# the patches already in patches/ for it.
#   tools/save_patch.sh psxrecomp 0002-mac-settings-in-application-support
#   tools/save_patch.sh recomp-ui recomp-ui-0003-something
set -euo pipefail
cd "$(dirname "$0")/.."
dir=$1; name=$2
case $dir in recomp-ui) glob="patches/recomp-ui-*.patch";; psxrecomp) glob="patches/0*.patch";; *) exit 1;; esac
[ -e "patches/$name.patch" ] && { echo "patches/$name.patch exists" >&2; exit 1; }
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
cd "vendor/$dir"
git add -N . 2>/dev/null || true
git diff --name-only | while read -r f; do mkdir -p "$tmp/$(dirname "$f")"; [ -e "$f" ] && cp "$f" "$tmp/$f"; done
git diff --name-only --diff-filter=A > "$tmp/.added"
git reset -q; git checkout -q .; git clean -qfd -- $(cat "$tmp/.added") 2>/dev/null || true
for p in ../../$glob; do [ -f "$p" ] && git apply "$p"; done
git add -A
(cd "$tmp" && find . -type f ! -name .added) | while read -r f; do mkdir -p "$(dirname "$f")"; cp "$tmp/$f" "$f"; done
git add -N .
git diff > "../../patches/$name.patch"
git reset -q
echo "saved patches/$name.patch:"; git diff --stat --cached | tail -1
git diff --stat | tail -1
