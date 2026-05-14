# Codex Gauge Setup

## Requirements

- macOS 14 or newer
- Xcode for the full native app workflow
- Swift Command Line Tools are enough for `swift build` and the probe

## Open The App Project

```sh
open /Users/jake/Desktop/CodexGauge/CodexGauge.xcodeproj
```

Select the `CodexGauge` scheme, then build and run.

The app runs as a menu-bar accessory. Closing the floating widget hides it instead of quitting. Use the menu bar gauge icon to show it again, refresh manually, toggle always-on-top, or quit.

## Validate Without Launching The UI

```sh
cd /Users/jake/Desktop/CodexGauge
make validate
```

This validates the plist/project file, compiles the Swift package, and runs `CodexGaugeProbe` against local Codex session data.

## Usage Detection Notes

Codex Gauge looks for local Codex data under `~/.codex`.

Exact mode:

- Reads recent `~/.codex/sessions/**/*.jsonl` files.
- Looks for Codex `token_count` events containing `rate_limits`.
- Uses `primary.used_percent` and `secondary.used_percent`.
- Displays the inverse as remaining percent.

Estimated mode:

- Used when no exact local snapshot is found.
- Estimates pressure from real recent Codex session file activity.
- Labels the widget as `Estimated`.

The app never fabricates exact usage values.

## Launch At Login

The launch-at-login toggle uses `SMAppService.mainApp`, which is bundle-based. It should be tested from an app built and run through Xcode, not from the raw SwiftPM executable.
