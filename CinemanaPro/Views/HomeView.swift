import SwiftUI

@MainActor final class HomeVM: ObservableObject {
    @Published var movies:[MediaItem]=[]; @Published var series:[MediaItem]=[]; @Published var loading=false; @Published var error:String?
    func load(_ service: CatalogService) async { loading=true; defer{loading=false}; do { async let m=service.latestMovies(); async let s=service.latestSeries(); (movies,series)=try await(m,s) } catch { self.error=error.localizedDescription } }
}
struct HomeView: View {
    @EnvironmentObject var env: AppEnvironment
    @StateObject private var vm=HomeVM()
    var body: some View {
        ZStack { Color.black.ignoresSafeArea(); ScrollView { VStack(alignment:.leading,spacing:24) {
            Text("سينمانا برو").font(.largeTitle.bold()).padding(.horizontal)
            SectionRow(title:"أحدث الأفلام",items:vm.movies)
            SectionRow(title:"أحدث المسلسلات",items:vm.series)
            if let e=vm.error { Text(e).foregroundStyle(.secondary).padding() }
        }}; if vm.loading { ProgressView() } }
        .task { if vm.movies.isEmpty { await vm.load(env.catalog) } }
    }
}
struct SectionRow: View { let title:String; let items:[MediaItem]
    var body: some View { VStack(alignment:.leading,spacing:12){ Text(title).font(.title2.bold()).padding(.horizontal); ScrollView(.horizontal,showsIndicators:false){ LazyHStack(spacing:12){ ForEach(items){ item in NavigationLink(value:item){ PosterCard(item:item) } }.navigationDestination(for:MediaItem.self){ DetailView(item:$0) } }.padding(.horizontal) } } }
}
struct PosterCard: View { let item:MediaItem
    var body: some View { VStack(alignment:.leading,spacing:7){ AsyncImage(url:item.posterURL){ p in p.resizable().scaledToFill() } placeholder:{ Rectangle().fill(.gray.opacity(0.2)).overlay(Image(systemName:"film")) }.frame(width:135,height:200).clipShape(RoundedRectangle(cornerRadius:12)); Text(item.title).font(.caption.bold()).lineLimit(2).frame(width:135,alignment:.leading) }.foregroundStyle(.white) }
}
