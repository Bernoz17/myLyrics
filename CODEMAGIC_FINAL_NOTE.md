# Important

This final Codemagic configuration intentionally does NOT run `flutter create --platforms=ios .`.
That command would overwrite the existing Xcode project and remove the FrasiWidget target and
the custom bundle identifiers.

The workflow:
1. uses the existing modern iOS project;
2. verifies both bundle IDs and the widget target;
3. builds the app without Apple code signing;
4. packages the resulting Runner.app into an unsigned .ipa.

The resulting IPA is intended to be re-signed/installed by AltServer on the physical iPhone.
