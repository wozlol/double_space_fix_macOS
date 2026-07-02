#!/bin/zsh
set -e

cd "$(dirname "$0")" || exit 1

label="com.woz.double-space-fix"
launch_agents="$HOME/Library/LaunchAgents"
plist="$launch_agents/$label.plist"
app_path="$PWD/Double Space Fix.app"
contents_path="$app_path/Contents"
macos_path="$contents_path/MacOS"
resources_path="$contents_path/Resources"
binary_path="$macos_path/double_space_fix"
config_path="$PWD/double_space_fix_config.txt"
log_path="$PWD/double_space_fix.log"
pid_file="$PWD/double_space_fix.pid"
module_cache="$PWD/.build/swift-module-cache"

mkdir -p "$launch_agents" "$macos_path" "$resources_path" "$module_cache"

if [[ -f "$pid_file" ]]; then
  existing_pid="$(cat "$pid_file")"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    kill "$existing_pid"
    echo "Stopped manual double_space_fix process with PID $existing_pid"
  fi
  rm -f "$pid_file"
fi

cat > "$contents_path/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>double_space_fix</string>
  <key>CFBundleIdentifier</key>
  <string>$label</string>
  <key>CFBundleName</key>
  <string>Double Space Fix</string>
  <key>CFBundleDisplayName</key>
  <string>Double Space Fix</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSBackgroundOnly</key>
  <true/>
</dict>
</plist>
PLIST

env CLANG_MODULE_CACHE_PATH="$module_cache" swiftc "$PWD/double_space_fix.swift" -o "$binary_path"
chmod +x "$binary_path"

codesign --force --deep --sign - "$app_path" >/dev/null 2>&1 || true

cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$label</string>
  <key>ProgramArguments</key>
  <array>
    <string>$binary_path</string>
    <string>--config</string>
    <string>$config_path</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$log_path</string>
  <key>StandardErrorPath</key>
  <string>$log_path</string>
  <key>WorkingDirectory</key>
  <string>$PWD</string>
</dict>
</plist>
PLIST

chmod 644 "$plist"

launchctl bootout "gui/$UID" "$plist" 2>/dev/null || true
: > "$log_path"
launchctl bootstrap "gui/$UID" "$plist"
launchctl kickstart -k "gui/$UID/$label"

sleep 1
service_status="$(launchctl print "gui/$UID/$label" 2>&1 || true)"
latest_log="$(tail -40 "$log_path" 2>/dev/null || true)"

echo "Installed and started $label"
echo "App: $app_path"
echo "LaunchAgent: $plist"
echo "Log: $log_path"
echo

if echo "$service_status" | grep -q "state = running"; then
  pid="$(echo "$service_status" | awk -F '= ' '/pid = / {print $2; exit}')"
  echo "Status: running${pid:+ with PID $pid}"
elif echo "$latest_log" | grep -q "Accessibility permission"; then
  echo "Status: Accessibility permission is still needed."
  echo "Open System Settings > Privacy & Security > Accessibility"
  echo "Then enable or add: Double Space Fix"
  echo "After granting permission, run ./install_startup.command again."
else
  echo "Status: not running yet."
  echo "Run this to inspect details:"
  echo "launchctl print \"gui/\$UID/$label\""
  echo "And check:"
  echo "$log_path"
fi
