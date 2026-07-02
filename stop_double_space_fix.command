#!/bin/zsh
cd "$(dirname "$0")" || exit 1

pid_file="$PWD/double_space_fix.pid"

if [[ ! -f "$pid_file" ]]; then
  echo "No pid file found; double_space_fix may not be running."
  exit 0
fi

pid="$(cat "$pid_file")"
if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
  kill "$pid"
  echo "Stopped double_space_fix with PID $pid"
else
  echo "PID $pid is not running."
fi

rm -f "$pid_file"
