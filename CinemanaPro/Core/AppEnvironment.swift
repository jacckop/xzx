import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let api = APIClient()
    lazy var catalog = CatalogService(api: api)
    @Published var favorites: Set<Int> = []
}
