import Foundation

actor APIClient {
    private let router = APIHostRouter()
    private let session: URLSession
    init() {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 18
        c.httpAdditionalHeaders = ["Accept":"application/json", "User-Agent":"Cinemana/5.3.3 (iOS)"]
        session = URLSession(configuration: c)
    }

    func get(path: String) async throws -> Any {
        var last: Error = URLError(.cannotConnectToHost)
        for host in await router.orderedHosts() {
            let clean = path.hasPrefix("/") ? String(path.dropFirst()) : path
            let url = host.appendingPathComponent(clean)
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw URLError(.badServerResponse) }
                let json = try JSONSerialization.jsonObject(with: data)
                await router.markWorking(host)
                return json
            } catch { last = error }
        }
        throw last
    }
}
