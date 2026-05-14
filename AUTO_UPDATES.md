# Auto Updates

Codex Gauge uses Sparkle 2 for automatic updates.

## How It Works

- Sparkle is bundled inside `CodexGauge.app`.
- Users do not install Sparkle separately.
- The app checks this feed:

```text
https://github.com/jakobdsavage-afk/CodexGauge/releases/latest/download/appcast.xml
```

- The update archive is signed with Sparkle's EdDSA key.
- The app contains the matching public key in `SUPublicEDKey`.

## Secret Already Needed By CI

The `Sparkle Release` workflow needs this GitHub secret:

```text
SPARKLE_PRIVATE_KEY
```

This private key signs update archives and appcasts. Do not commit it.

## Making An Update

1. Commit and push your code.
2. Go to GitHub `Actions`.
3. Select `Sparkle Release`.
4. Click `Run workflow`.
5. Enter the next version, for example `v1.0.1`.

The workflow builds `CodexGauge.app`, signs the update archive with Sparkle, generates `appcast.xml`, and creates a GitHub Release containing both files.

Installed copies of Codex Gauge will check for updates automatically. Users can also choose `Check for Updates...` from the menu bar item.

## First Install

For you and your dad, the first install can still use the manual Gatekeeper bypass if the app is not Apple-notarized:

```sh
xattr -dr com.apple.quarantine /Applications/CodexGauge.app
open /Applications/CodexGauge.app
```

After that, Sparkle handles future updates from inside the app.
