<p align="center">
  <img src="docs/icon.png" width="96" alt="UpNow icon">
</p>

<h1 align="center">UpNow</h1>

<p align="center">Know at a glance whether you're online, offline, or stuck behind a Wi-Fi login page.</p>

<p align="center"><a href="https://github.com/simonwisdom/upnow/releases/latest/download/UpNow.zip"><b>Download for macOS</b></a> · macOS 13 or later</p>

<p align="center">
  <img src="docs/menubar.gif" width="160" alt="The menu bar icon turns red with an Offline label, then a periscope pops up with Back online">
</p>

<p align="center">
  <img src="docs/menu.png" width="530" alt="The UpNow menu with History open, listing recent drops">
</p>

- Clear icon in the menu bar (color + shape)
- Status, latency and when it last checked, in one line
- History: how long you have been online, then each drop and how long it lasted
- A heads-up when you're on a hotspot or a weak power source
- Colorblind-friendly colors and Launch at Login, under Settings

## Install
1. Download `UpNow.zip` from the [latest release](https://github.com/simonwisdom/upnow/releases/latest).
2. Unzip it and drag `UpNow.app` into Applications.
3. Open it. The first time, macOS says it can't verify the app: open System Settings → Privacy & Security, scroll down and click **Open Anyway**.

Requires macOS 13 (Ventura) or later.

## Privacy
- No analytics or telemetry.
- Connectivity checks fetch the standard captive-portal endpoints `captive.apple.com/hotspot-detect.html` and `www.gstatic.com/generate_204`.

## Build from source
Open `UpNow.xcodeproj` in Xcode 15+, select the `UpNow` scheme and Run. App source lives in `swiftui-app/`; see `swiftui-app/README.md` for implementation notes.

## License
MIT — see `LICENSE`.
