# Universal Image Copy

Universal Image Copy is now an app-only macOS menu bar utility that converts copied Google Slides visuals into real `image/png` clipboard data for native Mac apps.

The native-only version keeps the strongest path that works without a browser companion:

1. detect `Command-C` while Google Slides is frontmost in Chrome
2. wait for Slides to update the clipboard
3. parse clipboard HTML and recover a real image source
4. rewrite the macOS pasteboard with PNG data

If clipboard recovery fails, you can still run the manual fallback hotkey to capture a region and write it back as PNG.

## What Changed

This version removes the Chrome extension and localhost bridge completely.

That means the app no longer does:

- browser DOM reconstruction of selected Slides objects
- visible-tab capture and cropping
- bridge-based selection diagnostics

It does keep:

- automatic `Command-C` detection in Google Slides
- clipboard HTML source recovery
- PNG pasteboard writing
- manual region fallback

## Architecture

### Native app services

- `CopyCommandMonitor`: watches for global `Command-C` and requires Input Monitoring permission.
- `BrowserContextDetector`: checks the frontmost Chrome-family browser tab via AppleScript to confirm the user is on a Google Slides URL.
- `ClipboardHTMLExtractor`: parses `public.html` clipboard payloads and recovers image sources.
- `PasteboardWriter`: writes `public.png` and TIFF flavors back to the general pasteboard.
- `ManualRegionCapture`: last-resort interactive capture for manual runs.
- `GlobalHotKeyManager`: manual override hotkey for force-running the conversion flow.

### Automatic flow

1. User copies something in Google Slides with `Command-C`.
2. The app detects the copy command.
3. The app confirms the frontmost tab is a Google Slides presentation.
4. The app waits briefly for the clipboard to change.
5. The app tries clipboard HTML recovery.
6. On success, the clipboard becomes a real PNG for native Mac apps.

## Project Layout

- `Package.swift`: SwiftPM macOS app package.
- `Sources/UniversalImageCopy/AppModel.swift`: app orchestration and fallback flow.
- `Sources/UniversalImageCopy/CopyCommandMonitor.swift`: global copy-command detection.
- `Sources/UniversalImageCopy/BrowserContextDetector.swift`: frontmost Chrome tab detection.
- `Sources/UniversalImageCopy/ClipboardHTMLExtractor.swift`: HTML-to-image recovery.
- `Sources/UniversalImageCopy/ManualRegionCapture.swift`: manual fallback.
- `scripts/build_app.sh`: release bundling script that produces `build/UniversalImageCopy.app`.

## Build

```bash
cd /Users/shay/Documents/Codex/UniversalImageCopy
./scripts/build_app.sh
```

## Install And Run

### 1. Build and launch the app

```bash
open /Users/shay/Documents/Codex/UniversalImageCopy/build/UniversalImageCopy.app
```

### 2. Grant permissions

The app-only version may ask for:

- Input Monitoring: required to detect global `Command-C`
- Automation permission for Google Chrome: required to verify the active tab is Google Slides before auto-converting

### 3. Use it

- Open Google Slides in Chrome.
- Select a visual object.
- Press `Command-C`.
- Paste into Preview, Notes, Keynote, Mail, Slack, Figma, or another native app.

If automatic recovery misses, use:

- manual fallback hotkey: `Control + Option + Command + C`
- and use `Refresh Permissions` in the menu if macOS permission state changes

## Permissions

### macOS

- `NSInputMonitoringUsageDescription`: used to watch for `Command-C`.
- `NSAppleEventsUsageDescription`: used to ask Chrome for the active tab URL.
- Screen Recording may still be needed if you use the manual screenshot fallback.

### Browser support

The app-only auto-detection is Chrome-first. It currently checks frontmost tab context in:

- Google Chrome
- Google Chrome Canary
- Chromium
- Brave Browser
- Microsoft Edge

## Technical Limitations

- This version relies on clipboard HTML recovery. If Google Slides does not expose a recoverable image source in the clipboard, automatic conversion cannot synthesize one.
- Because the browser companion was removed, there is no DOM reconstruction or tab-capture fallback anymore.
- Automatic triggering requires Input Monitoring permission.
- Context detection uses browser AppleScript support, so macOS may prompt for Automation permission the first time the app checks Chrome.
- The manual fallback remains screenshot-based and is intentionally separate from the automatic flow.

## Prototype Status

This app-only prototype is working and verified locally:

- the Swift app builds
- the packaged `.app` builds
- automatic Google Slides copy detection is implemented
- clipboard HTML recovery still writes real PNG data when the source is recoverable

The tradeoff is simpler architecture in exchange for less coverage on the hardest Slides objects.
