import Foundation

@MainActor
final class ServerViewModel: ObservableObject {
    @Published private(set) var serverURLText = AppConfig.serverURL.absoluteString
    @Published private(set) var responseText = "Waiting for server response..."
    @Published private(set) var statusText = "Idle"
    @Published private(set) var isLoading = false

    func fetchResponse() async {
        isLoading = true
        statusText = "Loading..."

        defer {
            isLoading = false
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: AppConfig.serverURL)
            let responseBody = String(decoding: data, as: UTF8.self)

            if let httpResponse = response as? HTTPURLResponse {
                statusText = "HTTP \(httpResponse.statusCode)"
            } else {
                statusText = "Success"
            }

            responseText = responseBody.isEmpty ? "(empty response)" : responseBody
        } catch {
            statusText = "Request failed"
            responseText = error.localizedDescription
        }
    }
}
