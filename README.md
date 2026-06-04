# Barometer Pressure

A minimal native SwiftUI iOS app that displays live barometric pressure from an iPhone's internal barometer in millimeters of mercury (mmHg).

## Requirements

- Xcode 15 or newer
- iOS 17 or newer
- An iPhone model with a barometer

## Project

- `BarometerPressureApp.xcodeproj` contains the iOS app target.
- The shared scheme is `BarometerPressureApp` for local Xcode use and GitHub Actions `xcodebuild` commands.
- Bundle identifier: `com.serban.barometer`.
- `BarometerPressureApp/BarometerPressureApp.swift` is the SwiftUI app entry point.
- `BarometerPressureApp/ContentView.swift` contains the centered UI and `CMAltimeter` view model.

The project generates its app Info.plist at build time and includes the required `NSMotionUsageDescription` value for CoreMotion access.

## Build

Open `BarometerPressureApp.xcodeproj` in Xcode, select the `BarometerPressureApp` scheme, choose a signing team if Xcode asks for one, then run on your iPhone.

For CI, the project disables code signing by default so GitHub Actions can build or archive without a provisioning profile. Build the shared scheme with a command like:

```sh
xcodebuild \
  -project BarometerPressureApp.xcodeproj \
  -scheme BarometerPressureApp \
  -destination 'generic/platform=iOS Simulator' \
  build
```

To create an unsigned CI archive, use:

```sh
xcodebuild \
  -project BarometerPressureApp.xcodeproj \
  -scheme BarometerPressureApp \
  -destination 'generic/platform=iOS' \
  -archivePath build/BarometerPressureApp.xcarchive \
  archive
```

For a local install on your iPhone, open the target in Xcode and enable automatic signing with your personal development team. Exporting an installable IPA also requires a valid signing identity and provisioning profile; unsigned CI archives are useful for compile/archive validation only.

The app uses `CMAltimeter` from CoreMotion. CoreMotion reports pressure in kilopascals, and `ContentView.swift` converts it to mmHg using `1 kPa = 7.50061683 mmHg`.
