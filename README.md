# Liquid Browser (iOS)

Custom iOS browser based on `WKWebView` with a Safari-like bottom address bar and a floating bubble menu for advanced controls.

## Features

- Safari-like browsing with a liquid glass bottom address bar
- Floating bubble menu with quick toggles:
  - Block ads
  - Block popups
  - Block redirects
  - Use proxy
  - Rotate proxy automatically on failure
- Proxy list management (save multiple proxies, switch active proxy, rotate)
- Developer tools panel:
  - Network monitor (`fetch` and XHR + navigation events)
  - Console log capture
  - Link extractor
  - HTML viewer
- Device emulation presets in settings:
  - iPhone
  - macOS Safari
  - Android Chrome
  - iPad Safari
- Tab behavior settings:
  - Keep tabs after restart
  - Close all tabs and start fresh
  - Configure start page for new tabs

## Important iOS notes

- Full desktop-class DevTools parity is not possible in pure iOS `WKWebView`. This app captures the most useful monitoring data available from public APIs.
- Proxy support uses iOS 17+ `WKWebsiteDataStore.proxyConfigurations`.
- `ProxyConfiguration` currently relies on an HTTP CONNECT endpoint for WebKit traffic.

## Build in Xcode

1. Open `LiquidBrowser.xcodeproj` in Xcode 16+.
2. Set your Team in Signing & Capabilities.
3. Change bundle id if needed (`com.amoo.liquidbrowser`).
4. Build and run on iPhone.

## Create IPA (for sideload / LiveContainer workflow)

Archive:

```bash
xcodebuild -project LiquidBrowser.xcodeproj -scheme LiquidBrowser -configuration Release -archivePath build/LiquidBrowser.xcarchive archive
```

Export:

```bash
xcodebuild -exportArchive -archivePath build/LiquidBrowser.xcarchive -exportOptionsPlist ExportOptions.plist -exportPath build
```

Then use the exported `.ipa` from `build/`.

## Suggested ExportOptions.plist example

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>development</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>stripSwiftSymbols</key>
  <true/>
  <key>compileBitcode</key>
  <false/>
</dict>
</plist>
```
