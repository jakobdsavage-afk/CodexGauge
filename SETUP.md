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

## Test In GitHub Actions

You can test without running the app locally:

1. Push to `main`, or open GitHub Actions manually.
2. Go to `Actions` -> `CI`.
3. Click `Run workflow`.

The workflow runs on a hosted macOS machine and checks:

- plist and Xcode project parsing
- Swift Package build
- `CodexGaugeProbe`
- native Xcode app target build with code signing disabled

## Get A Downloadable App

Use the `Build App` GitHub Actions workflow:

1. Go to `Actions` -> `Build App`.
2. Click `Run workflow`.
3. Wait for the run to complete.
4. Download the `CodexGauge-app` artifact.
5. Unzip `CodexGauge.app.zip`.
6. Open `CodexGauge.app`.

This produces the real macOS app bundle. It is ad-hoc signed rather than Developer ID notarized, so Gatekeeper may ask you to right-click and choose `Open` on first launch.

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
