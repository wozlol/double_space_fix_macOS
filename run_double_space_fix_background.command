#!/bin/zsh
cd "$(dirname "$0")" || exit 1

log_file="$PWD/double_space_fix.log"
pid_file="$PWD/double_space_fix.pid"

if [[ -f "$pid_file" ]]; then
  existing_pid="$(cat "$pid_file")"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "double_space_fix is already running with PID $existing_pid"
    exit 0
  fi
fi

nohup ./double_space_fix.swift --config "$PWD/double_space_fix_config.txt" > "$log_file" 2>&1 &
pid=$!
echo "$pid" > "$pid_file"
echo "double_space_fix started in the background with PID $pid"
echo "Log: $log_file"
