# Paperwalls

Native macOS app for browsing and setting wallpapers from the Paper collection at `https://burkeholland.github.io/paper/api.json`.

## What works

- SwiftUI macOS app with a menu bar quick switcher and full gallery window
- Theme-organized gallery using the Paper API
- Search by wallpaper name, theme, or tag
- Favorites
- One-click wallpaper setting across all displays
- Full-resolution wallpaper download cache with cache clearing
- Global and theme-based rotation with presets and custom intervals
- Subtle "New" tracking for wallpapers added after first launch
- Offline fallback to the last cached catalog

## Build

```bash
swift build --product Paperwalls
```

## Run behavior checks

This environment does not provide XCTest or Swift Testing, so non-UI checks live in a small executable target:

```bash
swift run PaperwallsChecks
```

## Run the app from source

```bash
swift run Paperwalls
```

For App Store distribution, open the Swift package in Xcode, configure signing, app sandbox/network entitlements, icons, bundle metadata, and archive through Xcode.
