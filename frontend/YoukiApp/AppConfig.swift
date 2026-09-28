import Foundation

enum AppConfig {
    static let environmentKey = "BACKEND_URL"
    #if DEBUG
    static let defaultServerURLString = "http://localhost:3000"
    #else
    static let defaultServerURLString = "https://youki-server-2idly.ondigitalocean.app"
    #endif

    static var serverURL: URL {
        let configuredValue = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let configuredValue,
           !configuredValue.isEmpty,
           let url = URL(string: configuredValue),
           (url.scheme == "https" || (url.scheme == "http" && url.host == "localhost")) {
            return url
        }

        guard let fallbackURL = URL(string: defaultServerURLString) else {
            preconditionFailure("Default server URL must be valid.")
        }

        return fallbackURL
    }
}
