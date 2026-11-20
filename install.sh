#!/bin/bash
# Unofficial Fellow Corvo Kettle: installer for macOS.
# installs the `kettle` command, the control panel (a tiny localhost server that starts
# at login), a Spotlight app, and optionally a menu-bar control via SwiftBar.
#
#   ./install.sh                     find the kettle automatically
#   KETTLE_IP=192.168.1.50 ./install.sh
#   KETTLE_MODEL="Stagg EKG Pro" ./install.sh
#   ./install.sh --no-menubar
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Unofficial Fellow Corvo Kettle"
LABEL="io.github.unofficial-fellow-corvo-kettle"
BIN="$HOME/.local/bin"
SHARE="$HOME/.local/share/unofficial-fellow-corvo-kettle"
CFG_DIR="$HOME/.config/kettle"
CFG="$CFG_DIR/config"
PORT="${KETTLE_PANEL_PORT:-8737}"
MENUBAR=1
for a in "$@"; do [ "$a" = "--no-menubar" ] && MENUBAR=0; done

say() { printf "\033[1m%s\033[0m\n" "$*"; }
[ "$(uname)" = "Darwin" ] || { echo "this installer is for macOS."; exit 1; }
command -v python3 >/dev/null || { echo "python3 is required (xcode-select --install)."; exit 1; }
if ! command -v jq >/dev/null; then
  if command -v brew >/dev/null; then brew install jq; else echo "jq is required (brew install jq)."; exit 1; fi
fi

say "installing the kettle command"
mkdir -p "$BIN" "$SHARE" "$CFG_DIR"
install -m 755 bin/kettle bin/kettle-api "$BIN/"
cp panel/server.py panel/index.html "$SHARE/"

if [ -n "${KETTLE_IP:-}" ]; then
  echo "KETTLE_IP=$KETTLE_IP" > "$CFG"
elif [ ! -f "$CFG" ] || ! grep -q '^KETTLE_IP=.' "$CFG"; then
  say "looking for your kettle (make sure it's on and not boiling)"
  "$BIN/kettle" find || { echo "couldn't find it. run '$BIN/kettle find' later, or re-run with KETTLE_IP=x.x.x.x"; }
fi
grep -q '^KETTLE_MODEL=' "$CFG" 2>/dev/null || echo "KETTLE_MODEL=\"${KETTLE_MODEL:-Corvo EKG Pro}\"" >> "$CFG"

say "starting the control panel (localhost:$PORT)"
PL="$HOME/Library/LaunchAgents/$LABEL.plist"
mkdir -p "$(dirname "$PL")"
cat > "$PL" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array>
    <string>/usr/bin/python3</string><string>$SHARE/server.py</string>
  </array>
  <key>EnvironmentVariables</key><dict><key>KETTLE_PANEL_PORT</key><string>$PORT</string></dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardErrorPath</key><string>/tmp/unofficial-fellow-corvo-kettle.log</string>
</dict></plist>
PLIST
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PL"

say "adding '$APP_NAME' to ~/Applications"
APP="$HOME/Applications/$APP_NAME.app"
mkdir -p "$HOME/Applications"
rm -rf "$APP"
osacompile -o "$APP" -e "open location \"http://localhost:$PORT\""
if [ -f assets/icon.png ]; then
  T="$(mktemp -d)"; IS="$T/icon.iconset"; mkdir "$IS"
  for s in 16 32 128 256 512; do
    sips -z $s $s assets/icon.png --out "$IS/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) assets/icon.png --out "$IS/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$IS" -o "$APP/Contents/Resources/applet.icns" && touch "$APP"
  rm -rf "$T"
fi

if [ "$MENUBAR" = 1 ]; then
  if [ ! -d /Applications/SwiftBar.app ] && command -v brew >/dev/null; then
    say "installing SwiftBar for the menu-bar control"
    brew install --cask swiftbar || true
  fi
  if [ -d /Applications/SwiftBar.app ]; then
    PD="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
    if [ -z "$PD" ]; then
      PD="$HOME/Library/Application Support/SwiftBar/Plugins"
      defaults write com.ameba.SwiftBar PluginDirectory "$PD"
    fi
    mkdir -p "$PD"
    install -m 755 menubar/kettle.10s.sh "$PD/kettle.10s.sh"
    open -ga SwiftBar
    open -g "swiftbar://refreshallplugins" 2>/dev/null || true
  else
    echo "skipping the menu bar (needs SwiftBar: brew install --cask swiftbar)."
  fi
fi

case ":$PATH:" in *":$BIN:"*) ;; *)
  echo; echo "add this to your ~/.zshrc so 'kettle' works everywhere:"
  echo "  export PATH=\"\$HOME/.local/bin:\$PATH\"" ;;
esac

echo
say "done."
echo "  open the panel:   Spotlight → \"$APP_NAME\"   (or http://localhost:$PORT)"
echo "  terminal:         kettle help"
echo
echo "macOS may ask whether python3 can find devices on your local network."
echo "click Allow, otherwise the panel can't reach the kettle."
sleep 1
open "http://localhost:$PORT"
