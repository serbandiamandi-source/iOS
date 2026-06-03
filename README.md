# Barometer Pressure SwiftUI Sources

This repository now contains only the Swift source files needed for a minimal native iOS SwiftUI app that displays live barometric pressure from an iPhone's internal barometer in millimeters of mercury (mmHg).

## Files

- `BarometerPressureApp/BarometerPressureApp.swift` — SwiftUI app entry point.
- `BarometerPressureApp/ContentView.swift` — Centered pressure UI and `CMAltimeter` view model.

## Use in Xcode

1. Create a new **iOS App** project in Xcode using SwiftUI.
2. Copy the two Swift files from `BarometerPressureApp/` into the app target, replacing Xcode's generated app and content view files if desired.
3. In the target's Info settings, add a Privacy - Motion Usage Description (`NSMotionUsageDescription`) value such as:
   `This personal app reads the iPhone barometer through CoreMotion to show current pressure.`
4. Select your personal development team in **Signing & Capabilities** if needed.
5. Run on an iPhone with a barometer.

The app uses `CMAltimeter` from CoreMotion. CoreMotion reports pressure in kilopascals, and `ContentView.swift` converts it to mmHg using `1 kPa = 7.50061683 mmHg`.
