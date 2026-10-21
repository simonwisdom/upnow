UpNow — macOS menu bar connectivity at a glance

UpNow is a tiny, privacy‑friendly macOS menu bar app that shows whether you’re online, offline, or need to sign in to a captive portal. It uses clear, color‑coded symbols and a compact history of recent checks so you can tell at a glance what’s happening.

Features
- Fast status: Online, Offline, Checking, or Wi-Fi login needed.
- Clear icon: Always‑visible color icon in the menu bar.
- History: How long you have been online, then each drop and how long it lasted.
- Manual refresh: “Check Now” from the menu.
- Launch at Login: Optional background helper.
- Privacy‑friendly: No analytics. Checks fetch Apple's and Google's standard captive-portal pages.

How it works
- Network.framework: Listens for reachability changes with `NWPathMonitor`.
- Probe: Verifies internet access by fetching the captive-portal endpoints `captive.apple.com/hotspot-detect.html` and `www.gstatic.com/generate_204`.
- Updates: Publishes changes on the main thread; the menu and icon update immediately.

Screenshots
![UpNow menu](../docs/menu.png)

Get started
1) Open `UpNow.xcodeproj` in Xcode.
2) Select the `UpNow` scheme.
3) Run. The UpNow icon appears in the menu bar; click it to open the menu.

Accessibility
- Color + shape: Status uses both color and distinct shapes/symbols.
- Labels: Menu items include clear text labels (e.g., Online, Offline).
- Keyboard: Standard menu navigation works; no custom hotkeys required.

Notes
- App name: User‑visible name is “UpNow”.
- Bundle IDs: `com.simonwisdom.upnow` and `com.simonwisdom.upnow.LoginItem`.
- macOS: Targets macOS 13+ (Ventura or later).

License
MIT — see `../LICENSE`.
