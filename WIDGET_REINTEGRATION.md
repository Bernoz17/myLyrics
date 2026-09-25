# appFrasi — modern iOS project with FrasiWidget

This copy restores the original WidgetKit extension in the Flutter iOS project.

## What was changed
- Kept the original Flutter app code and assets.
- Restored `FrasiWidget.swift`, its assets and `Info.plist`.
- Restored the shared App Group `group.it.bernoz.myLyrics` for Runner and widget entitlements.
- Restored the app and widget bundle identifiers:
  - `it.bernoz.mylyrics`
  - `it.bernoz.mylyrics.FrasiWidget`
- Kept the widget embedded in the Runner target.
- Fixed the legacy empty Xcode `sourceTree` values to the modern `<group>` form that the clean Flutter-generated project uses.
- Codemagic workflow no longer assumes a CocoaPods `Podfile`.

## Important
The build uses `--no-codesign`, so it validates compilation of the app + extension. Signing an IPA for a physical iPhone remains a separate step.
