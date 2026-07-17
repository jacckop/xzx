import SwiftUI

@MainActor
final class HomeVM: ObservableObject {
    @Published var movies: [MediaItem] = []
    @Published var series: [MediaItem] = []
    @Published var loading = false
    @Published var error: String?

    func load(_ service: CatalogService) async {
        loading = true
        error = nil
        defer { loading = false }

        do {
            async let movieRequest = service.latestMovies()
            async let seriesRequest = service.latestSeries()
            let result = try await (movieRequest, seriesRequest)
            movies = result.0
            series = result.1

            if movies.isEmpty && series.isEmpty {
                error = "اتصل الخادم، لكن لم تُقرأ النتائج. قد تكون صيغة API قد تغيّرت أو الخدمة غير متاحة على هذه الشبكة."
            }
        } catch {
            error = error.localizedDescription
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var env: AppEnvironment
    @StateObject private var vm = HomeVM()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("سينمانا برو")
                        .font(.largeTitle.bold())
                        .padding(.horizontal)

                    if !vm.movies.isEmpty {
                        SectionRow(title: "أحدث الأفلام", items: vm.movies)
                    }
                    if !vm.series.isEmpty {
                        SectionRow(title: "أحدث المسلسلات", items: vm.series)
                    }

                    if let error = vm.error {
                        VStack(spacing: 14) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 34))
                            Text(error)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                            Button("إعادة المحاولة") {
                                Task { await vm.load(env.catalog) }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                    }
                }
            }

            if vm.loading { ProgressView().controlSize(.large) }
        }
        .task {
            if vm.movies.isEmpty && vm.series.isEmpty {
                await vm.load(env.catalog)
            }
        }
    }
}

struct SectionRow: View {
    let title: String
    let items: [MediaItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title2.bold()).padding(.horizontal)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(items) { item in
                        NavigationLink(value: item) { PosterCard(item: item) }
                    }
                }
                .padding(.horizontal)
            }
        }
        .navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
    }
}

struct PosterCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            AsyncImage(url: item.posterURL) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                default:
                    Rectangle().fill(.gray.opacity(0.2)).overlay(Image(systemName: "film"))
                }
            }
            .frame(width: 135, height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(item.title)
                .font(.caption.bold())
                .lineLimit(2)
                .frame(width: 135, alignment: .leading)
        }
        .foregroundStyle(.white)
    }
}
