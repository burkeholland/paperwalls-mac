import Foundation

public actor FavoritesStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(directory: URL, fileManager: FileManager = .default) {
        self.fileURL = directory.appendingPathComponent("favorites.json")
        self.fileManager = fileManager
    }

    public func allFavorites() throws -> Set<String> {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return Set(try JSONDecoder().decode([String].self, from: data))
    }

    @discardableResult
    public func toggle(_ wallpaperID: String) throws -> Set<String> {
        var favorites = try allFavorites()

        if favorites.contains(wallpaperID) {
            favorites.remove(wallpaperID)
        } else {
            favorites.insert(wallpaperID)
        }

        try save(favorites)
        return favorites
    }

    public func contains(_ wallpaperID: String) throws -> Bool {
        try allFavorites().contains(wallpaperID)
    }

    private func save(_ favorites: Set<String>) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(favorites.sorted())
        try data.write(to: fileURL, options: .atomic)
    }
}

