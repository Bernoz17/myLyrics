# FrasiWidget reintegration

The original FrasiWidget source has been preserved under `widget_source_backup/`.
The old Xcode project was intentionally removed because its PBXFileReference/sourceTree
entries caused modern xcodebuild to assert.

The clean iOS project should first be generated with:
    flutter create --platforms=ios .

Then the widget target should be recreated in a modern Xcode environment, using the
preserved source files. Do not copy the old `.xcodeproj`/`.pbxproj` back into the project.

The Codemagic workflow currently validates the clean iOS build. Code signing and the
AltServer IPA step are separate.
