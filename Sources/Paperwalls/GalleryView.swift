import PaperwallsCore
import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var model: AppModel

    private let gridHorizontalPadding: CGFloat = 20
    private let gridVerticalPadding: CGFloat = 20
    private let gridSpacing: CGFloat = 20
    private let minimumCardWidth: CGFloat = 240

    var body: some View {
        HStack(spacing: 0) {
            SidebarView()
                .frame(width: 255)

            Divider()

            VStack(spacing: 0) {
                GalleryToolbar(title: navigationTitle)
                    .environmentObject(model)

                if let selectedTheme {
                    GalleryHeader(theme: selectedTheme)
                }

                if let statusMessage = model.statusMessage {
                    StatusBar(message: statusMessage, isLoading: model.isLoading)
                }

                GeometryReader { geo in
                    ScrollView {
                        LazyVGrid(columns: computedColumns(for: geo.size.width), spacing: gridSpacing) {
                            ForEach(model.filteredWallpapers) { wallpaper in
                                WallpaperCard(wallpaper: wallpaper)
                                    .environmentObject(model)
                            }
                        }
                        .padding(.horizontal, gridHorizontalPadding)
                        .padding(.vertical, gridVerticalPadding)
                    }
                    .overlay {
                        if model.catalog == nil, model.isLoading {
                            ProgressView("Loading Paper wallpapers...")
                        } else if model.filteredWallpapers.isEmpty {
                            ContentUnavailableView("No wallpapers", systemImage: "photo", description: Text("Try a different theme or search."))
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .sheet(item: $model.previewWallpaper) { wallpaper in
            WallpaperDetailView(wallpaper: wallpaper)
                .environmentObject(model)
        }
        .background(GalleryWindowReader { window in
            model.registerGalleryWindow(window)
        })
    }

    private var selectedTheme: PaperTheme? {
        guard let selectedThemeKey = model.selectedThemeKey else {
            return nil
        }

        return model.themes.first { $0.key == selectedThemeKey }
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

    private func computedColumns(for width: CGFloat) -> [GridItem] {
        let available = max(0, width - 2 * gridHorizontalPadding)
        let count = max(1, Int((available + gridSpacing) / (minimumCardWidth + gridSpacing)))
        let columnWidth = max(1, (available - CGFloat(count - 1) * gridSpacing) / CGFloat(count))
        return Array(repeating: GridItem(.fixed(columnWidth), spacing: gridSpacing), count: count)
    }
}

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)

                TextField("Search", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .font(.title3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 18)
            .padding(.horizontal, 18)
            .padding(.bottom, 18)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SidebarSection(title: nil) {
                        SidebarRow(
                            title: "All Wallpapers",
                            systemImage: "photo.stack",
                            isSelected: !model.favoritesOnly && model.selectedThemeKey == nil
                        ) {
                            model.favoritesOnly = false
                            model.selectedThemeKey = nil
                        }

                        SidebarRow(
                            title: "Favorites",
                            systemImage: "heart",
                            isSelected: model.favoritesOnly
                        ) {
                            model.favoritesOnly = true
                            model.selectedThemeKey = nil
                        }
                    }

                    SidebarSection(title: "Themes") {
                        ForEach(model.themes) { theme in
                            SidebarRow(
                                title: theme.label,
                                systemImage: nil,
                                isSelected: !model.favoritesOnly && model.selectedThemeKey == theme.key
                            ) {
                                model.favoritesOnly = false
                                model.selectedThemeKey = theme.key
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct GalleryToolbar: View {
    @EnvironmentObject private var model: AppModel
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.title3.bold())

            Spacer()

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
        .padding(.leading, 22)
        .padding(.trailing, 18)
        .padding(.top, 18)
        .padding(.bottom, 14)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SidebarSection<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 4)
            }

            content
        }
    }
}

struct SidebarRow: View {
    private let accent = Color(red: 1.0, green: 0.18, blue: 0.28)

    let title: String
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 22)
                }

                Text(title)
                    .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? accent : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? Color.black.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct GalleryHeader: View {
    let theme: PaperTheme

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.label)
                    .font(.title3.bold())
                Text(theme.desc)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.background)
    }
}

struct GalleryWindowReader: NSViewRepresentable {
    let onWindowChange: (NSWindow?) -> Void

    func makeNSView(context: Context) -> WindowReadingView {
        let view = WindowReadingView()
        view.onWindowChange = onWindowChange
        return view
    }

    func updateNSView(_ nsView: WindowReadingView, context: Context) {
        nsView.onWindowChange = onWindowChange
        DispatchQueue.main.async {
            nsView.onWindowChange?(nsView.window)
        }
    }
}

final class WindowReadingView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}

struct WallpaperCard: View {
    @EnvironmentObject private var model: AppModel
    let wallpaper: PaperWallpaper

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Color.clear acts as a fixed-size layout anchor. AsyncImage with scaledToFill
            // reports its fill dimensions (wider than the column) up the layout tree, which
            // inflates ZStack/VStack and causes card overlap. Color.clear fills exactly
            // what is proposed, so the layout frame stays pinned to the column width × 150.
            Color.clear
                .frame(minWidth: 0, maxWidth: .infinity, minHeight: 150, maxHeight: 150)
                .overlay {
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
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                }
                .overlay(alignment: .topLeading) {
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
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct WallpaperDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    let wallpaper: PaperWallpaper

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
                .keyboardShortcut(.cancelAction)
            }

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
