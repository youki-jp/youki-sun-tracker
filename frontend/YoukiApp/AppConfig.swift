import Foundation

enum AppConfig {
    static let environmentKey = "BACKEND_URL"
    #if DEBUG
    static let defaultServerURLString = "http://localhost:3000"
    #else
    static let defaultServerURLString = "https://206.189.178.229.sslip.io"
    #endif

    static var serverURL: URL {
        let configuredValue = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let configuredValue,
           !configuredValue.isEmpty,
           let url = URL(string: configuredValue),
           url.scheme == "https" {
            return url
        }

        #if DEBUG
        if let configuredValue,
           let url = URL(string: configuredValue),
           url.scheme == "http",
           ["localhost", "127.0.0.1"].contains(url.host ?? "") {
            return url
        }
        #endif

        guard let fallbackURL = URL(string: defaultServerURLString) else {
            preconditionFailure("Default server URL must be valid.")
        }

        return fallbackURL
    }
}
