import Foundation

public enum RotationScope: Codable, Equatable, Sendable {
    case all
    case theme(String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case themeKey
    }

    private enum Kind: String, Codable {
        case all
        case theme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)

        switch kind {
        case .all:
            self = .all
        case .theme:
            self = .theme(try container.decode(String.self, forKey: .themeKey))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .all:
            try container.encode(Kind.all, forKey: .kind)
        case .theme(let key):
            try container.encode(Kind.theme, forKey: .kind)
            try container.encode(key, forKey: .themeKey)
        }
    }
}

public struct RotationConfiguration: Codable, Equatable, Sendable {
    public var isEnabled: Bool
    public var intervalSeconds: TimeInterval
    public var scope: RotationScope

    public init(isEnabled: Bool = false, intervalSeconds: TimeInterval = 3_600, scope: RotationScope = .all) {
        self.isEnabled = isEnabled
        self.intervalSeconds = intervalSeconds
        self.scope = scope
    }
}

public enum RotationEngine {
    public static let minimumInterval: TimeInterval = 60

    public static func eligibleWallpapers(in catalog: PaperCatalog, scope: RotationScope) -> [PaperWallpaper] {
        switch scope {
        case .all:
            return catalog.wallpapers
        case .theme(let themeKey):
            return catalog.wallpapers.filter { $0.theme == themeKey }
        }
    }

    public static func nextWallpaper(
        in catalog: PaperCatalog,
        scope: RotationScope,
        currentID: String?
    ) -> PaperWallpaper? {
        let eligible = eligibleWallpapers(in: catalog, scope: scope)
        guard !eligible.isEmpty else {
            return nil
        }

        guard let currentID, let index = eligible.firstIndex(where: { $0.id == currentID }) else {
            return eligible.first
        }

        return eligible[(index + 1) % eligible.count]
    }

    public static func normalizedInterval(_ interval: TimeInterval) -> TimeInterval {
        max(minimumInterval, interval)
    }
}

