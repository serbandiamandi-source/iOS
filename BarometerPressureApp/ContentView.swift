import Charts
import CoreLocation
import CoreMotion
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = BarometricPressureViewModel()
    @State private var showsPressureTrend = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 16) {
                Text("Presiune atmosferica")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text(viewModel.pressureText)
                    .font(.system(size: 52, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())

                VStack(spacing: 4) {
                    Text("Altitudine satelit")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(viewModel.satelliteAltitudeText)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(viewModel.calitateColor)
                        .contentTransition(.numericText())
                }
                .padding(.top, 8)

                Button {
                    showsPressureTrend = true
                } label: {
                    Label("Trend", systemImage: "chart.xyaxis.line")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)

                Text(viewModel.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()

            Text(viewModel.gpsDebugText)
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .padding(12)
        }
        .task {
            viewModel.startUpdates()
        }
        .onDisappear {
            viewModel.stopUpdates()
        }
        .sheet(isPresented: $showsPressureTrend) {
            PressureTrendView(samples: viewModel.pressureSamples)
        }
    }
}

struct PressureTrendView: View {
    let samples: [PressureSample]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if samples.isEmpty {
                    ContentUnavailableView(
                        "Nu exista date inca",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Aplicatia salveaza cate un esantion de presiune la cel putin 1 ora, timp de maximum 7 zile.")
                    )
                } else {
                    Chart(samples) { sample in
                        LineMark(
                            x: .value("Ora", sample.date),
                            y: .value("Presiune", sample.pressureMillimetersOfMercury)
                        )

                        PointMark(
                            x: .value("Ora", sample.date),
                            y: .value("Presiune", sample.pressureMillimetersOfMercury)
                        )
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
                    }
                    .chartYAxisLabel("mmHg")
                    .padding()
                }
            }
            .navigationTitle("Trend presiune")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PressureSample: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let pressureMillimetersOfMercury: Double

    init(id: UUID = UUID(), date: Date, pressureMillimetersOfMercury: Double) {
        self.id = id
        self.date = date
        self.pressureMillimetersOfMercury = pressureMillimetersOfMercury
    }
}

final class BarometricPressureViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var pressureText = "--.- mmHg"
    @Published private(set) var statusText = "Waiting for barometer data…"
    @Published private(set) var satelliteAltitudeText = "-- m"
    @Published private(set) var CALITATE = 1
    @Published private(set) var satelliteCountText = "N/A"
    @Published private(set) var pressureSamples: [PressureSample] = []

    var gpsDebugText: String {
        "Sat: \(satelliteCountText)\nCALITATE: \(CALITATE)/10\nMedie: \(averageQualityText)/10"
    }

    var calitateColor: Color {
        Color.gpsQualityColor(for: CALITATE)
    }

    private let altimeter = CMAltimeter()
    private let locationManager = CLLocationManager()
    private let sampleStore = PressureSampleStore()
    private let kilopascalsToMillimetersOfMercury = 7.50061683
    private let minimumSampleInterval: TimeInterval = 60 * 60
    private var isUpdating = false
    private var qualityReadings: [Int] = []

    private var averageQualityText: String {
        guard !qualityReadings.isEmpty else { return "--" }
        let average = Double(qualityReadings.reduce(0, +)) / Double(qualityReadings.count)
        return average.formatted(.number.precision(.fractionLength(1)))
    }

    override init() {
        super.init()
        pressureSamples = sampleStore.loadSamples()
        configureLocationManager()
    }

    func startUpdates() {
        startBarometerUpdates()
        startLocationUpdates()
    }

    func stopUpdates() {
        stopBarometerUpdates()
        locationManager.stopUpdatingLocation()
    }

    private func configureLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.activityType = .other
    }

    private func startBarometerUpdates() {
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
            self.recordPressureSampleIfNeeded(pressureMillimetersOfMercury)
        }
    }

    private func stopBarometerUpdates() {
        guard isUpdating else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isUpdating = false
    }

    private func startLocationUpdates() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            satelliteAltitudeText = "-- m"
            CALITATE = 1
        @unknown default:
            satelliteAltitudeText = "-- m"
            CALITATE = 1
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startLocationUpdates()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        satelliteAltitudeText = location.altitude.formatted(.number.precision(.fractionLength(0))) + " m"
        let quality = Self.qualityScore(for: location)
        CALITATE = quality
        recordQualityReading(quality)
        satelliteCountText = "N/A"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        satelliteAltitudeText = "-- m"
        CALITATE = 1
    }

    private func recordQualityReading(_ quality: Int) {
        qualityReadings.append(quality)
        if qualityReadings.count > 20 {
            qualityReadings.removeFirst(qualityReadings.count - 20)
        }
    }

    private func recordPressureSampleIfNeeded(_ pressureMillimetersOfMercury: Double) {
        let now = Date()
        let lastSampleDate = pressureSamples.last?.date ?? .distantPast
        guard now.timeIntervalSince(lastSampleDate) >= minimumSampleInterval else { return }

        pressureSamples.append(
            PressureSample(date: now, pressureMillimetersOfMercury: pressureMillimetersOfMercury)
        )
        pressureSamples = sampleStore.prunedSamples(pressureSamples, relativeTo: now)
        sampleStore.saveSamples(pressureSamples)
    }

    private static func qualityScore(for location: CLLocation) -> Int {
        let horizontalAccuracy = max(location.horizontalAccuracy, 0)
        let verticalAccuracy = max(location.verticalAccuracy, 0)
        let combinedAccuracy = max(horizontalAccuracy, verticalAccuracy)

        switch combinedAccuracy {
        case 0..<5:
            return 10
        case 5..<8:
            return 9
        case 8..<12:
            return 8
        case 12..<20:
            return 7
        case 20..<35:
            return 6
        case 35..<50:
            return 5
        case 50..<75:
            return 4
        case 75..<100:
            return 3
        case 100..<150:
            return 2
        default:
            return 1
        }
    }
}

private struct PressureSampleStore {
    private let key = "pressureSamples.v1"
    private let maximumSampleAge: TimeInterval = 7 * 24 * 60 * 60

    func loadSamples() -> [PressureSample] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        let samples = (try? JSONDecoder().decode([PressureSample].self, from: data)) ?? []
        return prunedSamples(samples, relativeTo: Date())
    }

    func saveSamples(_ samples: [PressureSample]) {
        guard let data = try? JSONEncoder().encode(samples) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func prunedSamples(_ samples: [PressureSample], relativeTo date: Date) -> [PressureSample] {
        let oldestAllowedDate = date.addingTimeInterval(-maximumSampleAge)
        return samples.filter { $0.date >= oldestAllowedDate }.sorted { $0.date < $1.date }
    }
}

private extension Color {
    static func gpsQualityColor(for quality: Int) -> Color {
        let clampedQuality = min(max(quality, 1), 10)
        let stops: [(quality: Double, red: Double, green: Double, blue: Double)] = [
            (1, 0.90, 0.05, 0.05),
            (4, 1.00, 0.45, 0.00),
            (7, 1.00, 0.90, 0.00),
            (10, 0.00, 0.65, 0.25)
        ]

        guard let upperIndex = stops.firstIndex(where: { Double(clampedQuality) <= $0.quality }) else {
            return Color(red: 0.00, green: 0.65, blue: 0.25)
        }

        guard upperIndex > 0 else {
            let stop = stops[upperIndex]
            return Color(red: stop.red, green: stop.green, blue: stop.blue)
        }

        let lower = stops[upperIndex - 1]
        let upper = stops[upperIndex]
        let progress = (Double(clampedQuality) - lower.quality) / (upper.quality - lower.quality)

        return Color(
            red: lower.red + (upper.red - lower.red) * progress,
            green: lower.green + (upper.green - lower.green) * progress,
            blue: lower.blue + (upper.blue - lower.blue) * progress
        )
    }
}

#Preview {
    ContentView()
}
