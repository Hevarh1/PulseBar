<p align="center">
  <img src="docs/icon.png" alt="PulseBar" width="128" height="128">
</p>

# PulseBar

**Local-only** macOS menu-bar system monitor.  
Live CPU · Memory · Temperature · Network · utilities — with **zero telemetry**.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## Features

- **Menu bar** — TEM / MEM / CPU (and optional network, battery, uptime) with a brand gauge icon
- **Dashboard popover** — live graphs, sensors, and a full utility grid (no scrolling required)
- **Honest sensors** — Activity Monitor–style memory; AppleSMC temperature (not fake thermal enums)
- **Utilities** — Clean Keyboard / Screen, Dark Mode, Empty Trash, Lock, Hide Dock/Desktop, Keep Awake, Meeting Mode, and more
- **Private by design** — no accounts, no analytics, no network for metrics

## Requirements

- macOS **14** (Sonoma) or later
- [Xcode](https://developer.apple.com/xcode/) or Command Line Tools (`xcode-select --install`)
- Apple Silicon or Intel Mac

## Install

### Option A — Build a `.app` (recommended)

```bash
git clone <this-repo-url>
cd PulseBar
chmod +x scripts/package-app.sh
./scripts/package-app.sh
open dist/PulseBar.app
```

Then optionally drag `dist/PulseBar.app` into **Applications**.

### Option B — Run from source

```bash
git clone <this-repo-url>
cd PulseBar
swift run PulseBar
```

> When you use `swift run`, macOS may attribute **Accessibility** to **Terminal** (not PulseBar). Prefer Option A for Clean Keyboard and Launch at Login.

### Option C — Release download

If a GitHub Release is published, download `PulseBar.app.zip`, unzip, move to Applications, and open once (right-click → Open if Gatekeeper warns).

## First launch permissions

| Feature | Permission |
|---------|------------|
| Clean Keyboard (block keys) | **Privacy & Security → Accessibility** — enable PulseBar (or Terminal if using `swift run`) |
| Dark Mode / Empty Trash / Lock fallback | **Automation** (prompted on first use) |

PulseBar never phones home. Permissions are only for local system controls you trigger.

## Usage

1. Look for the **gauge icon** plus TEM / MEM / CPU in the menu bar.
2. Click any of them to open the dashboard.
3. Use **Preferences** (gear) for sampling interval, units, and which metrics appear in the menu bar.
4. Quit from the dashboard footer or Force Quit if needed.

## Development

```bash
swift build          # debug build
swift run PulseBar   # run
swift test           # unit tests
./scripts/package-app.sh   # release .app in dist/
```

Project layout:

```
PulseBar/
  App/           # NSApplication, menu bar
  Monitoring/    # CPU, memory, thermal, disk, network, GPU, battery
  Views/         # SwiftUI dashboard
  Controls/      # Dock, desktop, clean modes, utilities
  Resources/     # AppIcon.png
```

## Privacy

- Metrics and preferences stay on your Mac.
- No crash reporters, no update pings, no accounts.
- Optional Automation / Accessibility only when you use those utilities.

## License

[MIT](LICENSE) — free to use, modify, and redistribute.
