$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")
$versionLine = Select-String -Path "pubspec.yaml" -Pattern '^version:'
$version = (($versionLine.Line -split '\s+')[1] -split '\+')[0]

flutter pub get
if (Select-String -Path "pubspec.yaml" -Pattern '^\s*build_runner:' -Quiet) {
  dart run build_runner build --delete-conflicting-outputs
}
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --release
flutter build apk --release --split-per-abi

New-Item -ItemType Directory -Force -Path "dist" | Out-Null
Copy-Item "build/app/outputs/flutter-apk/app-release.apk" "dist/pasora-v$version.apk" -Force
Get-ChildItem "build/app/outputs/flutter-apk/app-*-release.apk" | ForEach-Object {
  if ($_.Name -match '^app-(.+)-release\.apk$') {
    Copy-Item $_.FullName "dist/pasora-v$version-$($Matches[1]).apk" -Force
  }
}
Write-Host "APK disponibles dans dist/"
