import SwiftUI

@main
struct PaperwallsApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra("Paperwalls", systemImage: "photo.on.rectangle.angled") {
            MenuBarView()
                .environmentObject(model)
                .task {
                    await model.refreshCatalog()
                }
        }

        WindowGroup("Paperwalls", id: "gallery") {
            GalleryView()
                .environmentObject(model)
                .task {
                    await model.refreshCatalog()
                }
        }
        .defaultSize(width: 1_080, height: 760)

        Settings {
            SettingsView()
                .environmentObject(model)
                .task {
                    await model.refreshCacheSize()
                }
        }
    }
}
