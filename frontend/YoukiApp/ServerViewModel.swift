import CoreLocation
import Combine
import Foundation
import SwiftUI

@MainActor
final class ServerViewModel: ObservableObject {
    @Published private(set) var forecastDays: [PrototypeDay] = []
    @Published private(set) var isLoading = true
    @Published private(set) var isLive = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var skyScene = SkyScene.fallback
    @Published private(set) var selectedMoment: SkyMoment = .now
    @Published private(set) var hasLiveSky = false
    @Published private(set) var hasLiveForecast = false
    @Published private(set) var coordinates: ForecastCoordinates?
    @Published private(set) var locationName = "Current location"

    private let locationManager = LocationManager()
    private let geocoder = CLGeocoder()
    private let predictionLoader: (ForecastCoordinates) async throws -> SkyColorAPIResponse
    private let timelineLoader: (ForecastCoordinates) async throws -> SkyDayTimelineResponse
    private var timeline: SkyDayTimelineResponse?
    private var predictions: SkyColorAPIResponse?
    private var scenes: [SkyMoment: SkyScene] = [:]
    private var requestID = UUID()
    private var useDeviceLocation = true
    private var currentDate = Date()
    private var clockTask: Task<Void, Never>?
    private let now: () -> Date
    private let requiresAuthentication: Bool
    private var retrievedAt: Date?
    private var forecastCoordinates: ForecastCoordinates?
    private var locationLookupID = UUID()
    private var lastRefreshAttempt: Date?
    private var isRefreshing = false
    private var isForeground = true
    private static let sameForecastAreaRadiusMeters: CLLocationDistance = 10_000

    var skyAppearance: SkyAppearance { skyScene.base }
    private var canLoadLive: Bool {
        if !requiresAuthentication { return true }
        if AuthSession.shared.isAuthenticated { return true }
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-uiSkyFixture") }
        #else
        return false
        #endif
    }

    init(
        requiresAuthentication: Bool = true,
        now: @escaping () -> Date = Date.init,
        predictionLoader: @escaping (ForecastCoordinates) async throws -> SkyColorAPIResponse = { coordinates in
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiSkyFixture") }) {
                throw URLError(.notConnectedToInternet)
            }
            #endif
            return try await SkyColorAPIClient(baseURL: AppConfig.serverURL).fetchPredictions(
                latitude: coordinates.latitude, longitude: coordinates.longitude,
                altitudeMeters: coordinates.altitudeMeters)
        },
        timelineLoader: @escaping (ForecastCoordinates) async throws -> SkyDayTimelineResponse = { coordinates in
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiSkyFixture") }) {
                return SkySceneDebugFixture.timeline()
            }
            #endif
            return try await SkyDayTimelineAPIClient(baseURL: AppConfig.serverURL).fetchTimeline(
                latitude: coordinates.latitude, longitude: coordinates.longitude,
                altitudeMeters: coordinates.altitudeMeters)
        }
    ) {
        self.requiresAuthentication = requiresAuthentication
        self.now = now
        self.predictionLoader = predictionLoader
        self.timelineLoader = timelineLoader
    }

    var isScoreAvailable: Bool {
        if !hasLiveForecast { return false }
        let hour = timeline.flatMap { Self.localHour(currentDate, timezone: $0.location.timezoneId) } ?? 0
        let evening = selectedMoment == .now ? hour >= 12 : selectedMoment.isEvening
        return predictions?.predictions.contains { $0.kind == (evening ? .sunset : .sunrise) } ?? false
    }

    func isAvailable(_ moment: SkyMoment) -> Bool {
        if timeline != nil {
            if moment == .now, let timeline {
                return SkySceneSampler(timeline: timeline).scene(at: now()) != nil
            }
            return scenes[moment] != nil
        }
        return false
    }

    func select(_ moment: SkyMoment) {
        guard isAvailable(moment) else { return }
        if moment == .now { currentDate = now() }
        selectedMoment = moment
        rebuildPresentation()
    }

    func loadForecast() async {
        guard canLoadLive else {
            showSample()
            return
        }
        if coordinates != nil && hasLiveSky {
            await refreshIfNeeded()
            return
        }
        if useDeviceLocation {
            await loadDeviceLocation()
        } else if let coordinates {
            await load(coordinates)
        }
    }

    func showSample() {
        requestID = UUID()
        clockTask?.cancel()
        timeline = nil
        predictions = nil
        scenes = [:]
        forecastCoordinates = nil
        forecastDays = [PrototypeDay.sampleDays[0]]
        skyScene = .fallback
        hasLiveSky = false
        hasLiveForecast = false
        isLive = false
        isLoading = false
        errorMessage = "Sign in for your live sky. Showing a sample forecast."
    }

    func loadDeviceLocation() async {
        guard canLoadLive else { showSample(); return }
        useDeviceLocation = true
        locationLookupID = UUID()
        let lookupID = locationLookupID
        do {
            let location = try await locationManager.currentLocation()
            guard locationLookupID == lookupID else { return }
            guard let resolved = ForecastCoordinates(
                latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil
            ) else { throw LocationProviderError.unavailable }
            coordinates = resolved
            if hasLiveSky, let forecastCoordinates,
               Self.distance(from: resolved, to: forecastCoordinates) <= Self.sameForecastAreaRadiusMeters {
                resolveLocationName(for: location, requestID: requestID, fallback: "Current location")
                await refreshIfNeeded()
                return
            }
            let id = beginRequest()
            resolveLocationName(for: location, requestID: id, fallback: "Current location")
            await fetch(resolved, id: id)
        } catch {
            guard locationLookupID == lookupID else { return }
            if hasLiveSky {
                errorMessage = error.localizedDescription
                rebuildPresentation()
            } else {
                finishFailure(error.localizedDescription)
            }
        }
    }

    func load(_ coordinates: ForecastCoordinates) async {
        guard canLoadLive else { showSample(); return }
        useDeviceLocation = false
        self.coordinates = coordinates
        let id = beginRequest()
        locationName = "Selected location"
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiSkyFixture") }) {
            locationName = "Tokyo"
        } else {
            resolveLocationName(for: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude),
                                requestID: id, fallback: "Selected location")
        }
        #else
        resolveLocationName(for: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude),
                            requestID: id, fallback: "Selected location")
        #endif
        await fetch(coordinates, id: id)
    }

    private func beginRequest() -> UUID {
        requestID = UUID()
        geocoder.cancelGeocode()
        clockTask?.cancel()
        clockTask = nil
        isLoading = true
        errorMessage = nil
        timeline = nil
        predictions = nil
        scenes = [:]
        skyScene = .fallback
        forecastDays = []
        hasLiveSky = false
        hasLiveForecast = false
        isLive = false
        selectedMoment = .now
        retrievedAt = nil
        lastRefreshAttempt = nil
        isRefreshing = false
        locationName = useDeviceLocation ? "Current location" : "Selected location"
        return requestID
    }

    private func fetch(_ coordinates: ForecastCoordinates, id: UUID) async {
        // A score failure must not discard a usable sky, or vice versa.
        async let scoreResult = capture {
            try await self.predictionLoader(coordinates)
        }
        async let skyResult = capture {
            try await self.timelineLoader(coordinates)
        }
        let (score, sky) = await (scoreResult, skyResult)
        guard requestID == id else { return }
        var failures: [String] = []
        switch sky {
        case .success(let value):
            if value.targetDateIso != Self.localDate(now(), timezone: value.location.timezoneId) {
                failures.append("Sky: the returned timeline is for a different local day.")
            } else {
                let sampler = SkySceneSampler(timeline: value)
                for moment in SkyMoment.allCases {
                    if let iso = moment.localIso(in: value.milestones),
                       let scene = sampler.scene(atLocalIso: iso) {
                        scenes[moment] = scene
                    }
                }
                currentDate = now()
                if let currentScene = sampler.scene(at: currentDate) {
                    scenes[.now] = currentScene
                }
                if !scenes.isEmpty {
                    timeline = value
                    forecastCoordinates = coordinates
                    hasLiveSky = true
                    retrievedAt = now()
                } else {
                    failures.append("Sky: no usable solar milestones.")
                }
            }
        case .failure(let error):
            failures.append("Sky: " + error.localizedDescription)
        }
        switch score {
        case .success(let value):
            // Independent requests can resolve different days around local midnight.
            let matching = value.predictions.filter { prediction in
                guard let day = Self.localDate(now(), timezone: value.location.timezoneId),
                      prediction.window.eventTimeIso.hasPrefix(day + "T") else { return false }
                guard let timeline else { return true }
                return prediction.window.eventTimeIso.hasPrefix(timeline.targetDateIso + "T")
            }
            if !matching.isEmpty {
                predictions = SkyColorAPIResponse(location: value.location,
                    generatedAtIso: value.generatedAtIso, predictions: matching)
                hasLiveForecast = true
            } else {
                failures.append("Score: no forecast for the displayed day.")
            }
        case .failure(let error):
            failures.append("Score: " + error.localizedDescription)
        }
        if hasLiveSky, let firstAvailable = SkyMoment.allCases.first(where: { scenes[$0] != nil }) {
            currentDate = now()
            if let timeline, let currentScene = SkySceneSampler(timeline: timeline).scene(at: currentDate) {
                scenes[.now] = currentScene
                selectedMoment = .now
            } else {
                selectedMoment = firstAvailable == .now
                    ? (SkyMoment.allCases.first(where: { $0 != .now && scenes[$0] != nil }) ?? .now)
                    : firstAvailable
            }
        } else if hasLiveForecast {
            let availableKinds = predictions?.predictions.map(\.kind) ?? []
            if !availableKinds.contains(.sunrise) {
                selectedMoment = .sunset
            } else if !availableKinds.contains(.sunset) {
                selectedMoment = .sunrise
            }
        }
        isLoading = false
        errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
        rebuildPresentation()
        startClockRefresh()
    }

    private func rebuildPresentation() {
        if selectedMoment == .now, let timeline {
            currentDate = now()
            scenes[.now] = SkySceneSampler(timeline: timeline).scene(at: currentDate)
        }
        skyScene = scenes[selectedMoment] ?? .fallback
        let partialAtmosphere = timeline.map { SkyTimelineSampler(timeline: $0).hasAtmosphericFallback } ?? false
        let stale = retrievedAt.map { now().timeIntervalSince($0) > 1_800 } ?? false
        if stale && hasLiveSky { skyScene = skyScene.withProvenance(.staleForecast) }
        let limited = hasLiveSky && skyScene.quality == .unavailable
        isLive = hasLiveSky && hasLiveForecast && isScoreAvailable && !partialAtmosphere && !stale && !limited
        if let predictions, let day = ForecastMapper.makeDay(
            from: predictions, locationName: locationName,
            generatedRamp: hasLiveSky ? skyScene.base.ramp.map { Color(hex: $0) } : nil,
            moment: selectedMoment, timeline: timeline, currentDate: currentDate
        ) {
            forecastDays = [day]
        } else if let timeline {
            forecastDays = [ForecastMapper.timelineDay(timeline,
                locationName: locationName,
                moment: selectedMoment, appearance: skyScene.base, currentDate: currentDate)]
        }
    }

    private func finishFailure(_ message: String) {
        isLoading = false
        selectedMoment = .now
        errorMessage = message
    }

    private func resolveLocationName(for location: CLLocation, requestID id: UUID, fallback: String) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor [weak self] in
                guard let self, self.requestID == id else { return }
                self.locationName = Self.cityName(from: placemarks?.first) ?? fallback
                self.rebuildPresentation()
            }
        }
    }

    private static func cityName(from placemark: CLPlacemark?) -> String? {
        guard let placemark else { return nil }
        return [placemark.locality, placemark.subAdministrativeArea,
                placemark.administrativeArea, placemark.subLocality]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }

    private func startClockRefresh() {
        clockTask?.cancel()
        guard timeline != nil else { return }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                guard let self else { return }
                self.currentDate = self.now()
                if self.selectedMoment == .now, let timeline = self.timeline,
                   SkySceneSampler(timeline: timeline).scene(at: self.currentDate) == nil,
                   let milestone = SkyMoment.allCases.first(where: { $0 != .now && self.scenes[$0] != nil }) {
                    self.selectedMoment = milestone
                }
                self.rebuildPresentation()
                await self.refreshIfNeeded()
            }
        }
    }

    func setForeground(_ foreground: Bool) {
        isForeground = foreground
        if foreground { Task { await refreshIfNeeded() } }
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard canLoadLive else { return }
        guard let coordinates, let timeline, !isRefreshing, isForeground else { return }
        let date = now()
        guard let localDate = Self.localDate(date, timezone: timeline.location.timezoneId) else { return }
        if localDate != timeline.targetDateIso {
            let id = beginRequest()
            await fetch(coordinates, id: id)
            return
        }
        let age = date.timeIntervalSince(retrievedAt ?? .distantPast)
        guard force || age >= 1_800 else { return }
        if !force, let lastRefreshAttempt, date.timeIntervalSince(lastRefreshAttempt) < 300 { return }
        isRefreshing = true
        lastRefreshAttempt = date
        let id = requestID
        async let score = capture { try await predictionLoader(coordinates) }
        async let sky = capture { try await timelineLoader(coordinates) }
        let (scoreResult, skyResult) = await (score, sky)
        guard requestID == id else { return }
        isRefreshing = false
        guard case .success(let fresh) = skyResult, fresh.targetDateIso == localDate else {
            errorMessage = "Sky refresh failed; showing the earlier forecast."
            rebuildPresentation()
            return
        }
        let sampler = SkySceneSampler(timeline: fresh)
        var replacement: [SkyMoment: SkyScene] = [:]
        for moment in SkyMoment.allCases {
            if let iso = moment.localIso(in: fresh.milestones), let scene = sampler.scene(atLocalIso: iso) {
                replacement[moment] = scene
            }
        }
        if let scene = sampler.scene(at: date) { replacement[.now] = scene }
        guard !replacement.isEmpty else {
            errorMessage = "Sky refresh returned no usable moments."
            rebuildPresentation()
            return
        }
        self.timeline = fresh
        scenes = replacement
        retrievedAt = now()
        if case .success(let updated) = scoreResult {
            let matching = updated.predictions.filter { $0.window.eventTimeIso.hasPrefix(localDate + "T") }
            if !matching.isEmpty {
                predictions = SkyColorAPIResponse(location: updated.location,
                    generatedAtIso: updated.generatedAtIso, predictions: matching)
                hasLiveForecast = true
            }
        }
        if scenes[selectedMoment] == nil {
            selectedMoment = scenes[.now] != nil ? .now :
                (SkyMoment.allCases.first { scenes[$0] != nil } ?? .now)
        }
        errorMessage = nil
        rebuildPresentation()
    }

    private static func localDate(_ date: Date, timezone: String) -> String? {
        guard let timezone = TimeZone(identifier: timezone) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timezone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func distance(from first: ForecastCoordinates, to second: ForecastCoordinates) -> CLLocationDistance {
        CLLocation(latitude: first.latitude, longitude: first.longitude).distance(
            from: CLLocation(latitude: second.latitude, longitude: second.longitude))
    }

    private static func localHour(_ date: Date, timezone: String) -> Int? {
        guard let timezone = TimeZone(identifier: timezone) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timezone
        return calendar.component(.hour, from: date)
    }

    private func capture<T>(_ operation: () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await operation()) }
        catch { return .failure(error) }
    }
}
