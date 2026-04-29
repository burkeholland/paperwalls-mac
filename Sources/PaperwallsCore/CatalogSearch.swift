import Foundation

public struct CatalogFilter: Equatable, Sendable {
    public var searchText: String
    public var themeKey: String?
    public var favoriteIDs: Set<String>
    public var favoritesOnly: Bool

    public init(
        searchText: String = "",
        themeKey: String? = nil,
        favoriteIDs: Set<String> = [],
        favoritesOnly: Bool = false
    ) {
        self.searchText = searchText
        self.themeKey = themeKey
        self.favoriteIDs = favoriteIDs
        self.favoritesOnly = favoritesOnly
    }
}

public enum CatalogSearch {
    public static func filter(_ catalog: PaperCatalog, using filter: CatalogFilter) -> [PaperWallpaper] {
        let query = filter.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let themeLabelsByKey = Dictionary(uniqueKeysWithValues: catalog.themes.map { ($0.key, $0.label.lowercased()) })

        return catalog.wallpapers.filter { wallpaper in
            if let themeKey = filter.themeKey, wallpaper.theme != themeKey {
                return false
            }

            if filter.favoritesOnly, !filter.favoriteIDs.contains(wallpaper.id) {
                return false
            }

            guard !query.isEmpty else {
                return true
            }

            let searchableValues = [
                wallpaper.name.lowercased(),
                wallpaper.theme.lowercased(),
                themeLabelsByKey[wallpaper.theme] ?? "",
                wallpaper.tags.joined(separator: " ").lowercased()
            ]

            return searchableValues.contains { $0.contains(query) }
        }
    }
}

