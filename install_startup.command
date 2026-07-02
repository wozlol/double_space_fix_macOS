#!/bin/zsh
set -e

cd "$(dirname "$0")" || exit 1

label="com.woz.double-space-fix"
launch_agents="$HOME/Library/LaunchAgents"
plist="$launch_agents/$label.plist"
script_path="$PWD/double_space_fix.swift"
config_path="$PWD/double_space_fix_config.txt"
log_path="$PWD/double_space_fix.log"
pid_file="$PWD/double_space_fix.pid"

mkdir -p "$launch_agents"

if [[ -f "$pid_file" ]]; then
  existing_pid="$(cat "$pid_file")"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    kill "$existing_pid"
    echo "Stopped manual double_space_fix process with PID $existing_pid"
  fi
  rm -f "$pid_file"
fi

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
    <string>$script_path</string>
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
launchctl bootstrap "gui/$UID" "$plist"
launchctl kickstart -k "gui/$UID/$label"

echo "Installed and started $label"
echo "LaunchAgent: $plist"
echo "Log: $log_path"
