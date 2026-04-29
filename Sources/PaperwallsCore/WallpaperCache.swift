import Foundation

public actor WallpaperCache {
    private let directory: URL
    private let maxBytes: Int
    private let fileManager: FileManager
    private let downloadData: @Sendable (URL) async throws -> Data

    public init(
        directory: URL,
        maxBytes: Int = 750 * 1_024 * 1_024,
        fileManager: FileManager = .default,
        downloadData: @escaping @Sendable (URL) async throws -> Data = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.directory = directory
        self.maxBytes = maxBytes
        self.fileManager = fileManager
        self.downloadData = downloadData
    }

    public func localURL(for wallpaper: PaperWallpaper) -> URL {
        let ext = wallpaper.wallpaperUrl.pathExtension.isEmpty ? "jpg" : wallpaper.wallpaperUrl.pathExtension
        return directory.appendingPathComponent("\(wallpaper.id).\(ext)")
    }

    public func cachedFileURL(for wallpaper: PaperWallpaper, downloadIfNeeded: Bool = true) async throws -> URL {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = localURL(for: wallpaper)

        if fileManager.fileExists(atPath: fileURL.path) {
            try touch(fileURL)
            return fileURL
        }

        guard downloadIfNeeded else {
            throw CocoaError(.fileNoSuchFile)
        }

        let data = try await downloadData(wallpaper.wallpaperUrl)
        try data.write(to: fileURL, options: .atomic)
        try await enforceSizeLimit()
        return fileURL
    }

    public func totalBytes() throws -> Int {
        guard fileManager.fileExists(atPath: directory.path) else {
            return 0
        }

        return try cachedFiles().reduce(0) { total, file in
            total + (try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
        }
    }

    public func clear() throws {
        guard fileManager.fileExists(atPath: directory.path) else {
            return
        }

        for file in try cachedFiles() {
            try fileManager.removeItem(at: file)
        }
    }

    private func enforceSizeLimit() async throws {
        var files = try cachedFiles().map { url in
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentAccessDateKey, .creationDateKey])
            return CachedFile(
                url: url,
                size: values.fileSize ?? 0,
                date: values.contentAccessDate ?? values.creationDate ?? .distantPast
            )
        }

        var total = files.reduce(0) { $0 + $1.size }
        guard total > maxBytes else {
            return
        }

        files.sort { $0.date < $1.date }
        for file in files where total > maxBytes {
            try fileManager.removeItem(at: file.url)
            total -= file.size
        }
    }

    private func cachedFiles() throws -> [URL] {
        try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )
    }

    private func touch(_ fileURL: URL) throws {
        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
    }
}

private struct CachedFile {
    let url: URL
    let size: Int
    let date: Date
}

