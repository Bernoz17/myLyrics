# Run this from the root of the Flutter project on Windows.
flutter create --platforms=ios .
flutter pub get
Write-Host ""
Write-Host "Clean iOS scaffolding regenerated."
Write-Host "Do NOT run an iOS build on Windows; Codemagic will build it on macOS."
