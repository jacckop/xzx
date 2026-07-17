import Foundation

struct CatalogService {
    let api: APIClient

    func latestMovies(page: Int = 0) async throws -> [MediaItem] {
        try await load("api/android/latestMovies/level/0/itemsPerPage/30/page/\(page)/")
    }
    func latestSeries(page: Int = 0) async throws -> [MediaItem] {
        try await load("api/android/latestSeries/level/0/itemsPerPage/30/page/\(page)/")
    }
    func category(id: Int, page: Int = 0) async throws -> [MediaItem] {
        try await load("api/android/videosByCategory/id/\(id)/level/0/itemsPerPage/30/page/\(page)/")
    }
    func details(id: Int) async throws -> MediaItem {
        let json = try await api.get(path: "api/android/allVideoInfo/id/\(id)/")
        return JSONAdapter.items(from: json).first ?? MediaItem(id: id, title: "Video \(id)")
    }
    func streams(id: Int) async throws -> [StreamSource] {
        let json = try await api.get(path: "api/android/transcoddedFiles/id/\(id)/")
        return JSONAdapter.streams(from: json)
    }
    func search(_ query: String) async throws -> [MediaItem] {
        let q = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
        let candidates = ["api/android/search/name/\(q)/", "api/android/search/\(q)/"]
        for p in candidates { if let x = try? await load(p), !x.isEmpty { return x } }
        return []
    }
    private func load(_ path: String) async throws -> [MediaItem] { JSONAdapter.items(from: try await api.get(path: path)) }
}

enum JSONAdapter {
    static func items(from object: Any) -> [MediaItem] {
        let dictionaries = flatten(object)
        return dictionaries.compactMap { d in
            guard let id = int(d["id"] ?? d["videoId"] ?? d["video_id"]) else { return nil }
            let title = str(d["title"] ?? d["name"] ?? d["enTitle"] ?? d["arTitle"]) ?? "بدون عنوان"
            let poster = url(d["poster"] ?? d["posterUrl"] ?? d["image"] ?? d["img"])
            let backdrop = url(d["backdrop"] ?? d["cover"] ?? d["background"])
            return MediaItem(id: id, title: title, posterURL: poster, backdropURL: backdrop,
                             overview: str(d["description"] ?? d["overview"] ?? d["story"]) ?? "",
                             year: str(d["year"] ?? d["releaseYear"]), rating: double(d["rating"] ?? d["rate"]),
                             type: str(d["type"] ?? d["kind"]))
        }.uniqued()
    }
    static func streams(from object: Any) -> [StreamSource] {
        flatten(object).compactMap { d in
            guard let u = url(d["url"] ?? d["file"] ?? d["link"] ?? d["videoUrl"]) else { return nil }
            return StreamSource(quality: str(d["quality"] ?? d["resolution"]) ?? "Auto", url: u)
        }
    }
    private static func flatten(_ value: Any) -> [[String:Any]] {
        if let a = value as? [[String:Any]] { return a }
        if let d = value as? [String:Any] {
            var out:[ [String:Any] ] = []
            for key in ["data","result","results","items","videos","movies","series"] {
                if let v=d[key] { out += flatten(v) }
            }
            if out.isEmpty, d["id"] != nil { out=[d] }
            return out
        }
        if let a=value as? [Any] { return a.flatMap(flatten) }
        return []
    }
    private static func str(_ v: Any?) -> String? { if let s=v as? String{return s}; if let n=v as? NSNumber{return n.stringValue}; return nil }
    private static func int(_ v: Any?) -> Int? { if let i=v as? Int{return i}; if let n=v as? NSNumber{return n.intValue}; if let s=v as? String{return Int(s)}; return nil }
    private static func double(_ v: Any?) -> Double? { if let d=v as? Double{return d}; if let n=v as? NSNumber{return n.doubleValue}; if let s=v as? String{return Double(s)}; return nil }
    private static func url(_ v: Any?) -> URL? { guard let s=str(v), !s.isEmpty else{return nil}; if s.hasPrefix("//"){return URL(string:"https:"+s)}; return URL(string:s) }
}
private extension Array where Element == MediaItem { func uniqued()->[MediaItem]{ var s=Set<Int>(); return filter{s.insert($0.id).inserted} } }
