# ChargeLimit

A native macOS Menu Bar application written in SwiftUI that allows you to effortlessly cap your MacBook's battery charging level (80%, 85%, 90%, 95%, 100%) to prolong battery health.

![ChargeLimit UI](https://github.com/user-attachments/assets/placeholder)

## Features

- **Battery Health Preservation**: Easily set a maximum charge limit to reduce battery wear.
- **Modern UI**: A sleek, window-style menu bar interface with hover effects and checkmarks.
- **Launch at Startup**: Option to automatically start the app when you log in.
- **Auto-Reset on Quit**: Automatically restores the charge limit to 100% when you quit the app to ensure your battery can be fully charged when needed.
- **Keyboard Shortcuts**: Quickly quit the app using `⌘Q`.

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

The app runs exclusively in your Menu Bar. Click on the battery icon with the bolt to see the control panel.

## Building from source

To rebuild the app from source, simply run the included build script:
```bash
chmod +x build.sh
./build.sh
```

## How it works

- The UI is built entirely using SwiftUI and `MenuBarExtra` with the `.window` style.
- When you select a charging level, the app executes `bclm write <value>` and `bclm persist` using `osascript`.
- Because modifying the SMC requires administrator privileges, macOS securely prompts you for your password or Touch ID.
- The app uses `ServiceManagement` (`SMAppService`) to handle "Launch at Startup" functionality.
- The `LSUIElement` key is set to `true` in `Info.plist` so the app runs cleanly without cluttering your Dock or App Switcher.
