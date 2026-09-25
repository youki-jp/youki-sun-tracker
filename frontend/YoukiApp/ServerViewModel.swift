import CoreLocation
import Combine
import Foundation
import SwiftUI

@MainActor
final class ServerViewModel: ObservableObject {
    @Published private(set) var forecastDays: [PrototypeDay] = []
    @Published private(set) var statusText = "Finding location"
    @Published private(set) var isLoading = true
    @Published private(set) var isLive = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var skyAppearance = SkyAppearance.fallback
    @Published private(set) var selectedMoment: SkyMoment = .now
    @Published private(set) var hasLiveSky = false
    @Published private(set) var hasLiveForecast = false
    @Published private(set) var coordinates: ForecastCoordinates?

    private let locationManager = LocationManager()
    private let predictionLoader: (ForecastCoordinates) async throws -> SkyColorAPIResponse
    private let timelineLoader: (ForecastCoordinates) async throws -> SkyDayTimelineResponse
    private var timeline: SkyDayTimelineResponse?
    private var predictions: SkyColorAPIResponse?
    private var appearances: [SkyMoment: SkyAppearance] = [:]
    private var requestID = UUID()
    private var useDeviceLocation = true
    private var currentDate = Date()
    private var clockTask: Task<Void, Never>?

    init(
        predictionLoader: @escaping (ForecastCoordinates) async throws -> SkyColorAPIResponse = { coordinates in
            try await SkyColorAPIClient(baseURL: AppConfig.serverURL).fetchPredictions(
                latitude: coordinates.latitude, longitude: coordinates.longitude,
                altitudeMeters: coordinates.altitudeMeters)
        },
        timelineLoader: @escaping (ForecastCoordinates) async throws -> SkyDayTimelineResponse = { coordinates in
            try await SkyDayTimelineAPIClient(baseURL: AppConfig.serverURL).fetchTimeline(
                latitude: coordinates.latitude, longitude: coordinates.longitude,
                altitudeMeters: coordinates.altitudeMeters)
        }
    ) {
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
                return SkyTimelineSampler(timeline: timeline).appearance(at: Date()) != nil
            }
            return appearances[moment] != nil
        }
        return false
    }

    func select(_ moment: SkyMoment) {
        guard isAvailable(moment) else { return }
        if moment == .now { currentDate = Date() }
        selectedMoment = moment
        rebuildPresentation()
    }

    func loadForecast() async {
        if useDeviceLocation {
            await loadDeviceLocation()
        } else if let coordinates {
            await load(coordinates)
        }
    }

    func loadDeviceLocation() async {
        useDeviceLocation = true
        coordinates = nil
        let id = beginRequest(status: "Finding location")
        do {
            let location = try await locationManager.currentLocation()
            guard requestID == id else { return }
            guard let resolved = ForecastCoordinates(
                latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil
            ) else { throw LocationProviderError.unavailable }
            coordinates = resolved
            await fetch(resolved, id: id)
        } catch {
            guard requestID == id else { return }
            finishFailure(error.localizedDescription)
        }
    }

    func load(_ coordinates: ForecastCoordinates) async {
        useDeviceLocation = false
        self.coordinates = coordinates
        let id = beginRequest(status: "Loading forecast")
        await fetch(coordinates, id: id)
    }

    private func beginRequest(status: String) -> UUID {
        requestID = UUID()
        clockTask?.cancel()
        clockTask = nil
        isLoading = true
        errorMessage = nil
        statusText = status
        timeline = nil
        predictions = nil
        appearances = [:]
        skyAppearance = .fallback
        forecastDays = []
        hasLiveSky = false
        hasLiveForecast = false
        isLive = false
        selectedMoment = .now
        return requestID
    }

    private func fetch(_ coordinates: ForecastCoordinates, id: UUID) async {
        statusText = "Loading forecast"
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
            let sampler = SkyTimelineSampler(timeline: value)
            for moment in SkyMoment.allCases {
                if let iso = moment.localIso(in: value.milestones),
                   let appearance = sampler.appearance(atLocalIso: iso) {
                    appearances[moment] = appearance
                }
            }
            currentDate = Date()
            if let currentAppearance = sampler.appearance(at: currentDate) {
                appearances[.now] = currentAppearance
            }
            if !appearances.isEmpty {
                timeline = value
                hasLiveSky = true
            } else {
                failures.append("Sky: no usable solar milestones.")
            }
        case .failure(let error):
            failures.append("Sky: " + error.localizedDescription)
        }
        switch score {
        case .success(let value):
            // Independent requests can resolve different days around local midnight.
            let matching = value.predictions.filter { prediction in
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
        if hasLiveSky, let firstAvailable = SkyMoment.allCases.first(where: { appearances[$0] != nil }) {
            currentDate = Date()
            if let timeline, SkyTimelineSampler(timeline: timeline).appearance(at: currentDate) != nil {
                appearances[.now] = SkyTimelineSampler(timeline: timeline).appearance(at: currentDate)
                selectedMoment = .now
            } else {
                selectedMoment = firstAvailable == .now
                    ? (SkyMoment.allCases.first(where: { $0 != .now && appearances[$0] != nil }) ?? .now)
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
            currentDate = Date()
            appearances[.now] = SkyTimelineSampler(timeline: timeline).appearance(at: currentDate)
        }
        skyAppearance = appearances[selectedMoment] ?? .fallback
        let partialAtmosphere = timeline.map { SkyTimelineSampler(timeline: $0).hasAtmosphericFallback } ?? false
        isLive = hasLiveSky && hasLiveForecast && isScoreAvailable && !partialAtmosphere
        switch (hasLiveSky, hasLiveForecast && isScoreAvailable) {
        case (true, true): statusText = partialAtmosphere ? "Live sky · partial atmosphere" : "Live sky and forecast"
        case (true, false): statusText = "Live sky · score unavailable"
        case (false, true): statusText = "Live score · sky unavailable"
        case (false, false): statusText = "Forecast unavailable"
        }
        if let predictions, let day = ForecastMapper.makeDay(
            from: predictions, locationName: coordinates?.label ?? "Current location",
            generatedRamp: hasLiveSky ? skyAppearance.ramp.map { Color(hex: $0) } : nil,
            moment: selectedMoment, timeline: timeline, currentDate: currentDate
        ) {
            forecastDays = [day]
        } else if let timeline {
            forecastDays = [ForecastMapper.timelineDay(timeline,
                locationName: coordinates?.label ?? "Current location",
                moment: selectedMoment, appearance: skyAppearance, currentDate: currentDate)]
        }
    }

    private func finishFailure(_ message: String) {
        isLoading = false
        selectedMoment = .now
        statusText = "Forecast unavailable"
        errorMessage = message
    }

    private func startClockRefresh() {
        clockTask?.cancel()
        guard timeline != nil else { return }
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
                guard let self else { return }
                self.currentDate = Date()
                if self.selectedMoment == .now, let timeline = self.timeline,
                   SkyTimelineSampler(timeline: timeline).appearance(at: self.currentDate) == nil,
                   let milestone = SkyMoment.allCases.first(where: { $0 != .now && self.appearances[$0] != nil }) {
                    self.selectedMoment = milestone
                }
                self.rebuildPresentation()
            }
        }
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
