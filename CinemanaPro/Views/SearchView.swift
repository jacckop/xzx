import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var env: AppEnvironment
    @State private var query = ""
    @State private var items: [MediaItem] = []
    @State private var isSearching = false

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
        .navigationTitle("البحث")
        .searchable(text: $query, prompt: "ابحث عن فيلم أو مسلسل")
        .onSubmit(of: .search) {
            performSearch()
        }
        .overlay {
            if isSearching {
                ProgressView()
            }
        }
    }

    private func performSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            items = []
            return
        }

        isSearching = true
        Task {
            items = (try? await env.catalog.search(trimmed)) ?? []
            isSearching = false
        }
    }
}
