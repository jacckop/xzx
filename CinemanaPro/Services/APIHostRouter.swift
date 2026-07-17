import Foundation

actor APIHostRouter {
    private var index = 0
    private let hosts = [
        URL(string: "https://cinemana.shabakaty.com")!,
        URL(string: "https://cee.buzz")!,
        URL(string: "https://cnth2.shabakaty.com")!,
        URL(string: "https://cnth2.cee.buzz")!
    ]
    func orderedHosts() -> [URL] { Array(hosts[index...] + hosts[..<index]) }
    func markWorking(_ host: URL) { if let i = hosts.firstIndex(of: host) { index = i } }
}
