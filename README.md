## UpNow

UpNow is a tiny, privacy‑friendly macOS menu bar app that shows whether you’re online, offline, or need to sign in to a captive portal — at a glance.

- Clear icon in the menu bar (color + shape)
- Compact history row of recent checks (oldest → now)
- Manual refresh, quick access to Network settings
- Optional Launch at Login helper

## Screenshot
![UpNow menu](docs/screenshot.svg)

## Requirements
- macOS 13+ (Ventura or later)
- Xcode 15+
- Swift 5.9+

## Install
- Build from source: Open `UpNow.xcodeproj` in Xcode, select the `UpNow` scheme, Run.
- Run outside Xcode: Product → Show Build Folder in Finder → move `UpNow.app` from Build/Products/(Debug|Release) to `/Applications` and launch.

## Launch at Login
- Enable the “Launch at Login” toggle in the app menu. Approve in System Settings if prompted.

## Signing & IDs
- Default bundle IDs: `com.example.UpNow` and `com.example.UpNow.LoginItem`.
- Change both to your domain and set a Signing Team before distributing.

## Privacy
- No analytics or telemetry.
- Connectivity checks use short HEAD requests to `apple.com` and `cloudflare.com`.

## Details
- App source lives in `swiftui-app/`. See `swiftui-app/README.md` for implementation notes.

## License
MIT — see `LICENSE`.
