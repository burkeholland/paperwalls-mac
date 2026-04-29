import PaperwallsCore
import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var model: AppModel

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 16)
    ]

    var body: some View {
        NavigationSplitView {
            SidebarView()
        } detail: {
            VStack(spacing: 0) {
                if let statusMessage = model.statusMessage {
                    StatusBar(message: statusMessage, isLoading: model.isLoading)
                }

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(model.filteredWallpapers) { wallpaper in
                            WallpaperCard(wallpaper: wallpaper)
                                .environmentObject(model)
                        }
                    }
                    .padding(20)
                }
                .overlay {
                    if model.catalog == nil, model.isLoading {
                        ProgressView("Loading Paper wallpapers...")
                    } else if model.filteredWallpapers.isEmpty {
                        ContentUnavailableView("No wallpapers", systemImage: "photo", description: Text("Try a different theme or search."))
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .searchable(text: $model.searchText, prompt: "Search name, theme, or tag")
            .toolbar {
                Button {
                    Task { await model.refreshCatalog() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    Task { await model.setRandomWallpaper(scope: .all) }
                } label: {
                    Label("Random", systemImage: "shuffle")
                }
                .disabled(model.catalog == nil)
            }
            .sheet(item: $model.previewWallpaper) { wallpaper in
                WallpaperDetailView(wallpaper: wallpaper)
                    .environmentObject(model)
            }
        }
    }

    private var navigationTitle: String {
        if model.favoritesOnly {
            return "Favorites"
        }

        if let selectedThemeKey = model.selectedThemeKey,
           let theme = model.themes.first(where: { $0.key == selectedThemeKey }) {
            return theme.label
        }

        return "Paperwalls"
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        List(selection: Binding(
            get: { model.favoritesOnly ? "favorites" : model.selectedThemeKey ?? "all" },
            set: { selection in
                model.favoritesOnly = selection == "favorites"
                model.selectedThemeKey = selection == "all" || selection == "favorites" ? nil : selection
            }
        )) {
            Section("Library") {
                Label("All Wallpapers", systemImage: "photo.stack")
                    .tag("all")

                Label("Favorites", systemImage: "heart")
                    .tag("favorites")
            }

            Section("Themes") {
                ForEach(model.themes) { theme in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(theme.label)
                        Text(theme.desc)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(theme.key)
                }
            }
        }
        .navigationTitle("Paper")
    }
}

struct WallpaperCard: View {
    @EnvironmentObject private var model: AppModel
    let wallpaper: PaperWallpaper

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                AsyncImage(url: wallpaper.thumbUrl) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                if model.newWallpaperIDs.contains(wallpaper.id) {
                    Text("NEW")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange, in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                model.previewWallpaper = wallpaper
                Task { await model.markSeen(wallpaper) }
            }

            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallpaper.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(wallpaper.tags.prefix(3).joined(separator: " • "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    Task { await model.toggleFavorite(wallpaper) }
                } label: {
                    Image(systemName: model.favoriteIDs.contains(wallpaper.id) ? "heart.fill" : "heart")
                }
                .buttonStyle(.borderless)

                Button("Set") {
                    Task { await model.setWallpaper(wallpaper) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct WallpaperDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    let wallpaper: PaperWallpaper

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AsyncImage(url: wallpaper.wallpaperUrl) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                case .failure:
                    ContentUnavailableView("Could not load preview", systemImage: "exclamationmark.triangle")
                case .empty:
                    ProgressView("Loading preview...")
                        .frame(maxWidth: .infinity, minHeight: 320)
                @unknown default:
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 520)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(wallpaper.name)
                        .font(.title2.bold())
                    Text(wallpaper.tags.joined(separator: " • "))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await model.toggleFavorite(wallpaper) }
                } label: {
                    Label(model.favoriteIDs.contains(wallpaper.id) ? "Favorited" : "Favorite", systemImage: model.favoriteIDs.contains(wallpaper.id) ? "heart.fill" : "heart")
                }

                Button("Set Wallpaper") {
                    Task {
                        await model.setWallpaper(wallpaper)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(minWidth: 760, minHeight: 560)
    }
}

struct StatusBar: View {
    let message: String
    let isLoading: Bool

    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.thinMaterial)
    }
}

