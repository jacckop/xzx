import SwiftUI

enum CatalogKind { case movies, series }
struct CatalogView: View {
    let kind:CatalogKind; @EnvironmentObject var env:AppEnvironment; @State private var items:[MediaItem]=[]; @State private var loading=true
    var body: some View { ScrollView { LazyVGrid(columns:[GridItem(.adaptive(minimum:135),spacing:14)],spacing:18){ ForEach(items){ item in NavigationLink{DetailView(item:item)} label:{PosterCard(item:item)} } }.padding() }.background(Color.black).navigationTitle(kind == .movies ? "الأفلام" : "المسلسلات").task { guard items.isEmpty else{return}; items=(try? await (kind == .movies ? env.catalog.latestMovies() : env.catalog.latestSeries())) ?? []; loading=false }.overlay{if loading{ProgressView()}} }
}
