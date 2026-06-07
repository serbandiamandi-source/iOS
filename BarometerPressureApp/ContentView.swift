import CoreMotion
import SwiftUI

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

            Text(viewModel.statusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
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
    @Published private(set) var statusText = "Waiting for barometer data…"

    private let altimeter = CMAltimeter()
    private let kilopascalsToMillimetersOfMercury = 7.50061683
    private var isUpdating = false

    func startUpdates() {
        guard !isUpdating else { return }

        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            statusText = "This iPhone does not report barometer data."
            return
        }

        isUpdating = true
        statusText = "Reading internal barometer…"

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }

            if let error {
                self.pressureText = "--.- mmHg"
                self.statusText = "Barometer error: \(error.localizedDescription)"
                return
            }

            guard let pressureKilopascals = data?.pressure.doubleValue else {
                self.pressureText = "--.- mmHg"
                self.statusText = "No pressure reading available yet."
                return
            }

            let pressureMillimetersOfMercury = pressureKilopascals * self.kilopascalsToMillimetersOfMercury
            self.pressureText = pressureMillimetersOfMercury.formatted(
                .number.precision(.fractionLength(1))
            ) + " mmHg"
            self.statusText = "Live reading from CMAltimeter"
        }
    }

    func stopUpdates() {
        guard isUpdating else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isUpdating = false
    }
}

#Preview {
    ContentView()
}
