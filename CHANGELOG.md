# Changelog

All notable changes to Pulse will be documented in this file.
Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) · adheres loosely to SemVer.

## [Unreleased]

## [1.0.0] — 2026-05-01

Initial public release.

### Features

- Native SwiftUI menu bar app with animated heartbeat status icon
- Window dashboard with live status hero, 5 stat tiles, network info card,
  latency chart, throughput chart, outage timeline
- Multi-host pinging (default `1.1.1.1` + `8.8.8.8`)
- Jitter, packet loss, min/max/mean per cycle
- Speed tests via macOS built-in `networkQuality` (download / upload / responsiveness)
- Outage logging with auto-traceroute capture at outage onset
- Captive-portal detection
- Public IP / local IP / gateway / interface display
- Battery-aware cadence backoff
- Local notifications: outage start, restored, latency-spike threshold
- Latency-spike threshold rule on chart
- Login at startup via `SMAppService.mainApp`
- Shortcuts integration: `Get Latest Ping`, `Check If Online`, `Run Speed Test`
- CSV export (pings, outages, speed tests) — proof for ISP
- 7-day rolling JSON history in `~/Library/Application Support/Pulse/`
- Procedurally generated app icon (separate `IconGen` SwiftPM target using SwiftUI `ImageRenderer`)
