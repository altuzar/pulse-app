# Contributing to Pulse

Thank you for considering contributing! Pulse is small, opinionated, and built to stay that way.

## Quick start

1. Fork & clone
2. `./build.sh` — builds the app and the icon target
3. `open Pulse.app`
4. Make your change, rebuild, verify visually
5. Open a PR with a screenshot if it touches the UI

## Code style

- SwiftUI-first; AppKit only when there's no SwiftUI equivalent
- No third-party dependencies. Don't add a new Swift package without discussing it in an issue first
- Default to writing no comments. Only document the *why*, not the *what*
- Tabular numbers (`.monospacedDigit()`) for any UI metric

## What to work on

- The [`good first issue`](https://github.com/<user>/pulse/labels/good%20first%20issue) label
- Items in the README **Roadmap** section
- Bug reports labeled `confirmed`

If you want to work on something bigger, open an issue first so we can align on scope.

## What's out of scope

- Per-app bandwidth attribution (would require a NetworkExtension entitlement & paid Apple Developer account)
- Anything that adds telemetry, analytics, or phones home
- Cross-platform support (Pulse is intentionally Mac-only)

## PR checklist

- [ ] `./build.sh` succeeds with no warnings
- [ ] Screenshot attached for any UI change
- [ ] No new dependencies added (or clear rationale + issue thread)
- [ ] CHANGELOG entry under "Unreleased"
- [ ] One commit per logical change; squash on merge

## Releasing (maintainer only)

1. Bump `CFBundleShortVersionString` in `build.sh`
2. Move "Unreleased" CHANGELOG entries under a new dated heading
3. `git tag v1.x.0 && git push --tags`
4. GitHub Releases — attach the built `Pulse.app.zip`
