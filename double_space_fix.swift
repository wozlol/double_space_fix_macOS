#!/usr/bin/env swift

import ApplicationServices
import Foundation

struct Config {
    var enabled = true
    var maxSpaceIntervalMs = 90.0
    var minSpaceIntervalMs = 0.0
    var onlyWithoutCommandControlOption = true
    var ignoreAutoRepeat = true
    var correctionMode = "suppress"
    var backspaceDelayMs = 8.0
    var logSuppressed = false
}

final class SpaceFilter {
    let config: Config
    var eventTap: CFMachPort?
    private var lastAcceptedSpaceNs: UInt64?
    private var lastKeyWasAcceptedSpace = false

    init(config: Config) {
        self.config = config
    }

    func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard config.enabled, type == .keyDown else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let isSpace = keyCode == 49

        if config.ignoreAutoRepeat,
           event.getIntegerValueField(.keyboardEventAutorepeat) != 0 {
            return Unmanaged.passUnretained(event)
        }

        if config.onlyWithoutCommandControlOption && hasCommandControlOrOption(event.flags) {
            lastKeyWasAcceptedSpace = false
            return Unmanaged.passUnretained(event)
        }

        guard isSpace else {
            lastKeyWasAcceptedSpace = false
            return Unmanaged.passUnretained(event)
        }

        let now = DispatchTime.now().uptimeNanoseconds
        let shouldCorrect: Bool
        if let lastAcceptedSpaceNs, lastKeyWasAcceptedSpace {
            let deltaMs = Double(now - lastAcceptedSpaceNs) / 1_000_000.0
            shouldCorrect = deltaMs >= config.minSpaceIntervalMs && deltaMs <= config.maxSpaceIntervalMs
        } else {
            shouldCorrect = false
        }

        if shouldCorrect {
            if config.logSuppressed {
                let stamp = ISO8601DateFormatter().string(from: Date())
                fputs("[\(stamp)] corrected duplicate space\n", stderr)
            }

            if config.correctionMode == "backspace" {
                sendBackspace(afterMs: config.backspaceDelayMs)
                return Unmanaged.passUnretained(event)
            }

            return nil
        }

        lastAcceptedSpaceNs = now
        lastKeyWasAcceptedSpace = true
        return Unmanaged.passUnretained(event)
    }
}

func hasCommandControlOrOption(_ flags: CGEventFlags) -> Bool {
    flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate)
}

func sendBackspace(afterMs delayMs: Double) {
    let delay = DispatchTime.now() + .milliseconds(max(0, Int(delayMs)))
    DispatchQueue.main.asyncAfter(deadline: delay) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

func loadConfig(at path: String) -> Config {
    var config = Config()

    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        return config
    }

    for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
        let withoutComment = rawLine.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first ?? ""
        let line = withoutComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else {
            continue
        }

        let parts = line.split(separator: "=", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard parts.count == 2 else {
            continue
        }

        let key = parts[0].lowercased()
        let value = parts[1]
        switch key {
        case "enabled":
            config.enabled = parseBool(value, default: config.enabled)
        case "max_space_interval_ms":
            config.maxSpaceIntervalMs = parseDouble(value, default: config.maxSpaceIntervalMs)
        case "min_space_interval_ms":
            config.minSpaceIntervalMs = parseDouble(value, default: config.minSpaceIntervalMs)
        case "only_without_command_control_option":
            config.onlyWithoutCommandControlOption = parseBool(value, default: config.onlyWithoutCommandControlOption)
        case "ignore_auto_repeat":
            config.ignoreAutoRepeat = parseBool(value, default: config.ignoreAutoRepeat)
        case "correction_mode":
            config.correctionMode = value.lowercased()
        case "backspace_delay_ms":
            config.backspaceDelayMs = parseDouble(value, default: config.backspaceDelayMs)
        case "log_suppressed":
            config.logSuppressed = parseBool(value, default: config.logSuppressed)
        default:
            continue
        }
    }

    if config.minSpaceIntervalMs < 0 {
        config.minSpaceIntervalMs = 0
    }
    if config.maxSpaceIntervalMs < config.minSpaceIntervalMs {
        config.maxSpaceIntervalMs = config.minSpaceIntervalMs
    }
    if config.correctionMode != "suppress" && config.correctionMode != "backspace" {
        config.correctionMode = "suppress"
    }

    return config
}

func parseBool(_ value: String, default defaultValue: Bool) -> Bool {
    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "1", "true", "yes", "y", "on":
        return true
    case "0", "false", "no", "n", "off":
        return false
    default:
        return defaultValue
    }
}

func parseDouble(_ value: String, default defaultValue: Double) -> Double {
    Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) ?? defaultValue
}

func scriptDirectory() -> String {
    let arg0 = CommandLine.arguments[0]
    let path: String
    if arg0.hasPrefix("/") {
        path = arg0
    } else {
        path = FileManager.default.currentDirectoryPath + "/" + arg0
    }
    return URL(fileURLWithPath: path).deletingLastPathComponent().path
}

func configPath() -> String {
    if let index = CommandLine.arguments.firstIndex(of: "--config"),
       CommandLine.arguments.indices.contains(index + 1) {
        return CommandLine.arguments[index + 1]
    }
    return scriptDirectory() + "/double_space_fix_config.txt"
}

let configFile = configPath()
let config = loadConfig(at: configFile)

if CommandLine.arguments.contains("--check") {
    print("""
    double_space_fix check OK
    config_file = \(configFile)
    enabled = \(config.enabled)
    max_space_interval_ms = \(config.maxSpaceIntervalMs)
    min_space_interval_ms = \(config.minSpaceIntervalMs)
    correction_mode = \(config.correctionMode)
    """)
    exit(0)
}

guard AXIsProcessTrusted() else {
    fputs("""
    double_space_fix needs Accessibility permission before it can filter keyboard events.

    Open System Settings > Privacy & Security > Accessibility, then allow the terminal app you use to run this script.
    If you run it from Terminal, allow Terminal. If you run it from iTerm, allow iTerm.

    After granting permission, quit and run this script again.

    """, stderr)
    exit(2)
}

let filter = SpaceFilter(config: config)
let mask = (1 << CGEventType.keyDown.rawValue)
    | (1 << CGEventType.tapDisabledByTimeout.rawValue)
    | (1 << CGEventType.tapDisabledByUserInput.rawValue)

let callback: CGEventTapCallBack = { proxy, type, event, refcon in
    guard let refcon else {
        return Unmanaged.passUnretained(event)
    }
    let filter = Unmanaged<SpaceFilter>.fromOpaque(refcon).takeUnretainedValue()
    return filter.handle(proxy: proxy, type: type, event: event)
}

guard let tap = CGEvent.tapCreate(
    tap: .cghidEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(mask),
    callback: callback,
    userInfo: Unmanaged.passUnretained(filter).toOpaque()
) else {
    fputs("""
    Could not create keyboard event tap.

    Check System Settings > Privacy & Security > Input Monitoring and Accessibility for the terminal app running this script.

    """, stderr)
    exit(3)
}

filter.eventTap = tap
let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("double_space_fix is running. Config: \(configFile)")
CFRunLoopRun()
