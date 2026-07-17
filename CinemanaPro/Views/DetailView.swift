import SwiftUI
import AVKit

struct DetailView: View {
    let item:MediaItem; @EnvironmentObject var env:AppEnvironment; @State private var details:MediaItem?; @State private var streams:[StreamSource]=[]; @State private var selected:StreamSource?
    var shown:MediaItem { details ?? item }
    var body: some View { ScrollView { VStack(alignment:.leading,spacing:16){ AsyncImage(url:shown.backdropURL ?? shown.posterURL){$0.resizable().scaledToFill()} placeholder:{Rectangle().fill(.gray.opacity(0.2))}.frame(maxWidth:.infinity).frame(height:280).clipped(); VStack(alignment:.leading,spacing:12){ Text(shown.title).font(.largeTitle.bold()); if let y=shown.year{Text(y).foregroundStyle(.secondary)}; Text(shown.overview).foregroundStyle(.secondary); Button { selected=streams.first } label:{Label("تشغيل",systemImage:"play.fill").frame(maxWidth:.infinity).padding().background(.white).foregroundStyle(.black).clipShape(RoundedRectangle(cornerRadius:12))}.disabled(streams.isEmpty) }.padding() } }.background(Color.black).navigationBarTitleDisplayMode(.inline).task { details=try? await env.catalog.details(id:item.id); streams=(try? await env.catalog.streams(id:item.id)) ?? [] }.sheet(item:$selected){ PlayerSheet(source:$0) } }
}
struct PlayerSheet:View { let source:StreamSource; var body:some View{VideoPlayer(player:AVPlayer(url:source.url)).ignoresSafeArea()} }
