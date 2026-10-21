<p align="center">
  <img src="docs/banner.png" alt="UpNow: online, offline, or stuck behind a Wi-Fi login? Know at a glance.">
</p>

<p align="center"><a href="https://github.com/simonwisdom/upnow/releases/latest/download/UpNow.zip"><b>Download for macOS</b></a> · Free · macOS 13 or later</p>

<p align="center">
  <img src="docs/menubar-card.gif" width="300" alt="The menu bar turns red with Offline, then a periscope pops up with Back online"><br>
  <sub><b>Drops, at a glance.</b> The dot turns red, and a periscope pops up when you're back.</sub>
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
