# Codex Gauge

Codex Gauge is a tiny native macOS floating widget for watching Codex usage signals from local Codex data.

It is intentionally honest: when Codex has written a local rate-limit snapshot, the widget uses that. When no exact snapshot is available, it shows `Unknown` instead of inventing a percentage.

## What It Reads

The current provider is `CodexProvider`.

It scans:

- `~/.codex/sessions/**/*.jsonl`
- Codex `token_count` events written into those session files
- `~/.codex/logs_2.sqlite` websocket rate-limit events

When local telemetry contains Codex `rate_limits`, the provider maps:

- `rate_limits.primary.used_percent` to the widget's daily bucket
- `rate_limits.secondary.used_percent` to the widget's weekly bucket

The UI displays remaining percent, so it renders `100 - used_percent`.

If exact local snapshots are missing, Codex Gauge displays unknown values. The app does not fake usage values.

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

## Download The App From GitHub

GitHub Actions can build two kinds of app bundles.

For internal testing, use `Build App`:

1. Open the repository's `Actions` tab.
2. Choose `Build App`.
3. Click `Run workflow`.
4. Open the completed run.
5. Download the `CodexGauge-app` artifact.
6. Unzip it and open `CodexGauge.app`.

The artifact is ad-hoc signed, not notarized with an Apple Developer ID. macOS may require right-clicking the app and choosing `Open` the first time.

For public downloads, use the `Release` workflow instead. That workflow requires Apple Developer secrets, signs with Developer ID, notarizes with Apple, staples the ticket, and publishes a GitHub Release zip that normal users can open without the quarantine workaround. See `DISTRIBUTION.md`.

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

The probe prints whether it found real local Codex rate-limit telemetry or had to report usage as unavailable.

Full floating app behavior is best tested from Xcode because launch-at-login and accessory-app behavior are bundle-oriented macOS features. The included Xcode unit test target uses XCTest, which requires a full Xcode install rather than Command Line Tools only.
