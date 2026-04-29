import Foundation

public enum PaperAPIError: Error, Equatable {
    case emptyCatalog
}

public struct PaperAPIClient: Sendable {
    public let catalogURL: URL
    private let fetchData: @Sendable (URL) async throws -> Data

    public init(
        catalogURL: URL = URL(string: "https://burkeholland.github.io/paper/api.json")!,
        fetchData: @escaping @Sendable (URL) async throws -> Data = { url in
            let (data, _) = try await URLSession.shared.data(from: url)
            return data
        }
    ) {
        self.catalogURL = catalogURL
        self.fetchData = fetchData
    }

    public func fetchCatalog() async throws -> PaperCatalog {
        let data = try await fetchData(catalogURL)
        let catalog = try JSONDecoder().decode(PaperCatalog.self, from: data)
        guard !catalog.themes.isEmpty, !catalog.wallpapers.isEmpty else {
            throw PaperAPIError.emptyCatalog
        }
        return catalog
    }
}

