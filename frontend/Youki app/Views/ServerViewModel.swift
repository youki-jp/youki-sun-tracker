import Combine
import CoreLocation
import Foundation
import SwiftUI
import UIKit

@MainActor
final class ServerViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    struct SunPhaseCard {
        let title: String
        let subtitle: String
        let metricValue: String
        let metricLabel: String
        let countdownText: String
        let progress: Double
    }

    struct TimelineEntry: Identifiable {
        let id = UUID()
        let title: String
        let symbol: String
        let value: String
    }

    struct SunPlacement {
        let xRatio: CGFloat
        let yRatio: CGFloat
        let opacity: Double
    }

    @Published private(set) var sunData: SunriseSunsetResponse?
    @Published private(set) var locationName = "Finding your sky..."
    @Published private(set) var headingDegrees = 0.0
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasLocationFix = false
    @Published private var now = Date()

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let isoFormatter = ISO8601DateFormatter()
    private let backendUrl: URL
    private let haptics = SunAlignmentHaptics()

    private var timerCancellable: AnyCancellable?
    private var lastFetchedLocation: CLLocation?
    private var currentLocation: CLLocation?

    override init() {
        backendUrl = ServerViewModel.resolveBackendURL()

        super.init()

        print("[ServerViewModel] Resolved backend URL:", backendUrl.absoluteString)

        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.headingFilter = 2

        timerCancellable = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] value in
                self?.now = value
            }
    }

    private static func resolveBackendURL() -> URL {
        let environmentValue = ProcessInfo.processInfo.environment["BACKEND_URL"]
        let plistValue = Bundle.main.object(forInfoDictionaryKey: "BackendURL") as? String
        let rawValue = environmentValue ?? plistValue ?? "http://localhost:3000/sun"

        guard var components = URLComponents(string: rawValue) else {
            return URL(string: "http://localhost:3000/sun")!
        }

        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if trimmedPath.isEmpty {
            components.path = "/sun"
        }

        return components.url ?? URL(string: "http://localhost:3000/sun")!
    }

    func start() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            beginTracking()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Location access is needed to find sunrise and sunset for where you are."
        @unknown default:
            errorMessage = "Location permissions are in an unknown state."
        }
    }

    func refresh() {
        guard let currentLocation else { return }

        Task {
            await fetchSunResult(for: currentLocation)
        }
    }

    var phaseCard: SunPhaseCard {
        guard
            let sunrise = eventDate(for: \.sunrise),
            let sunset = eventDate(for: \.sunset),
            let solarNoon = eventDate(for: \.solarNoon)
        else {
            return SunPhaseCard(
                title: hasLocationFix ? "Loading" : "Waiting for location",
                subtitle: hasLocationFix ? "Fetching your sun path" : "Enable location to begin",
                metricValue: "--",
                metricLabel: "Sun data",
                countdownText: "Stand by",
                progress: 0
            )
        }

        if now < sunrise {
            let untilSunrise = sunrise.timeIntervalSince(now)
            let nightWindow = max(sunrise.timeIntervalSince(startOfDay(for: sunrise)), 1)
            let nightProgress = 1 - min(max(untilSunrise / nightWindow, 0), 1)

            return SunPhaseCard(
                title: "Sunrise",
                subtitle: "at \(displayTime(sunrise))",
                metricValue: "\(Int((nightProgress * 100).rounded()))%",
                metricLabel: "Night almost over",
                countdownText: "in \(relativeDuration(untilSunrise))",
                progress: nightProgress
            )
        }

        if now <= sunset {
            let daylightProgress = progressBetween(start: sunrise, end: sunset, date: now)

            return SunPhaseCard(
                title: now < solarNoon ? "Sunrise" : "Daylight",
                subtitle: now < solarNoon ? "at \(displayTime(sunrise))" : "until \(displayTime(sunset))",
                metricValue: "\(Int((daylightProgress * 100).rounded()))%",
                metricLabel: "Daylight progress",
                countdownText: "Sunset in \(relativeDuration(sunset.timeIntervalSince(now)))",
                progress: daylightProgress
            )
        }

        let sinceSunset = now.timeIntervalSince(sunset)
        let eveningWindow: TimeInterval = 2 * 60 * 60
        let eveningProgress = 1 - min(max(sinceSunset / eveningWindow, 0), 1)

        return SunPhaseCard(
            title: "Sunset",
            subtitle: "at \(displayTime(sunset))",
            metricValue: "\(Int((eveningProgress * 100).rounded()))%",
            metricLabel: "Afterglow remaining",
            countdownText: "Solar noon was \(displayTime(solarNoon))",
            progress: eveningProgress
        )
    }

    var timelineEntries: [TimelineEntry] {
        let firstLight = eventDate(for: \.firstLight)
        let dawn = eventDate(for: \.dawn)
        let sunrise = eventDate(for: \.sunrise)
        let sunset = eventDate(for: \.sunset)
        let dusk = eventDate(for: \.dusk)
        let goldenHour = eventDate(for: \.goldenHour)

        return [
            TimelineEntry(title: "First Light", symbol: "sparkles", value: displayTime(firstLight)),
            TimelineEntry(title: "Golden Hour", symbol: "sun.haze", value: displayRange(start: dawn, end: sunrise)),
            TimelineEntry(title: "Sunrise", symbol: "sunrise", value: displayTime(sunrise)),
            TimelineEntry(title: "Daylight", symbol: "sun.max", value: displayRange(start: sunrise, end: sunset)),
            TimelineEntry(title: "Golden Hour", symbol: "sunset", value: eveningGoldenHourRange(start: goldenHour, dusk: dusk, sunset: sunset))
        ]
    }

    var sunPlacement: SunPlacement {
        guard
            let sunrise = eventDate(for: \.sunrise),
            let sunset = eventDate(for: \.sunset),
            let solarNoon = eventDate(for: \.solarNoon)
        else {
            return SunPlacement(xRatio: 0.5, yRatio: 0.88, opacity: 0.5)
        }

        let azimuth = estimatedSunAzimuth(sunrise: sunrise, solarNoon: solarNoon, sunset: sunset)
        let relativeBearing = normalizedDegrees(azimuth - headingDegrees)
        let xRatio = min(max(0.5 + CGFloat(relativeBearing / 180) * 0.85, 0.04), 0.96)

        if now < sunrise || now > sunset {
            return SunPlacement(xRatio: xRatio, yRatio: 0.9, opacity: 0.35)
        }

        let dayProgress = progressBetween(start: sunrise, end: sunset, date: now)
        let arcHeight = sin(dayProgress * .pi)
        let yRatio = 0.84 - CGFloat(arcHeight) * 0.58
        let opacity = abs(relativeBearing) > 120 ? 0.2 : 1

        return SunPlacement(xRatio: xRatio, yRatio: yRatio, opacity: opacity)
    }

    var cardCaption: String {
        let heading = Int(headingDegrees.rounded())
        return "Sun aligned against heading \(heading)deg"
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            errorMessage = nil
            beginTracking()
        case .denied, .restricted:
            errorMessage = "Location access is turned off. Enable it in Settings to place the sun correctly."
        case .notDetermined:
            break
        @unknown default:
            errorMessage = "Location permissions are in an unknown state."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        hasLocationFix = true
        currentLocation = location
        maybeReverseGeocode(location)

        let shouldFetch: Bool
        if let lastFetchedLocation {
            shouldFetch = location.distance(from: lastFetchedLocation) > 250
        } else {
            shouldFetch = true
        }

        guard shouldFetch else { return }

        lastFetchedLocation = location

        Task {
            await fetchSunResult(for: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        if heading >= 0 {
            headingDegrees = heading
            updateAlignmentHaptics()
        }
    }

    func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool {
        true
    }

    private func beginTracking() {
        locationManager.startUpdatingLocation()

        if CLLocationManager.headingAvailable() {
            locationManager.startUpdatingHeading()
        }
    }

    private func maybeReverseGeocode(_ location: CLLocation) {
        guard locationName == "Finding your sky..." || location.distance(from: lastFetchedLocation ?? location) > 1000 else {
            return
        }

        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }

            if let placemark = placemarks?.first {
                let pieces = [placemark.locality, placemark.administrativeArea]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }

                if pieces.isEmpty {
                    self.locationName = String(
                        format: "%.4f, %.4f",
                        location.coordinate.latitude,
                        location.coordinate.longitude
                    )
                } else {
                    self.locationName = pieces.joined(separator: ", ")
                }
            }
        }
    }

    private func fetchSunResult(for location: CLLocation) async {
        isLoading = true
        errorMessage = nil

        guard var components = URLComponents(url: backendUrl, resolvingAgainstBaseURL: false) else {
            errorMessage = "The backend URL is invalid."
            isLoading = false
            return
        }

        components.queryItems = [
            URLQueryItem(name: "lat", value: String(location.coordinate.latitude)),
            URLQueryItem(name: "lng", value: String(location.coordinate.longitude))
        ]

        guard let url = components.url else {
            errorMessage = "Unable to create the backend request."
            isLoading = false
            return
        }

        print("[ServerViewModel] Fetching sun data from:", url.absoluteString)

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse {
                print("[ServerViewModel] HTTP status:", httpResponse.statusCode)
            }

            if let responseBody = String(data: data, encoding: .utf8) {
                print("[ServerViewModel] Raw response body:", responseBody)
            } else {
                print("[ServerViewModel] Raw response body could not be converted to UTF-8 text.")
            }

            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                errorMessage = "The backend returned status \(httpResponse.statusCode)."
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            sunData = try decoder.decode(SunriseSunsetResponse.self, from: data)
            print("[ServerViewModel] Decoding succeeded.")
            updateAlignmentHaptics()
        } catch let decodingError as DecodingError {
            print("[ServerViewModel] Decoding failed:", describeDecodingError(decodingError))
            errorMessage = "The data couldn't be read because it is missing."
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCannotConnectToHost {
                errorMessage = connectionHelpText(for: backendUrl)
            } else {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case let .keyNotFound(key, context):
            return "Key '\(key.stringValue)' not found. CodingPath: \(codingPathDescription(context.codingPath)). \(context.debugDescription)"
        case let .typeMismatch(type, context):
            return "Type mismatch for \(type). CodingPath: \(codingPathDescription(context.codingPath)). \(context.debugDescription)"
        case let .valueNotFound(type, context):
            return "Value not found for \(type). CodingPath: \(codingPathDescription(context.codingPath)). \(context.debugDescription)"
        case let .dataCorrupted(context):
            return "Data corrupted. CodingPath: \(codingPathDescription(context.codingPath)). \(context.debugDescription)"
        @unknown default:
            return "Unknown decoding error: \(error.localizedDescription)"
        }
    }

    private func codingPathDescription(_ codingPath: [CodingKey]) -> String {
        if codingPath.isEmpty {
            return "<root>"
        }

        return codingPath.map(\.stringValue).joined(separator: ".")
    }

    private func connectionHelpText(for url: URL) -> String {
        if let host = url.host, host == "localhost" || host == "127.0.0.1" {
            #if targetEnvironment(simulator)
            return "Could not connect to \(host):3000. Make sure the Bun server is running and serving /sun."
            #else
            return "Could not connect to \(host):3000. On a real iPhone, localhost points to the phone itself. Use your Mac's local IP address and make sure the server is reachable on your Wi-Fi."
            #endif
        }

        if let host = url.host {
            return "Could not connect to \(host):3000. Make sure your Mac and iPhone are on the same Wi-Fi and the Bun server is reachable on the network."
        }

        return "Could not connect to the server."
    }

    private func eventDate(for keyPath: KeyPath<SunResults, String>) -> Date? {
        guard let sunData else { return nil }
        return parseEventDate(
            rawValue: sunData.results[keyPath: keyPath],
            tzid: sunData.results.timezone ?? sunData.tzid
        )
    }

    private func eventDate(for keyPath: KeyPath<SunResults, String?>) -> Date? {
        guard let sunData else { return nil }

        guard let rawValue = sunData.results[keyPath: keyPath], !rawValue.isEmpty else {
            return nil
        }
        return parseEventDate(rawValue: rawValue, tzid: sunData.results.timezone ?? sunData.tzid)
    }

    private func parseEventDate(rawValue: String, tzid: String?) -> Date? {
        let timeZone = TimeZone(identifier: tzid ?? "") ?? .current

        if let isoDate = isoFormatter.date(from: rawValue) {
            return isoDate
        }

        let fallbackIso = ISO8601DateFormatter()
        fallbackIso.formatOptions = [.withInternetDateTime]
        if let isoDate = fallbackIso.date(from: rawValue) {
            return isoDate
        }

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = timeZone

        for format in ["h:mm:ss a", "h:mm a", "HH:mm:ss", "HH:mm"] {
            parser.dateFormat = format

            if let parsedTime = parser.date(from: rawValue) {
                let calendar = Calendar(identifier: .gregorian)
                let sourceComponents = calendar.dateComponents(in: timeZone, from: parsedTime)
                let todayComponents = calendar.dateComponents(in: timeZone, from: now)

                var mergedComponents = DateComponents()
                mergedComponents.timeZone = timeZone
                mergedComponents.year = todayComponents.year
                mergedComponents.month = todayComponents.month
                mergedComponents.day = todayComponents.day
                mergedComponents.hour = sourceComponents.hour
                mergedComponents.minute = sourceComponents.minute
                mergedComponents.second = sourceComponents.second

                return calendar.date(from: mergedComponents)
            }
        }

        return nil
    }

    private func displayTime(_ date: Date?) -> String {
        guard let date else { return "--" }

        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func displayRange(start: Date?, end: Date?) -> String {
        guard let start, let end else { return "--" }
        return "\(displayTime(start))-\(displayTime(end))"
    }

    private func eveningGoldenHourRange(start: Date?, dusk: Date?, sunset: Date?) -> String {
        if let start, let dusk {
            return displayRange(start: start, end: dusk)
        }

        return displayRange(start: sunset, end: dusk)
    }

    private func updateAlignmentHaptics() {
        guard
            let sunrise = eventDate(for: \.sunrise),
            let sunset = eventDate(for: \.sunset),
            let solarNoon = eventDate(for: \.solarNoon)
        else {
            haptics.reset()
            return
        }

        let azimuth = estimatedSunAzimuth(sunrise: sunrise, solarNoon: solarNoon, sunset: sunset)
        let relativeBearing = normalizedDegrees(azimuth - headingDegrees)
        haptics.update(relativeBearing: relativeBearing)
    }

    private func relativeDuration(_ interval: TimeInterval) -> String {
        if interval <= 0 {
            return "now"
        }

        let minutes = Int(interval / 60)
        let hours = minutes / 60
        let remainderMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainderMinutes)m"
        }

        return "\(max(remainderMinutes, 1)) min"
    }

    private func progressBetween(start: Date, end: Date, date: Date) -> Double {
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(max(date.timeIntervalSince(start) / total, 0), 1)
    }

    private func estimatedSunAzimuth(sunrise: Date, solarNoon: Date, sunset: Date) -> Double {
        if now <= sunrise {
            return 90
        }

        if now >= sunset {
            return 270
        }

        if now <= solarNoon {
            let morningProgress = progressBetween(start: sunrise, end: solarNoon, date: now)
            return 90 + (90 * morningProgress)
        }

        let afternoonProgress = progressBetween(start: solarNoon, end: sunset, date: now)
        return 180 + (90 * afternoonProgress)
    }

    private func normalizedDegrees(_ degrees: Double) -> Double {
        var result = degrees.truncatingRemainder(dividingBy: 360)

        if result > 180 {
            result -= 360
        } else if result < -180 {
            result += 360
        }

        return result
    }

    private func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}

@MainActor
private final class SunAlignmentHaptics {
    private let degreeStepFeedback = UISelectionFeedbackGenerator()
    private let alignedImpact = UIImpactFeedbackGenerator(style: .medium)

    private var hasTriggeredAligned = false
    private var lastDegreeBucket: Int?

    init() {
        degreeStepFeedback.prepare()
        alignedImpact.prepare()
    }

    func update(relativeBearing: Double) {
        let distance = abs(relativeBearing)
        let degreeBucket = Int((relativeBearing / 5).rounded())

        if let lastDegreeBucket, lastDegreeBucket != degreeBucket {
            degreeStepFeedback.selectionChanged()
            degreeStepFeedback.prepare()
        } else if lastDegreeBucket == nil {
            degreeStepFeedback.prepare()
        }

        lastDegreeBucket = degreeBucket

        if distance <= 1 {
            if !hasTriggeredAligned {
                alignedImpact.impactOccurred(intensity: 0.95)
                alignedImpact.prepare()
                hasTriggeredAligned = true
            }
        } else {
            hasTriggeredAligned = false
        }
    }

    func reset() {
        hasTriggeredAligned = false
        lastDegreeBucket = nil
    }
}
