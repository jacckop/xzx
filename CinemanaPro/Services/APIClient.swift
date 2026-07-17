import Foundation

struct APIHTTPError: LocalizedError {
    let statusCode: Int?
    let url: URL?
    let responsePreview: String

    var errorDescription: String? {
        if let statusCode {
            return "فشل اتصال API (HTTP \(statusCode))\n\(url?.absoluteString ?? "")"
        }
        return "تعذر الاتصال بخوادم سينمانا\n\(url?.absoluteString ?? "")"
    }
}

actor APIClient {
    private let router = APIHostRouter()
    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        configuration.httpShouldSetCookies = true
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpAdditionalHeaders = [
            "Accept": "application/json, text/plain, */*",
            "X-Requested-With": "com.shabakaty.cinemana",
            "User-Agent": "Cinemana/5.3.3 (Linux; Android 13; Pixel) AppleWebKit/537.36 okhttp/4.9.0"
        ]
        session = URLSession(configuration: configuration)
    }

    func get(path: String) async throws -> Any {
        var lastError: Error = URLError(.cannotConnectToHost)

        for host in await router.orderedCatalogHosts() {
            for url in endpointCandidates(host: host, path: path) {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
                    request.setValue("com.shabakaty.cinemana", forHTTPHeaderField: "X-Requested-With")
                    request.setValue("Cinemana/5.3.3 (Linux; Android 13; Pixel) AppleWebKit/537.36 okhttp/4.9.0", forHTTPHeaderField: "User-Agent")

                    let (data, response) = try await session.data(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw APIHTTPError(statusCode: nil, url: url, responsePreview: "")
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        let preview = String(data: data.prefix(300), encoding: .utf8) ?? ""
                        throw APIHTTPError(statusCode: http.statusCode, url: url, responsePreview: preview)
                    }

                    let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
                    await router.markWorking(host)
                    return object
                } catch {
                    lastError = error
                }
            }
        }
        throw lastError
    }

    private func endpointCandidates(host: URL, path: String) -> [URL] {
        var clean = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if clean.hasPrefix("api/android/") {
            clean.removeFirst("api/android/".count)
        }

        let variants = [
            "/api/android/\(clean)/",
            "/api/android/\(clean)",
            "/\(clean)/",
            "/\(clean)"
        ]

        var seen = Set<String>()
        return variants.compactMap { value in
            var components = URLComponents(url: host, resolvingAgainstBaseURL: false)
            components?.path = value.replacingOccurrences(of: "//", with: "/")
            guard let url = components?.url, seen.insert(url.absoluteString).inserted else { return nil }
            return url
        }
    }
}
