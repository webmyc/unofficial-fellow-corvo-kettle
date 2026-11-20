#!/bin/bash
# removes everything install.sh added. your config (~/.config/kettle) is kept unless you pass --all.
set -u
LABEL="io.github.unofficial-fellow-corvo-kettle"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null
rm -f "$HOME/Library/LaunchAgents/$LABEL.plist"
rm -f "$HOME/.local/bin/kettle" "$HOME/.local/bin/kettle-api"
rm -rf "$HOME/.local/share/unofficial-fellow-corvo-kettle"
rm -rf "$HOME/Applications/Unofficial Fellow Corvo Kettle.app"
PD="$(defaults read com.ameba.SwiftBar PluginDirectory 2>/dev/null || true)"
[ -n "$PD" ] && rm -f "$PD/kettle.10s.sh"
[ "${1:-}" = "--all" ] && rm -rf "$HOME/.config/kettle"
echo "uninstalled. (SwiftBar itself was left in place.)"
