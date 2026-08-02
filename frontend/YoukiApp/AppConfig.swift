import Foundation

enum AppConfig {
    static let environmentKey = "BACKEND_URL"
    static let defaultServerURLString = "http://localhost:3000"

    static var serverURL: URL {
        let configuredValue = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let configuredValue,
           !configuredValue.isEmpty,
           let url = URL(string: configuredValue) {
            return url
        }

        guard let fallbackURL = URL(string: defaultServerURLString) else {
            preconditionFailure("Default server URL must be valid.")
        }

        return fallbackURL
    }
}
