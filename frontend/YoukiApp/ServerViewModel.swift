import CoreLocation
import Combine
import Foundation
import SwiftUI

@MainActor
final class ServerViewModel: ObservableObject {
    @Published private(set) var forecastDays: [PrototypeDay] = []
    @Published private(set) var calendarDays: [ForecastWeekDay] = []
    @Published private(set) var isCalendarLoading = false
    @Published private(set) var calendarError: String?
    @Published private(set) var selectedDateIso: String?
    private var calendarLastAttempt: Date?
    private var calendarRetrievedAt: Date?
    private var calendarRequestID = UUID()
    private var calendarTimezone: String?
    private var calendarToday: String?
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
    private let weekLoader: (ForecastCoordinates) async throws -> ForecastWeekResponse
    private let predictionLoader: (ForecastCoordinates) async throws -> SkyColorAPIResponse
    private let timelineLoader: (ForecastCoordinates) async throws -> SkyDayTimelineResponse
    private let locationLoader: () async throws -> CLLocation
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
    private var scoreRetrievedAt: Date?
    private var forecastCoordinates: ForecastCoordinates?
    private var locationLookupID = UUID()
    private var lastRefreshAttempt: Date?
    private var isRefreshing = false
    private var isForeground = true
    private var isLocating = false
    private var geocodeID = UUID()
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
        locationLoader: (() async throws -> CLLocation)? = nil,
        weekLoader: @escaping (ForecastCoordinates) async throws -> ForecastWeekResponse = {
            try await SkyDayTimelineAPIClient(baseURL: AppConfig.serverURL).fetchWeek($0)
        },
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
        let locationManager = self.locationManager
        self.locationLoader = locationLoader ?? { try await locationManager.currentLocation() }
        self.weekLoader = weekLoader
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
        if moment == .sunrise || moment == .sunset {
            return predictions?.predictions.contains { $0.kind == (moment == .sunrise ? .sunrise : .sunset) } ?? false
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
            if useDeviceLocation { await loadDeviceLocation() }
            else { await refreshIfNeeded() }
            return
        }
        if useDeviceLocation {
            await loadDeviceLocation()
        } else if let coordinates {
            await load(coordinates)
        }
    }

    func showSample() {
        resetCalendar()
        requestID = UUID()
        locationLookupID = UUID()
        isLocating = false
        locationManager.cancelCurrentLocationRequest()
        invalidateGeocoding()
        clockTask?.cancel()
        timeline = nil
        predictions = nil
        scenes = [:]
        forecastCoordinates = nil
        retrievedAt = nil
        scoreRetrievedAt = nil
        isRefreshing = false
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
        guard !isLocating else { return }
        useDeviceLocation = true
        locationLookupID = UUID()
        let lookupID = locationLookupID
        invalidateGeocoding()
        isLocating = true
        defer {
            if locationLookupID == lookupID { isLocating = false }
        }
        do {
            let location = try await locationLoader()
            guard locationLookupID == lookupID else { return }
            guard let resolved = ForecastCoordinates(
                latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil
            ) else { throw LocationProviderError.unavailable }
            coordinates = resolved
            if hasLiveSky, let forecastCoordinates,
               Self.distance(from: resolved, to: forecastCoordinates) <= Self.sameForecastAreaRadiusMeters {
                self.coordinates = resolved
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
        resetCalendar()
        requestID = UUID()
        invalidateGeocoding()
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
        scoreRetrievedAt = nil
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
            guard let responseCoordinates = Self.responseCoordinates(value.location) else {
                failures.append("Sky: the server returned an invalid location.")
                break
            }
            if value.targetDateIso != Self.localDate(now(), timezone: value.location.timezoneId)
                || Self.distance(from: coordinates, to: responseCoordinates) > Self.sameForecastAreaRadiusMeters {
                failures.append("Sky: the returned timeline is for a different day or location.")
            } else {
                scenes = Self.makeScenes(for: value, at: now())
                let sampler = SkySceneSampler(timeline: value)
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
            if let matching = Self.matchingPredictions(value, coordinates: coordinates,
                                                        timeline: timeline, at: now()) {
                predictions = matching
                hasLiveForecast = true
                scoreRetrievedAt = now()
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
        // Also supplies tomorrow's upcoming event after today's last milestone.
        await loadCalendar()
    }

    private func rebuildPresentation() {
        if selectedMoment == .now, let timeline {
            currentDate = now()
            scenes[.now] = SkySceneSampler(timeline: timeline).scene(at: currentDate)
        }
        skyScene = scenes[selectedMoment] ?? .fallback
        let partialAtmosphere = timeline.map { SkyTimelineSampler(timeline: $0).hasAtmosphericFallback } ?? false
        let skyStale = retrievedAt.map { now().timeIntervalSince($0) > 1_800 } ?? false
        let scoreStale = scoreRetrievedAt.map { now().timeIntervalSince($0) > 1_800 } ?? true
        if skyStale && hasLiveSky { skyScene = skyScene.withProvenance(.staleForecast) }
        let limited = hasLiveSky && skyScene.quality == .unavailable
        isLive = hasLiveSky && hasLiveForecast && isScoreAvailable && !partialAtmosphere
            && !skyStale && !scoreStale && !limited
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
        geocoder.cancelGeocode()
        geocodeID = UUID()
        let lookupID = geocodeID
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor [weak self] in
                guard let self, self.requestID == id, self.geocodeID == lookupID else { return }
                self.locationName = Self.cityName(from: placemarks?.first) ?? fallback
                self.rebuildPresentation()
            }
        }
    }

    private func invalidateGeocoding() {
        geocodeID = UUID()
        geocoder.cancelGeocode()
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
        guard timeline != nil || selectedDateIso != nil else { return }
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
        if foreground {
            Task {
                if self.useDeviceLocation { await self.loadDeviceLocation() }
                else { await self.refreshIfNeeded() }
            }
        }
    }

    func refreshIfNeeded(force: Bool = false) async {
        guard canLoadLive else { return }
        guard let coordinates, !isRefreshing, isForeground else { return }
        guard let timeline else {
            if selectedDateIso != nil { await loadCalendar(force: force) }
            return
        }
        let date = now()
        guard let localDate = Self.localDate(date, timezone: timeline.location.timezoneId) else { return }
        if let selectedDateIso, selectedDateIso >= localDate {
            await loadCalendar(force: force)
            return
        }
        if localDate != timeline.targetDateIso {
            let id = beginRequest()
            await fetch(coordinates, id: id)
            return
        }
        let age = date.timeIntervalSince(min(retrievedAt ?? .distantPast, scoreRetrievedAt ?? .distantPast))
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
        var failures: [String] = []
        if case .success(let fresh) = skyResult,
           fresh.targetDateIso == localDate,
           let responseCoordinates = Self.responseCoordinates(fresh.location),
           Self.distance(from: coordinates, to: responseCoordinates) <= Self.sameForecastAreaRadiusMeters {
            let replacement = Self.makeScenes(for: fresh, at: date)
            if !replacement.isEmpty {
                self.timeline = fresh
                scenes = replacement
                forecastCoordinates = coordinates
                retrievedAt = now()
            } else {
                failures.append("Sky refresh returned no usable moments.")
            }
        } else {
            failures.append("Sky refresh failed; showing the earlier forecast.")
        }
        if case .success(let updated) = scoreResult,
           let matching = Self.matchingPredictions(updated, coordinates: coordinates,
                                                    timeline: self.timeline, at: date) {
            predictions = matching
            hasLiveForecast = true
            scoreRetrievedAt = now()
        } else {
            predictions = nil
            hasLiveForecast = false
            scoreRetrievedAt = nil
            failures.append("Score refresh failed; showing sky details without a current score.")
        }
        if scenes[selectedMoment] == nil {
            selectedMoment = scenes[.now] != nil ? .now :
                (SkyMoment.allCases.first { scenes[$0] != nil } ?? .now)
        }
        errorMessage = failures.isEmpty ? nil : failures.joined(separator: "\n")
        rebuildPresentation()
        await loadCalendar()
    }

    func retryForecast() async {
        if selectedDateIso != nil { await loadCalendar(force: true) }
        else { await loadForecast() }
    }

    func accountTierDidChange() async {
        guard canLoadLive, let coordinates else { return }
        let id = beginRequest()
        await fetch(coordinates, id: id)
    }

    private func resetCalendar() {
        calendarRequestID = UUID()
        calendarDays = []
        calendarError = nil
        calendarRetrievedAt = nil
        calendarLastAttempt = nil
        calendarTimezone = nil
        calendarToday = nil
        selectedDateIso = nil
        isCalendarLoading = false
    }

    func loadCalendar(force: Bool = false) async {
        guard canLoadLive, let coordinates, !isCalendarLoading else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(where: { $0.hasPrefix("-uiSkyFixture") }) { return }
        #endif
        guard requiresAuthentication else { return }
        let localDay = calendarTimezone.flatMap { Self.localDate(now(), timezone: $0) }
        if !force, localDay == calendarToday,
           let calendarRetrievedAt, now().timeIntervalSince(calendarRetrievedAt) < 1_800 { return }
        if !force, let calendarLastAttempt, now().timeIntervalSince(calendarLastAttempt) < 300 { return }
        calendarLastAttempt = now()
        let id = UUID()
        calendarRequestID = id
        isCalendarLoading = true
        calendarError = nil
        do {
            let result = try await weekLoader(coordinates)
            guard calendarRequestID == id else { return }
            guard let returned = Self.responseCoordinates(result.location),
                  Self.distance(from: coordinates, to: returned) <= Self.sameForecastAreaRadiusMeters,
                  result.today == Self.localDate(now(), timezone: result.location.timezoneId),
                  result.days.count == 7,
                  result.days.enumerated().allSatisfy({ offset, row in
                      Self.offsetDay(result.today, by: offset) == row.id
                      && row.forecastType == (offset < 2 ? "forecast" : "outlook")
                  }),
                  result.days.allSatisfy({ row in
                      (row.timeline.map { value in
                          value.targetDateIso == row.id && value.location.timezoneId == result.location.timezoneId
                          && Self.responseCoordinates(value.location).map { Self.distance(from: coordinates, to: $0) <= Self.sameForecastAreaRadiusMeters } == true
                      } ?? true)
                      && (row.predictions.map { response in
                          response.location.timezoneId == result.location.timezoneId
                          && Self.responseCoordinates(response.location).map { Self.distance(from: coordinates, to: $0) <= Self.sameForecastAreaRadiusMeters } == true
                          && response.predictions.allSatisfy { $0.window.eventTimeIso.hasPrefix(row.id + "T") }
                      } ?? true)
                  }) else { throw SkyDayTimelineAPIError.invalidResponse }
            calendarDays = result.days
            calendarTimezone = result.location.timezoneId
            calendarToday = result.today
            calendarRetrievedAt = now()
            let dateToRestore = selectedDateIso ?? ((!hasLiveSky || !hasLiveForecast) ? result.today : nil)
            if let dateToRestore,
               let updated = result.days.first(where: { $0.id == dateToRestore && $0.isAvailable }) {
                selectDay(updated, keepMoment: true)
            }
        } catch {
            guard calendarRequestID == id else { return }
            calendarError = error.localizedDescription
        }
        if calendarRequestID == id { isCalendarLoading = false }
    }

    func selectDay(_ day: ForecastWeekDay, keepMoment: Bool = false) {
        guard day.isAvailable, let coordinates else { return }
        // Invalidate outstanding current-day refreshes before publishing the selected day.
        requestID = UUID()
        isRefreshing = false
        selectedDateIso = day.id
        timeline = day.timeline
        predictions = day.predictions.flatMap { response in
            guard let returned = Self.responseCoordinates(response.location),
                  Self.distance(from: coordinates, to: returned) <= Self.sameForecastAreaRadiusMeters,
                  response.predictions.allSatisfy({ $0.window.eventTimeIso.hasPrefix(day.id + "T") }) else { return nil }
            return response.predictions.isEmpty ? nil : response
        }
        hasLiveSky = timeline != nil
        hasLiveForecast = predictions != nil
        currentDate = now()
        scenes = timeline.map { Self.makeScenes(for: $0, at: now()) } ?? [:]
        retrievedAt = calendarRetrievedAt
        scoreRetrievedAt = calendarRetrievedAt
        if !keepMoment || !isAvailable(selectedMoment) {
            if day.id == Self.localDate(now(), timezone: calendarTimezone ?? ""), scenes[.now] != nil {
                selectedMoment = .now
            } else {
                selectedMoment = SkyMoment.allCases.first { $0 != .now && scenes[$0] != nil }
                    ?? (day.sunrisePrediction != nil ? .sunrise : .sunset)
            }
        }
        errorMessage = day.errors.isEmpty ? nil : day.errors.joined(separator: "\n")
        isLoading = false
        forecastDays = []
        rebuildPresentation()
        startClockRefresh()
    }

    var displayedMoments: [SkyMoment] {
        let day = selectedDateIso ?? timeline?.targetDateIso
        let today = Self.localDate(now(), timezone: timeline?.location.timezoneId ?? calendarTimezone ?? "UTC")
        return day != nil && day != today ? SkyMoment.allCases.filter { $0 != .now } : SkyMoment.allCases
    }

    var calendarUpdatedLabel: String? {
        guard let calendarRetrievedAt else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: calendarTimezone ?? "UTC")
        formatter.dateFormat = "MMM d, HH:mm"
        return "Updated " + formatter.string(from: calendarRetrievedAt)
    }

    var displayedDateLabel: String {
        guard let day = selectedDateIso ?? timeline?.targetDateIso ?? forecastDays.first?.id,
              let timezone = timeline?.location.timezoneId ?? calendarTimezone ?? predictions?.location.timezoneId
        else { return "Forecast" }
        return dateLabel(day, timezone: timezone)
    }

    func dateLabel(_ day: String, timezone: String? = nil) -> String {
        let zone = timezone ?? calendarTimezone ?? timeline?.location.timezoneId ?? "UTC"
        let today = Self.localDate(now(), timezone: zone)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: day) else { return day }
        let tomorrow = today.flatMap { formatter.date(from: $0) }.map { $0.addingTimeInterval(86_400) }
            .map { formatter.string(from: $0) }
        formatter.dateFormat = "EEE, MMM d"
        let label = formatter.string(from: date)
        if day == today { return "Today · " + label }
        if day == tomorrow { return "Tomorrow · " + label }
        return label
    }

    var forecastProvenance: String {
        let day = selectedDateIso ?? timeline?.targetDateIso
        let isOutlook = calendarDays.first { $0.id == day }?.forecastType == "outlook"
        let generated = predictions?.generatedAtIso ?? timeline?.generatedAtIso
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let updated = generated.flatMap { formatter.date(from: $0) }
        let clock = DateFormatter()
        clock.timeZone = TimeZone(identifier: timeline?.location.timezoneId ?? calendarTimezone ?? "UTC")
        clock.dateFormat = "HH:mm"
        let update = updated.map { " · Updated " + clock.string(from: $0) } ?? ""
        let earlier = updated.map { now().timeIntervalSince($0) > 1_800 } ?? false
        let prefix = earlier ? "Earlier forecast · " : ""
        return prefix + (isOutlook ? "Outlook · Conditions may change" : "Forecast · " + (forecastDays.first?.confidenceLabel ?? "Input coverage unavailable")) + update
    }

    func hasPassed(_ moment: SkyMoment) -> Bool {
        guard moment != .now, let timeline,
              let iso = moment.localIso(in: timeline.milestones),
              let local = Self.localDateTime(now(), timezone: timeline.location.timezoneId) else { return false }
        return iso < local
    }

    var nextEventLabel: String {
        let today = timeline.flatMap { Self.localDate(now(), timezone: $0.location.timezoneId) }
            ?? calendarToday
        guard let today else { return "Upcoming events unavailable" }
        var candidates = calendarDays.compactMap(\.timeline)
        if let timeline, !candidates.contains(where: { $0.targetDateIso == timeline.targetDateIso }) {
            candidates.append(timeline)
        }
        for day in candidates.sorted(by: { $0.targetDateIso < $1.targetDateIso }) where day.targetDateIso >= today {
            guard let local = Self.localDateTime(now(), timezone: day.location.timezoneId) else { continue }
            for moment in SkyMoment.allCases where moment != .now {
                if let iso = moment.localIso(in: day.milestones), iso > local {
                    let prefix = day.targetDateIso == today ? "Today" : dateLabel(day.targetDateIso).components(separatedBy: " · ").first ?? day.targetDateIso
                    return "Next: \(prefix) · \(moment.label.lowercased()) · \(ForecastMapper.milestoneTime(iso))"
                }
            }
        }
        if isCalendarLoading { return "Loading upcoming events…" }
        if calendarError != nil { return "Upcoming events unavailable · Refresh to retry" }
        return "No upcoming event available"
    }

    private static func offsetDay(_ day: String, by offset: Int) -> String? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: day).map { formatter.string(from: $0.addingTimeInterval(Double(offset) * 86_400)) }
    }

    private static func localDateTime(_ date: Date, timezone: String) -> String? {
        guard let zone = TimeZone(identifier: timezone) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
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

    private static func responseCoordinates(_ location: SkyDayTimelineResponse.ResolvedLocation) -> ForecastCoordinates? {
        ForecastCoordinates(latitude: location.latitude, longitude: location.longitude,
                            altitudeMeters: location.altitudeMeters)
    }

    private static func responseCoordinates(_ location: SkyColorAPIResponse.ResolvedLocation) -> ForecastCoordinates? {
        ForecastCoordinates(latitude: location.latitude, longitude: location.longitude,
                            altitudeMeters: location.altitudeMeters)
    }

    private static func makeScenes(for timeline: SkyDayTimelineResponse, at date: Date) -> [SkyMoment: SkyScene] {
        let sampler = SkySceneSampler(timeline: timeline)
        var result: [SkyMoment: SkyScene] = [:]
        for moment in SkyMoment.allCases {
            if let iso = moment.localIso(in: timeline.milestones),
               let scene = sampler.scene(atLocalIso: iso) {
                result[moment] = scene
            }
        }
        if let current = sampler.scene(at: date) { result[.now] = current }
        return result
    }

    private static func matchingPredictions(
        _ response: SkyColorAPIResponse,
        coordinates: ForecastCoordinates,
        timeline: SkyDayTimelineResponse?,
        at date: Date
    ) -> SkyColorAPIResponse? {
        guard let responseCoordinates = responseCoordinates(response.location),
              distance(from: coordinates, to: responseCoordinates) <= sameForecastAreaRadiusMeters,
              timeline.map({ $0.location.timezoneId == response.location.timezoneId }) ?? true,
              let day = timeline?.targetDateIso ?? localDate(date, timezone: response.location.timezoneId)
        else { return nil }
        let matching = response.predictions.filter { $0.window.eventTimeIso.hasPrefix(day + "T") }
        guard !matching.isEmpty else { return nil }
        return SkyColorAPIResponse(location: response.location, generatedAtIso: response.generatedAtIso,
                                   predictions: matching)
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
