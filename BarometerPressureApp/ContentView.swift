import CoreMotion
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var viewModel = BarometricPressureViewModel()

    var body: some View {
        VStack(spacing: 16) {
            Text("Presiune atmosferica")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text(viewModel.pressureText)
                .font(.system(size: 52, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(viewModel.rainChanceText)
                .font(.title3.weight(.medium))
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Text(viewModel.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .background(viewModel.backgroundColor.gradient)
        .animation(.easeInOut(duration: 0.6), value: viewModel.rainChance)
        .task {
            viewModel.startUpdates()
        }
        .onDisappear {
            viewModel.stopUpdates()
        }
    }
}

final class BarometricPressureViewModel: ObservableObject {
    @Published private(set) var pressureText = "--.- mmHg"
    @Published private(set) var rainChanceText = "Șanse de ploaie: --%"
    @Published private(set) var rainChance = 0.5
    @Published private(set) var statusText = "© SerbanD"

    var backgroundColor: Color {
        Color.interpolate(
            from: .lightRainYellow,
            to: .heavyRainBlue,
            amount: rainChance
        )
    }

    private let altimeter = CMAltimeter()
    private let kilopascalsToMillimetersOfMercury = 7.50061683
    private var isUpdating = false

    func startUpdates() {
        guard !isUpdating else { return }

        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            pressureText = "--.- mmHg"
            rainChanceText = "Șanse de ploaie: --%"
            rainChance = 0.5
            return
        }

        isUpdating = true

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }

            if error != nil {
                self.pressureText = "--.- mmHg"
                self.rainChanceText = "Șanse de ploaie: --%"
                self.rainChance = 0.5
                return
            }

            guard let pressureKilopascals = data?.pressure.doubleValue else {
                self.pressureText = "--.- mmHg"
                self.rainChanceText = "Șanse de ploaie: --%"
                self.rainChance = 0.5
                return
            }

            let pressureMillimetersOfMercury = pressureKilopascals * self.kilopascalsToMillimetersOfMercury
            self.pressureText = pressureMillimetersOfMercury.formatted(
                .number.precision(.fractionLength(1))
            ) + " mmHg"

            let rainChance = Self.estimatedRainChance(forPressureMillimetersOfMercury: pressureMillimetersOfMercury)
            self.rainChance = rainChance
            self.rainChanceText = "Șanse de ploaie: \((rainChance * 100).formatted(.number.precision(.fractionLength(0))))%"
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isUpdating = false
    }

    private static func estimatedRainChance(forPressureMillimetersOfMercury pressure: Double) -> Double {
        let highPressure = 775.0
        let lowPressure = 735.0
        let normalizedChance = (highPressure - pressure) / (highPressure - lowPressure)
        return min(max(normalizedChance, 0), 1)
    }
}

private extension Color {
    static let heavyRainBlue = Color(red: 0.03, green: 0.12, blue: 0.32)
    static let lightRainYellow = Color(red: 1.0, green: 0.93, blue: 0.55)

    static func interpolate(from start: Color, to end: Color, amount: Double) -> Color {
        let amount = min(max(amount, 0), 1)
        let startComponents = start.components
        let endComponents = end.components

        return Color(
            red: startComponents.red + (endComponents.red - startComponents.red) * amount,
            green: startComponents.green + (endComponents.green - startComponents.green) * amount,
            blue: startComponents.blue + (endComponents.blue - startComponents.blue) * amount
        )
    }

    private var components: (red: Double, green: Double, blue: Double) {
        #if canImport(UIKit)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return (Double(red), Double(green), Double(blue))
        #else
        return (0, 0, 0)
        #endif
    }
}

#Preview {
    ContentView()
}
