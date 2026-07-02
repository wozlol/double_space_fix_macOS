#!/bin/zsh
set -e

label="com.woz.double-space-fix"
plist="$HOME/Library/LaunchAgents/$label.plist"

launchctl bootout "gui/$UID" "$plist" 2>/dev/null || true
rm -f "$plist"

echo "Uninstalled $label"
