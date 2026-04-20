# ChargeLimit

A native macOS Menu Bar application written in SwiftUI that allows you to effortlessly cap your MacBook's battery charging level (80%, 85%, 90%, 95%, 100%) to prolong battery health.

## Prerequisites

This app depends on the `bclm` command-line utility to communicate with the macOS System Management Controller (SMC).

You can install `bclm` via Homebrew:
```bash
brew tap zackelia/formulae
brew install bclm
```

## Running the App

You can just open the built `ChargeLimit.app` bundle:
```bash
open ChargeLimit.app
```

The app runs exclusively in your Menu Bar (it has no dock icon). Click on the battery icon with the bolt to see the dropdown menu.

## Building from source

To rebuild the app from source, simply run the included build script:
```bash
chmod +x build.sh
./build.sh
```

## How it works

- The UI is built entirely using SwiftUI and `MenuBarExtra`.
- When you select a charging level, the app executes `bclm write <value>` and `bclm persist` using `osascript`.
- Because modifying the SMC requires administrator privileges, macOS securely prompts you for your password or Touch ID.
- The `LSUIElement` key is set to `true` in `Info.plist` so the app runs cleanly without cluttering your Dock or App Switcher.
