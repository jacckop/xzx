import Foundation

struct CatalogService {
    let api: APIClient

    func latestMovies(page: Int = 0) async throws -> [MediaItem] {
        try await load("latestMovies/level/0/itemsPerPage/30/page/\(page)")
    }

    func latestSeries(page: Int = 0) async throws -> [MediaItem] {
        try await load("latestSeries/level/0/itemsPerPage/30/page/\(page)")
    }

    func category(id: Int, page: Int = 0) async throws -> [MediaItem] {
        let candidates = [
            "videosByCategory/id/\(id)/level/0/itemsPerPage/30/page/\(page)",
            "videosByCategory/\(id)/level/0/itemsPerPage/30/page/\(page)",
            "videoListPagination/groupID/\(id)/level/0/itemsPerPage/30/page/\(page)"
        ]
        return try await firstNonEmpty(candidates)
    }

    func details(id: Int) async throws -> MediaItem {
        let json = try await api.get(path: "allVideoInfo/id/\(id)")
        return JSONAdapter.items(from: json).first ?? MediaItem(id: id, title: "Video \(id)")
    }

    func streams(id: Int) async throws -> [StreamSource] {
        let json = try await api.get(path: "transcoddedFiles/id/\(id)")
        return JSONAdapter.streams(from: json)
    }

    func search(_ query: String) async throws -> [MediaItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        return try await firstNonEmpty([
            "search/name/\(encoded)",
            "search/\(encoded)",
            "video/V/2/itemsPerPage/30/page/0/search/\(encoded)"
        ])
    }

    private func firstNonEmpty(_ paths: [String]) async throws -> [MediaItem] {
        var lastError: Error?
        for path in paths {
            do {
                let items = try await load(path)
                if !items.isEmpty { return items }
            } catch {
                lastError = error
            }
        }
        if let lastError { throw lastError }
        return []
    }

    private func load(_ path: String) async throws -> [MediaItem] {
        JSONAdapter.items(from: try await api.get(path: path))
    }
}

enum JSONAdapter {
    private static let imageBases = [
        URL(string: "https://cdn.shabakaty.com")!,
        URL(string: "https://cdn.cee.buzz")!,
        URL(string: "https://cnth2.shabakaty.com")!,
        URL(string: "https://cnth2.cee.buzz")!
    ]

    static func items(from object: Any) -> [MediaItem] {
        allDictionaries(in: object).compactMap { dictionary in
            guard let id = integer(firstValue(in: dictionary, keys: [
                "id", "videoId", "video_id", "videoID", "objectId"
            ])) else { return nil }

            let ArabicTitle = string(firstValue(in: dictionary, keys: ["ar_title", "arTitle"]))
            let EnglishTitle = string(firstValue(in: dictionary, keys: ["en_title", "enTitle"]))
            let genericTitle = string(firstValue(in: dictionary, keys: ["title", "name", "other_title"]))
            let title = nonEmpty(ArabicTitle) ?? nonEmpty(EnglishTitle) ?? nonEmpty(genericTitle) ?? "بدون عنوان"

            let poster = mediaURL(firstValue(in: dictionary, keys: [
                "imgObjUrl", "imgMediumThumbObjUrl", "imgThumbObjUrl", "imgMediumThumb",
                "imgThumb", "poster", "posterUrl", "posterURL", "image", "img"
            ]))
            let backdrop = mediaURL(firstValue(in: dictionary, keys: [
                "backdrop", "backdropURL", "cover", "background", "imgObjUrl"
            ]))

            let overview = nonEmpty(string(firstValue(in: dictionary, keys: [
                "ar_content", "en_content", "content", "description", "overview", "story"
            ]))) ?? ""

            return MediaItem(
                id: id,
                title: title,
                posterURL: poster,
                backdropURL: backdrop,
                overview: overview,
                year: string(firstValue(in: dictionary, keys: ["year", "releaseYear", "videoUploadDate"])),
                rating: number(firstValue(in: dictionary, keys: ["rating", "rate", "filmRating", "seriesRating", "stars"])),
                type: string(firstValue(in: dictionary, keys: ["kind", "type", "videoType"]))
            )
        }.uniqued()
    }

    static func streams(from object: Any) -> [StreamSource] {
        allDictionaries(in: object).compactMap { dictionary in
            guard let url = mediaURL(firstValue(in: dictionary, keys: [
                "file", "url", "link", "videoUrl", "transcoddedFileName"
            ])) else { return nil }
            let quality = nonEmpty(string(firstValue(in: dictionary, keys: [
                "quality", "resolution", "type", "extention"
            ]))) ?? "Auto"
            return StreamSource(quality: quality, url: url)
        }.uniquedByURL()
    }

    private static func allDictionaries(in value: Any) -> [[String: Any]] {
        if let dictionary = value as? [String: Any] {
            var result = [dictionary]
            for nestedValue in dictionary.values {
                result.append(contentsOf: allDictionaries(in: nestedValue))
            }
            return result
        }
        if let array = value as? [Any] {
            return array.flatMap { allDictionaries(in: $0) }
        }
        return []
    }

    private static func firstValue(in dictionary: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dictionary[key], !(value is NSNull) { return value }
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        if let value = value as? String { return value.trimmingCharacters(in: .whitespacesAndNewlines) }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func number(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }

    private static func mediaURL(_ value: Any?) -> URL? {
        guard var text = string(value), !text.isEmpty else { return nil }
        text = text.replacingOccurrences(of: "\\/", with: "/")
        if text.hasPrefix("//") { return URL(string: "https:" + text) }
        if let absolute = URL(string: text), absolute.scheme != nil { return absolute }

        let clean = text.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        for base in imageBases {
            if let candidate = URL(string: base.absoluteString + "/" + clean) { return candidate }
        }
        return nil
    }
}

private extension Array where Element == MediaItem {
    func uniqued() -> [MediaItem] {
        var ids = Set<Int>()
        return filter { ids.insert($0.id).inserted }
    }
}

private extension Array where Element == StreamSource {
    func uniquedByURL() -> [StreamSource] {
        var urls = Set<URL>()
        return filter { urls.insert($0.url).inserted }
    }
}
