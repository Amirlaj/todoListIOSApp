import SwiftUI

struct AppRootView: View {
    var body: some View {
        TabView {
            ModuleListView()
                .tabItem { Label("Library", systemImage: "rectangle.stack") }
            ReviewLibraryView()
                .tabItem { Label("Review", systemImage: "rectangle.on.rectangle.angled") }
            StatisticsView()
                .tabItem { Label("Statistics", systemImage: "chart.bar") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#if DEBUG
#Preview("Flashies") {
    let data = PreviewData()
    return AppRootView().modelContainer(data.container)
}
#endif
