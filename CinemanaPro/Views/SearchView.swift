import SwiftUI
struct SearchView:View { @EnvironmentObject var env:AppEnvironment; @State private var q=""; @State private var items:[MediaItem]=[]
 var body:some View{ScrollView{LazyVGrid(columns:[GridItem(.adaptive(minimum:135))]){ForEach(items){i in NavigationLink{DetailView(item:i)}label:{PosterCard(item:i)}}}.padding()}.background(Color.black).navigationTitle("البحث").searchable(text:$q,prompt:"ابحث عن فيلم أو مسلسل").onSubmit(of:.search){Task{items=(try? await env.catalog.search(q)) ?? []}}}
}
