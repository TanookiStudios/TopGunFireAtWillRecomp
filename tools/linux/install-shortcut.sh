#!/bin/sh
# Adds Top Gun Fire at Will to the application menu for this user only.
here="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/256x256/apps"
cp "$here/topgunfaw.png" "$HOME/.local/share/icons/hicolor/256x256/apps/topgunfaw.png"
sed "s|^Exec=.*|Exec=\"$here/TopGunFireAtWill\"|" "$here/topgunfaw.desktop" > "$HOME/.local/share/applications/topgunfaw.desktop"
echo "Added Top Gun Fire at Will to your application menu."
