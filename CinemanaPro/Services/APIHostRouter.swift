import Foundation

actor APIHostRouter {
    private var preferredIndex = 0

    private let catalogHosts: [URL] = [
        URL(string: "https://cinemana.shabakaty.com")!,
        URL(string: "https://cee.buzz")!
    ]

    func orderedCatalogHosts() -> [URL] {
        guard !catalogHosts.isEmpty else { return [] }
        return Array(catalogHosts[preferredIndex...] + catalogHosts[..<preferredIndex])
    }

    func markWorking(_ host: URL) {
        if let index = catalogHosts.firstIndex(of: host) {
            preferredIndex = index
        }
    }
}
