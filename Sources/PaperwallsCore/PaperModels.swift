import Foundation

public struct PaperCatalog: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    public let baseUrl: URL
    public let wallpapersPath: String
    public let thumbsPath: String
    public let themes: [PaperTheme]
    public let wallpapers: [PaperWallpaper]

    public init(
        name: String,
        description: String,
        baseUrl: URL,
        wallpapersPath: String,
        thumbsPath: String,
        themes: [PaperTheme],
        wallpapers: [PaperWallpaper]
    ) {
        self.name = name
        self.description = description
        self.baseUrl = baseUrl
        self.wallpapersPath = wallpapersPath
        self.thumbsPath = thumbsPath
        self.themes = themes
        self.wallpapers = wallpapers
    }

    public func theme(for wallpaper: PaperWallpaper) -> PaperTheme? {
        themes.first { $0.key == wallpaper.theme }
    }
}

public struct PaperTheme: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: String { key }

    public let key: String
    public let label: String
    public let desc: String

    public init(key: String, label: String, desc: String) {
        self.key = key
        self.label = label
        self.desc = desc
    }
}

public struct PaperWallpaper: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let theme: String
    public let tags: [String]
    public let file: String
    public let wallpaperUrl: URL
    public let thumbUrl: URL

    public init(
        id: String,
        name: String,
        theme: String,
        tags: [String],
        file: String,
        wallpaperUrl: URL,
        thumbUrl: URL
    ) {
        self.id = id
        self.name = name
        self.theme = theme
        self.tags = tags
        self.file = file
        self.wallpaperUrl = wallpaperUrl
        self.thumbUrl = thumbUrl
    }
}

