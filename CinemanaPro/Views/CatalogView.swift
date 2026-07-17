import SwiftUI

enum CatalogKind {
    case movies
    case series
}

struct CatalogView: View {
    let kind: CatalogKind

    @EnvironmentObject private var env: AppEnvironment
    @State private var items: [MediaItem] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 135), spacing: 14)],
                spacing: 18
            ) {
                ForEach(items) { item in
                    NavigationLink {
                        DetailView(item: item)
                    } label: {
                        PosterCard(item: item)
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
        .navigationTitle(kind == .movies ? "الأفلام" : "المسلسلات")
        .task {
            guard items.isEmpty else {
                isLoading = false
                return
            }

            switch kind {
            case .movies:
                items = (try? await env.catalog.latestMovies()) ?? []
            case .series:
                items = (try? await env.catalog.latestSeries()) ?? []
            }
            isLoading = false
        }
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }
}
