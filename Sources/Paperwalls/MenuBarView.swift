import AppKit
import PaperwallsCore
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button("Open Gallery") {
            openGallery()
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

    private var favoriteWallpapers: [PaperWallpaper] {
        model.catalog?.wallpapers.filter { model.favoriteIDs.contains($0.id) } ?? []
    }

    private func openGallery() {
        openWindow(id: "gallery")

        DispatchQueue.main.async {
            model.bringGalleryToFront()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            model.bringGalleryToFront()
        }
    }
}
