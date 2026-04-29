import Foundation
import PaperwallsCore

@main
struct PaperwallsChecks {
    static func main() async throws {
        try await testAPIClientDecodesValidCatalog()
        try await testAPIClientRejectsEmptyCatalog()
        try testSearchMatchesNameThemeLabelAndTags()
        try testSearchFiltersThemeAndFavorites()
        try await testCatalogStoreDoesNotMarkEverythingNewOnFirstRun()
        try await testCatalogStoreReportsNewIDsOnSubsequentUpdates()
        try await testFavoritesStoreTogglesAndPersistsIDs()
        try await testWallpaperCacheDownloadsOnceAndClears()
        try testRotationEngineSelectsNextWallpaperWithinScope()
        testRotationIntervalIsClampedToMinimum()

        print("All Paperwalls checks passed")
    }

    private static func testAPIClientDecodesValidCatalog() async throws {
        let client = PaperAPIClient(fetchData: { _ in try fixtureData })
        let catalog = try await client.fetchCatalog()

        expect(catalog.themes.count == 2)
        expect(catalog.wallpapers.count == 3)
        expect(catalog.wallpapers.first?.id == "moonlit-barn")
    }

    private static func testAPIClientRejectsEmptyCatalog() async throws {
        let empty = PaperCatalog(
            name: "paper",
            description: "empty",
            baseUrl: URL(string: "https://example.com")!,
            wallpapersPath: "/wallpapers/",
            thumbsPath: "/thumbs/",
            themes: [],
            wallpapers: []
        )
        let data = try JSONEncoder().encode(empty)
        let client = PaperAPIClient(fetchData: { _ in data })

        do {
            _ = try await client.fetchCatalog()
            throw CheckFailure("Expected empty catalog to throw")
        } catch PaperAPIError.emptyCatalog {
            return
        }
    }

    private static func testSearchMatchesNameThemeLabelAndTags() throws {
        let catalog = fixtureCatalog()

        expect(CatalogSearch.filter(catalog, using: CatalogFilter(searchText: "barn")).map(\.id) == ["moonlit-barn"])
        expect(CatalogSearch.filter(catalog, using: CatalogFilter(searchText: "Coastal")).map(\.id) == ["blue-harbor"])
        expect(CatalogSearch.filter(catalog, using: CatalogFilter(searchText: "stars")).map(\.id) == ["moonlit-barn", "starry-pasture"])
    }

    private static func testSearchFiltersThemeAndFavorites() throws {
        let catalog = fixtureCatalog()
        let result = CatalogSearch.filter(
            catalog,
            using: CatalogFilter(themeKey: "farm", favoriteIDs: ["starry-pasture"], favoritesOnly: true)
        )

        expect(result.map(\.id) == ["starry-pasture"])
    }

    private static func testCatalogStoreDoesNotMarkEverythingNewOnFirstRun() async throws {
        let store = CatalogStore(directory: try temporaryDirectory())
        let firstCatalog = fixtureCatalog()

        let firstUpdate = try await store.saveCatalog(firstCatalog)
        let seenIDs = try await store.seenIDs()

        expect(firstUpdate.isFirstRun)
        expect(firstUpdate.newIDs == [])
        expect(seenIDs == Set(firstCatalog.wallpapers.map(\.id)))
    }

    private static func testCatalogStoreReportsNewIDsOnSubsequentUpdates() async throws {
        let store = CatalogStore(directory: try temporaryDirectory())
        let firstCatalog = PaperCatalog(
            name: "paper",
            description: "fixture",
            baseUrl: URL(string: "https://example.com")!,
            wallpapersPath: "/wallpapers/",
            thumbsPath: "/thumbs/",
            themes: [farmTheme],
            wallpapers: [moonlitBarn]
        )
        let secondCatalog = fixtureCatalog()

        _ = try await store.saveCatalog(firstCatalog)
        let update = try await store.saveCatalog(secondCatalog)

        expect(update.newIDs == ["starry-pasture", "blue-harbor"])
    }

    private static func testFavoritesStoreTogglesAndPersistsIDs() async throws {
        let directory = try temporaryDirectory()
        let store = FavoritesStore(directory: directory)

        let afterAdding = try await store.toggle("moonlit-barn")
        let containsFavorite = try await store.contains("moonlit-barn")
        let afterRemoving = try await store.toggle("moonlit-barn")

        let secondStore = FavoritesStore(directory: directory)
        let persistedFavorites = try await secondStore.allFavorites()

        expect(afterAdding == ["moonlit-barn"])
        expect(containsFavorite)
        expect(afterRemoving == [])
        expect(persistedFavorites == [])
    }

    private static func testWallpaperCacheDownloadsOnceAndClears() async throws {
        let directory = try temporaryDirectory()
        let counter = DownloadCounter()
        let cache = WallpaperCache(directory: directory, downloadData: { _ in
            await counter.increment()
            return Data("image".utf8)
        })

        let firstURL = try await cache.cachedFileURL(for: moonlitBarn)
        let secondURL = try await cache.cachedFileURL(for: moonlitBarn)
        let downloadCount = await counter.currentValue()
        let sizeBeforeClear = try await cache.totalBytes()

        expect(firstURL == secondURL)
        expect(downloadCount == 1)
        expect(sizeBeforeClear > 0)

        try await cache.clear()
        let sizeAfterClear = try await cache.totalBytes()
        expect(sizeAfterClear == 0)
    }

    private static func testRotationEngineSelectsNextWallpaperWithinScope() throws {
        let catalog = fixtureCatalog()

        expect(RotationEngine.nextWallpaper(in: catalog, scope: .all, currentID: nil)?.id == "moonlit-barn")
        expect(RotationEngine.nextWallpaper(in: catalog, scope: .all, currentID: "moonlit-barn")?.id == "starry-pasture")
        expect(RotationEngine.nextWallpaper(in: catalog, scope: .theme("coastal"), currentID: nil)?.id == "blue-harbor")
        expect(RotationEngine.nextWallpaper(in: catalog, scope: .theme("missing"), currentID: nil) == nil)
    }

    private static func testRotationIntervalIsClampedToMinimum() {
        expect(RotationEngine.normalizedInterval(10) == RotationEngine.minimumInterval)
        expect(RotationEngine.normalizedInterval(900) == 900)
    }

    private static let farmTheme = PaperTheme(key: "farm", label: "Farm", desc: "Nighttime pastoral scenes")

    private static let moonlitBarn = PaperWallpaper(
        id: "moonlit-barn",
        name: "Moonlit Barn",
        theme: "farm",
        tags: ["night", "barn", "stars"],
        file: "farm/moonlit-barn.jpg",
        wallpaperUrl: URL(string: "https://example.com/wallpapers/farm/moonlit-barn.jpg")!,
        thumbUrl: URL(string: "https://example.com/thumbs/farm/moonlit-barn.jpg")!
    )

    private static var fixtureData: Data {
        get throws {
            try JSONEncoder().encode(fixtureCatalog())
        }
    }

    private static func fixtureCatalog() -> PaperCatalog {
        PaperCatalog(
            name: "paper",
            description: "fixture",
            baseUrl: URL(string: "https://example.com")!,
            wallpapersPath: "/wallpapers/",
            thumbsPath: "/thumbs/",
            themes: [
                farmTheme,
                PaperTheme(key: "coastal", label: "Coastal", desc: "Sea, cliffs & shore")
            ],
            wallpapers: [
                moonlitBarn,
                PaperWallpaper(
                    id: "starry-pasture",
                    name: "Starry Pasture",
                    theme: "farm",
                    tags: ["night", "pasture", "stars"],
                    file: "farm/starry-pasture.jpg",
                    wallpaperUrl: URL(string: "https://example.com/wallpapers/farm/starry-pasture.jpg")!,
                    thumbUrl: URL(string: "https://example.com/thumbs/farm/starry-pasture.jpg")!
                ),
                PaperWallpaper(
                    id: "blue-harbor",
                    name: "Blue Harbor",
                    theme: "coastal",
                    tags: ["water", "boats"],
                    file: "coastal/blue-harbor.jpg",
                    wallpaperUrl: URL(string: "https://example.com/wallpapers/coastal/blue-harbor.jpg")!,
                    thumbUrl: URL(string: "https://example.com/thumbs/coastal/blue-harbor.jpg")!
                )
            ]
        )
    }

    private static func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PaperwallsChecks-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String = "Expectation failed") {
        guard condition() else {
            fatalError(message)
        }
    }
}

private struct CheckFailure: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

private actor DownloadCounter {
    private var value = 0

    func increment() {
        value += 1
    }

    func currentValue() -> Int {
        value
    }
}
