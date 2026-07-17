import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }.tabItem { Label("الرئيسية", systemImage: "house.fill") }
            NavigationStack { CatalogView(kind: .movies) }.tabItem { Label("الأفلام", systemImage: "film.fill") }
            NavigationStack { CatalogView(kind: .series) }.tabItem { Label("المسلسلات", systemImage: "tv.fill") }
            NavigationStack { SearchView() }.tabItem { Label("البحث", systemImage: "magnifyingglass") }
            NavigationStack { MoreView() }.tabItem { Label("المزيد", systemImage: "ellipsis") }
        }.tint(.white)
    }
}
