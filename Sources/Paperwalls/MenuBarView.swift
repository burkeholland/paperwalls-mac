import PaperwallsCore
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Paperwalls")
                    .font(.headline)
                Spacer()
                if model.isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Divider()

            Button("Open Gallery") {
                openWindow(id: "gallery")
            }
            .keyboardShortcut("o")

            Button("Set Random Wallpaper") {
                Task { await model.setRandomWallpaper(scope: .all) }
            }
            .disabled(model.catalog == nil)

            Menu("Random From Theme") {
                ForEach(model.themes) { theme in
                    Button(theme.label) {
                        Task { await model.setRandomWallpaper(scope: .theme(theme.key)) }
                    }
                }
            }
            .disabled(model.themes.isEmpty)

            if !model.favoriteIDs.isEmpty {
                Menu("Favorites") {
                    ForEach(favoriteWallpapers.prefix(10)) { wallpaper in
                        Button(wallpaper.name) {
                            Task { await model.setWallpaper(wallpaper) }
                        }
                    }
                }
            }

            Divider()

            Toggle("Rotate Automatically", isOn: Binding(
                get: { model.rotationConfiguration.isEnabled },
                set: {
                    model.rotationConfiguration.isEnabled = $0
                    model.saveRotationConfiguration()
                }
            ))

            Button("Refresh Catalog") {
                Task { await model.refreshCatalog() }
            }

            Button("Quit Paperwalls") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 280)
    }

    private var favoriteWallpapers: [PaperWallpaper] {
        model.catalog?.wallpapers.filter { model.favoriteIDs.contains($0.id) } ?? []
    }
}

