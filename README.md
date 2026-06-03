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

For CI, build the shared scheme with a command like:

```sh
xcodebuild \
  -project BarometerPressureApp.xcodeproj \
  -scheme BarometerPressureApp \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The app uses `CMAltimeter` from CoreMotion. CoreMotion reports pressure in kilopascals, and `ContentView.swift` converts it to mmHg using `1 kPa = 7.50061683 mmHg`.
