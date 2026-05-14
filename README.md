# Codex Gauge

Codex Gauge is a tiny native macOS floating widget for watching Codex usage signals from local Codex data.

It is intentionally honest: when Codex has written a local rate-limit snapshot, the widget uses that. When no exact snapshot is available, it estimates from recent local session activity and marks the values as `Estimated`.

## What It Reads

The current provider is `CodexProvider`.

It scans:

- `~/.codex/sessions/**/*.jsonl`
- Codex `token_count` events written into those session files
- Local session file activity as a fallback estimate

When a session line contains Codex `rate_limits`, the provider maps:

- `rate_limits.primary.used_percent` to the widget's daily bucket
- `rate_limits.secondary.used_percent` to the widget's weekly bucket

The UI displays remaining percent, so it renders `100 - used_percent`.

If those exact local snapshots are missing, Codex Gauge estimates from real session file sizes modified today and during the past seven days. The app does not fake exact usage values.

## Project Structure

```text
CodexGauge/
  CodexGauge.xcodeproj/
  CodexGauge/
    CodexGaugeApp.swift
    AppDelegate.swift
    Models/
    Providers/
    Services/
    Views/
    Resources/Info.plist
  Tests/
  Package.swift
```

## Architecture

- `UsageProvider` is the provider protocol.
- `CodexProvider` is the first concrete provider and owns local Codex detection.
- `UsageRefreshService` refreshes usage every 15 seconds.
- `FloatingPanelController` owns the native always-visible panel, remembered position, opacity, and floating level.
- SwiftUI views draw the hand-sketched notebook interface.

Future providers can be added by implementing `UsageProvider` and swapping the provider passed into `UsageRefreshService`.

## Run In Xcode

1. Open `CodexGauge/CodexGauge.xcodeproj`.
2. Select the `CodexGauge` scheme.
3. Build and run.

The app runs as a menu-bar/accessory utility. Closing the widget hides it to the menu bar.

## Test Without Running Locally

GitHub Actions is configured in `.github/workflows/ci.yml`.

From GitHub:

1. Open the repository's `Actions` tab.
2. Choose `CI`.
3. Click `Run workflow`.

The macOS runner validates the project files, builds the Swift package, runs `CodexGaugeProbe`, and builds the native Xcode target with code signing disabled.

## Run From Swift Package

The project also includes a Swift Package manifest for lightweight local builds:

```sh
cd CodexGauge
swift build
```

You can also run the local data probe without launching the floating UI:

```sh
swift run CodexGaugeProbe
```

The probe prints whether it found an exact local Codex rate-limit snapshot or had to estimate from session files.

Full floating app behavior is best tested from Xcode because launch-at-login and accessory-app behavior are bundle-oriented macOS features. The included Xcode unit test target uses XCTest, which requires a full Xcode install rather than Command Line Tools only.
