# Codex Gauge

Codex Gauge is a tiny native macOS floating widget for watching Codex usage signals from Codex account and local Codex data.

It is intentionally honest: when Codex account usage or local rate-limit snapshots are available, the widget uses them. When no exact snapshot is available, it shows `Unknown` instead of inventing a percentage.

## Download For Mac

[Download Codex Gauge](https://github.com/jakobdsavage-afk/CodexGauge/releases/latest/download/CodexGauge.zip)

After downloading:

1. Open `CodexGauge.zip`.
2. Drag `CodexGauge.app` into Applications.
3. Open `CodexGauge.app`.

If macOS says Apple cannot verify the app, right-click `CodexGauge.app`, choose `Open`, then click `Open` again.

Future updates install through the app automatically.

## Premium Widget Controls

Codex Gauge keeps its controls small so the widget still feels like a desktop instrument, not a settings panel.

- Themes: `Notebook Green`, `Amber Terminal`, `Blue Lab`, and `Red Alert`
- Widget sizes: `Tiny`, `Normal`, and `Expanded`
- Pin modes: `Floating`, `Desktop`, and `Menu Bar Only`
- Text modes: handwritten notebook text or a cleaner rounded system font
- First-run data source note explaining how real usage is detected

These settings are available from the widget controls and from the menu bar icon.

## V2 Experiment: Builder Board • This Week

The optional Builder Board is a local-only experiment for friendly weekly coding competition.

It compares:

- GitHub activity as output
- Codex weekly usage burned as fuel

The first version uses public GitHub activity only. The app loads shared builders from `leaderboard.json` in this repo, then merges in any local settings saved on the current Mac.

To add someone for everyone who downloads the app, edit `leaderboard.json` with:

- `displayName`
- `githubProfile`
- `codexUsageMode`
- `manualWeeklyCodexBurnedPercent`

People are added through the shared `leaderboard.json` file so everyone who downloads the app sees the same weekly board.

Scoring:

```text
Builder Score = GitHub weekly activity points / max(weekly Codex burned percent, 1) * 100
```

Activity points:

- Commit/push activity: 1 point
- Pull request opened: 3 points
- Issue closed: 2 points
- Active contribution day: 1 point

Scores are approximate and based on public GitHub activity. The feature does not require account creation, cloud sync, or multiplayer.

## What It Reads

The current provider is `CodexProvider`.

It reads:

- `~/.codex/auth.json` for the local Codex access token
- `https://chatgpt.com/backend-api/wham/usage` for the active account usage buckets
- `~/.codex/logs_2.sqlite` websocket rate-limit events
- `~/.codex/sessions/**/*.jsonl`
- Codex `token_count` events written into those session files

When the Codex account usage API is available, the provider maps:

- `rate_limit.primary_window.used_percent` to the widget's first displayed bucket, usually `5h`
- `rate_limit.secondary_window.used_percent` to the widget's second displayed bucket, usually `Weekly`

If the account API cannot be reached, local telemetry is used as a fallback:

- `rate_limits.primary.used_percent` maps to the widget's first displayed bucket
- `rate_limits.secondary.used_percent` maps to the widget's second displayed bucket

The UI displays remaining percent, so it renders `100 - used_percent`, and it uses Codex's reported `window_minutes` for row labels.

If exact account or local snapshots are missing, Codex Gauge displays unknown values. The app does not fake usage values.

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
- `CodexProvider` is the first concrete provider and owns Codex account and local usage detection.
- `GitHubProvider` reads public GitHub events for the optional leaderboard.
- `SharedLeaderboardProvider` downloads the shared leaderboard people from the repo's public `leaderboard.json`.
- `UsageRefreshService` refreshes usage every 10 seconds.
- `FloatingPanelController` owns the native always-visible panel, remembered position, opacity, and floating level.
- `LeaderboardWindowController` owns the optional V2 leaderboard window.
- `UpdaterService` owns Sparkle update checks.
- `UserPreferences` stores theme, size, pin mode, typography, opacity, launch-at-login, and first-run state.
- `LeaderboardStore` stores leaderboard people locally in `UserDefaults`.
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

For normal installs, use the direct download link at the top of this README. It always points to the newest release asset named `CodexGauge.zip`.

GitHub Actions can also build developer/test bundles.

For internal testing, use `Build App`:

1. Open the repository's `Actions` tab.
2. Choose `Build App`.
3. Click `Run workflow`.
4. Open the completed run.
5. Download the `CodexGauge-app` artifact.
6. Unzip it and open `CodexGauge.app`.

The artifact is ad-hoc signed, not notarized with an Apple Developer ID. macOS may require right-clicking the app and choosing `Open` the first time.

For public downloads without the macOS warning, use the `Release` workflow instead. That workflow requires Apple Developer secrets, signs with Developer ID, notarizes with Apple, staples the ticket, and publishes a GitHub Release zip that normal users can open without the quarantine workaround. See `DISTRIBUTION.md`.

## Automatic Updates

Codex Gauge bundles Sparkle 2. Your dad does not install Sparkle separately.

To publish an update, run the `Sparkle Release` workflow with a version like `v1.0.1`. The workflow builds the app, signs the update with Sparkle's private key, generates `appcast.xml`, and publishes both a versioned update zip and the human-friendly `CodexGauge.zip` download to GitHub Releases. Installed apps check that feed automatically and also expose `Check for Updates...` in the menu bar menu.

The update feed must be public. Private GitHub Releases return 404 to Sparkle.

See `AUTO_UPDATES.md`.

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
