import AppKit
import Foundation
import PaperwallsCore

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var catalog: PaperCatalog?
    @Published private(set) var favoriteIDs: Set<String> = []
    @Published private(set) var newWallpaperIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var statusMessage: String?
    @Published var searchText = ""
    @Published var selectedThemeKey: String?
    @Published var favoritesOnly = false
    @Published var previewWallpaper: PaperWallpaper?
    @Published var rotationConfiguration = RotationConfiguration()
    @Published var currentWallpaperID: String?
    @Published private(set) var cacheSizeBytes = 0

    private let apiClient = PaperAPIClient()
    private let catalogStore: CatalogStore
    private let favoritesStore: FavoritesStore
    private let wallpaperCache: WallpaperCache
    private let wallpaperSetter: SystemDesktopWallpaperSetter
    private var rotationTask: Task<Void, Never>?

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("Paperwalls", isDirectory: true)

        catalogStore = CatalogStore(directory: appSupport.appendingPathComponent("Catalog", isDirectory: true))
        favoritesStore = FavoritesStore(directory: appSupport.appendingPathComponent("User", isDirectory: true))
        wallpaperCache = WallpaperCache(directory: appSupport.appendingPathComponent("WallpaperCache", isDirectory: true))
        wallpaperSetter = SystemDesktopWallpaperSetter()
        rotationConfiguration = Self.loadRotationConfiguration()
    }

    var themes: [PaperTheme] {
        catalog?.themes ?? []
    }

    var filteredWallpapers: [PaperWallpaper] {
        guard let catalog else {
            return []
        }

        return CatalogSearch.filter(
            catalog,
            using: CatalogFilter(
                searchText: searchText,
                themeKey: selectedThemeKey,
                favoriteIDs: favoriteIDs,
                favoritesOnly: favoritesOnly
            )
        )
    }

    func refreshCatalog() async {
        guard !isLoading else {
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            favoriteIDs = try await favoritesStore.allFavorites()
            let freshCatalog = try await apiClient.fetchCatalog()
            let update = try await catalogStore.saveCatalog(freshCatalog)
            catalog = freshCatalog
            newWallpaperIDs = update.newIDs
            statusMessage = "Loaded \(freshCatalog.wallpapers.count) wallpapers"
        } catch {
            do {
                if let cachedCatalog = try await catalogStore.cachedCatalog() {
                    catalog = cachedCatalog
                    favoriteIDs = try await favoritesStore.allFavorites()
                    statusMessage = "Showing cached wallpapers. Refresh failed: \(error.localizedDescription)"
                } else {
                    statusMessage = "Could not load wallpapers: \(error.localizedDescription)"
                }
            } catch {
                statusMessage = "Could not load wallpapers: \(error.localizedDescription)"
            }
        }

        await refreshCacheSize()
        updateRotationTask()
    }

    func setWallpaper(_ wallpaper: PaperWallpaper) async {
        do {
            let fileURL = try await wallpaperCache.cachedFileURL(for: wallpaper)
            try wallpaperSetter.apply(fileURL)
            currentWallpaperID = wallpaper.id
            try await catalogStore.markSeen([wallpaper.id])
            newWallpaperIDs.remove(wallpaper.id)
            statusMessage = "Set \(wallpaper.name)"
            await refreshCacheSize()
        } catch {
            statusMessage = "Could not set \(wallpaper.name): \(error.localizedDescription)"
        }
    }

    func toggleFavorite(_ wallpaper: PaperWallpaper) async {
        do {
            favoriteIDs = try await favoritesStore.toggle(wallpaper.id)
        } catch {
            statusMessage = "Could not update favorites: \(error.localizedDescription)"
        }
    }

    func markSeen(_ wallpaper: PaperWallpaper) async {
        guard newWallpaperIDs.contains(wallpaper.id) else {
            return
        }

        do {
            try await catalogStore.markSeen([wallpaper.id])
            newWallpaperIDs.remove(wallpaper.id)
        } catch {
            statusMessage = "Could not update seen status: \(error.localizedDescription)"
        }
    }

    func setRandomWallpaper(scope: RotationScope = .all) async {
        guard let wallpaper = randomWallpaper(scope: scope) else {
            statusMessage = "No wallpapers available for that selection"
            return
        }

        await setWallpaper(wallpaper)
    }

    func saveRotationConfiguration() {
        rotationConfiguration.intervalSeconds = RotationEngine.normalizedInterval(rotationConfiguration.intervalSeconds)
        if let data = try? JSONEncoder().encode(rotationConfiguration) {
            UserDefaults.standard.set(data, forKey: "rotationConfiguration")
        }
        updateRotationTask()
    }

    func clearCache() async {
        do {
            try await wallpaperCache.clear()
            await refreshCacheSize()
            statusMessage = "Cleared wallpaper cache"
        } catch {
            statusMessage = "Could not clear cache: \(error.localizedDescription)"
        }
    }

    func refreshCacheSize() async {
        do {
            cacheSizeBytes = try await wallpaperCache.totalBytes()
        } catch {
            cacheSizeBytes = 0
        }
    }

    private func updateRotationTask() {
        rotationTask?.cancel()
        rotationTask = nil

        guard rotationConfiguration.isEnabled else {
            return
        }

        let interval = RotationEngine.normalizedInterval(rotationConfiguration.intervalSeconds)
        let scope = rotationConfiguration.scope

        rotationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else {
                    return
                }
                await self?.rotateOnce(scope: scope)
            }
        }
    }

    private func rotateOnce(scope: RotationScope) async {
        guard let catalog else {
            return
        }

        guard let next = RotationEngine.nextWallpaper(in: catalog, scope: scope, currentID: currentWallpaperID) else {
            statusMessage = "No wallpapers available for rotation"
            return
        }

        await setWallpaper(next)
    }

    private func randomWallpaper(scope: RotationScope) -> PaperWallpaper? {
        guard let catalog else {
            return nil
        }

        return RotationEngine.eligibleWallpapers(in: catalog, scope: scope).randomElement()
    }

    private static func loadRotationConfiguration() -> RotationConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "rotationConfiguration"),
              let configuration = try? JSONDecoder().decode(RotationConfiguration.self, from: data)
        else {
            return RotationConfiguration()
        }

        return configuration
    }
}

