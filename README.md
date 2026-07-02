# double_space_fix for macOS

This runs a small macOS keyboard event tap that suppresses a second plain space
when it arrives immediately after the previous accepted space.

## Run

```sh
chmod +x double_space_fix.swift run_double_space_fix_background.command stop_double_space_fix.command
./double_space_fix.swift --check
./run_double_space_fix_background.command
```

The first run may ask for macOS permissions. If it does not work, open:

```text
System Settings > Privacy & Security > Accessibility
System Settings > Privacy & Security > Input Monitoring
```

Allow the terminal app you used to start the script, then run it again.

## Tune

Edit `double_space_fix_config.txt`, then stop and start the background process:

```sh
./stop_double_space_fix.command
./run_double_space_fix_background.command
```

Start with `max_space_interval_ms = 90`. Lower it if intentional fast
double-spaces are blocked. Raise it if unwanted duplicate spaces still appear.

## Stop

```sh
./stop_double_space_fix.command
```

## Run At Login

Install and start the per-user LaunchAgent:

```sh
./install_startup.command
```

Remove it from login startup:

```sh
./uninstall_startup.command
```

Restart it after editing config:

```sh
launchctl kickstart -k "gui/$UID/com.woz.double-space-fix"
```

## Check Status

```sh
ps -p "$(cat double_space_fix.pid)"
```

If installed through LaunchAgent, check it with:

```sh
launchctl print "gui/$UID/com.woz.double-space-fix"
```

The log is historical. It records timestamped starts, stops, errors, and only
logs individual corrections if `log_suppressed = true`.
