import Foundation

public struct CatalogUpdateSummary: Equatable, Sendable {
    public let newIDs: Set<String>
    public let isFirstRun: Bool
}

public actor CatalogStore {
    private let directory: URL
    private let fileManager: FileManager

    private var catalogURL: URL { directory.appendingPathComponent("catalog.json") }
    private var seenIDsURL: URL { directory.appendingPathComponent("seen-wallpapers.json") }

    public init(directory: URL, fileManager: FileManager = .default) {
        self.directory = directory
        self.fileManager = fileManager
    }

    public func cachedCatalog() throws -> PaperCatalog? {
        guard fileManager.fileExists(atPath: catalogURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: catalogURL)
        return try JSONDecoder().decode(PaperCatalog.self, from: data)
    }

    public func saveCatalog(_ catalog: PaperCatalog) throws -> CatalogUpdateSummary {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let existingSeenIDs = try loadSeenIDs()
        let isFirstRun = existingSeenIDs == nil
        let currentIDs = Set(catalog.wallpapers.map(\.id))
        let newIDs = isFirstRun ? [] : currentIDs.subtracting(existingSeenIDs ?? [])

        let catalogData = try JSONEncoder.paperwalls.encode(catalog)
        try catalogData.write(to: catalogURL, options: .atomic)

        if isFirstRun {
            try saveSeenIDs(currentIDs)
        }

        return CatalogUpdateSummary(newIDs: newIDs, isFirstRun: isFirstRun)
    }

    public func markSeen(_ wallpaperIDs: Set<String>) throws {
        let existing = try loadSeenIDs() ?? []
        try saveSeenIDs(existing.union(wallpaperIDs))
    }

    public func seenIDs() throws -> Set<String> {
        try loadSeenIDs() ?? []
    }

    private func loadSeenIDs() throws -> Set<String>? {
        guard fileManager.fileExists(atPath: seenIDsURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: seenIDsURL)
        let ids = try JSONDecoder().decode([String].self, from: data)
        return Set(ids)
    }

    private func saveSeenIDs(_ ids: Set<String>) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder.paperwalls.encode(ids.sorted())
        try data.write(to: seenIDsURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var paperwalls: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

