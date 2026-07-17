import SwiftUI

struct MoreView: View {
    var body: some View {
        List {
            Section("المكتبة") {
                Label("المفضلة", systemImage: "heart")
                Label("سجل المشاهدة", systemImage: "clock")
                Label("التنزيلات", systemImage: "arrow.down.circle")
            }

            Section("الإعدادات") {
                Label("جودة التشغيل", systemImage: "gearshape")
                Label("الرقابة الأبوية", systemImage: "lock")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.black)
        .navigationTitle("المزيد")
    }
}
