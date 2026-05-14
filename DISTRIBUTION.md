# Public Distribution

The `Build App` workflow is useful for internal testing, but it creates an ad-hoc signed artifact. That is why macOS Gatekeeper can show "Apple could not verify..." dialogs.

For an app that works cleanly for everyone who downloads it, use the `Release` workflow. It builds, Developer ID signs, notarizes with Apple, staples the notarization ticket, and publishes a GitHub Release zip.

## Requirements

- Apple Developer Program membership.
- A `Developer ID Application` certificate exported as a `.p12`.
- An Apple app-specific password for notarization.

## GitHub Secrets

Add these repository secrets in GitHub:

- `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`
- `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_PASSWORD`
- `APPLE_DEVELOPER_ID_APPLICATION_IDENTITY`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

`APPLE_DEVELOPER_ID_APPLICATION_IDENTITY` should look like:

```text
Developer ID Application: Your Name or Company (TEAMID)
```

To create the base64 certificate secret:

```sh
base64 -i DeveloperIDApplication.p12 | pbcopy
```

Paste that value into `APPLE_DEVELOPER_ID_APPLICATION_CERTIFICATE_BASE64`.

## Release

1. Go to GitHub `Actions`.
2. Select `Release`.
3. Click `Run workflow`.
4. Enter a version like `v1.0.0`.
5. Wait for the workflow to finish.
6. Download the zip from the new GitHub Release.

That zip is the public-ready app. Users should be able to unzip and open it normally.

## Runtime Data

Codex Gauge reads data from the current macOS user's home directory:

- `~/.codex/sessions/**/*.jsonl`
- `~/.codex/logs_2.sqlite`

That means every downloader sees their own Codex usage, not the developer's. If a user has not installed or used Codex, the widget shows `Unknown`.
