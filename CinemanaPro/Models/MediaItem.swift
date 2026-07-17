import Foundation

struct MediaItem: Identifiable, Hashable, Codable {
    let id: Int
    var title: String
    var posterURL: URL?
    var backdropURL: URL?
    var overview: String
    var year: String?
    var rating: Double?
    var type: String?

    init(id: Int, title: String, posterURL: URL? = nil, backdropURL: URL? = nil, overview: String = "", year: String? = nil, rating: Double? = nil, type: String? = nil) {
        self.id=id; self.title=title; self.posterURL=posterURL; self.backdropURL=backdropURL; self.overview=overview; self.year=year; self.rating=rating; self.type=type
    }
}

struct StreamSource: Identifiable, Hashable {
    let id = UUID()
    let quality: String
    let url: URL
}
