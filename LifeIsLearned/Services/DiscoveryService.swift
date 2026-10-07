import Foundation
import Combine

actor DiscoveryService {
    struct Cache: Codable { var fetchedAt: Date; var catalog: DiscoveryCatalog }
    let endpoint: URL?
    private let cacheFile: URL
    private let identity: CatalogIdentity
    private let session: URLSession
    init(endpoint: URL?, directory: URL, identity: CatalogIdentity, session: URLSession = .shared) {
        self.endpoint = endpoint; self.identity = identity; self.session = session
        let key = LibraryDigest.sha256(Data((endpoint?.absoluteString ?? "preview").utf8))
        cacheFile = directory.appendingPathComponent("Discovery/" + key + ".json")
    }
    func cached() -> Cache? {
        guard let size = try? cacheFile.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= DiscoveryCatalog.maximumBytes * 2,
              let data = try? Data(contentsOf: cacheFile), data.count <= DiscoveryCatalog.maximumBytes * 2,
              let value = try? JSONDecoder().decode(Cache.self, from: data),
              (try? value.catalog.validated(identity: identity)) != nil else { return nil }
        return value
    }
    func refresh() async throws -> Cache {
        guard let endpoint else { throw PackageError.invalid("The remote library is not configured yet.") }
        let data = try await fetch(endpoint, limit: DiscoveryCatalog.maximumBytes)
        let value = Cache(fetchedAt: Date(), catalog: try DiscoveryCatalog.decode(data, identity: identity))
        try Task.checkCancellation()
        let bytes = try JSONEncoder().encode(value)
        try FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: cacheFile, options: .atomic)
        return value
    }
    func thumbnail(_ asset: RemoteAsset) async throws -> Data {
        try asset.validate(limit: 512 * 1_024)
        let data = try await fetch(asset.url, limit: asset.bytes)
        try CollectionLimits.require(data.count == asset.bytes && LibraryDigest.sha256(data) == asset.sha256, "Thumbnail integrity check failed.")
        return data
    }
    private func fetch(_ url: URL, limit: Int) async throws -> Data {
        try RemoteURL.validate(url)
        var request = URLRequest(url: url); request.timeoutInterval = 25; request.cachePolicy = .reloadIgnoringLocalCacheData
        let (bytes, response) = try await session.bytes(for: request, delegate: HTTPSRedirectDelegate())
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, let finalURL = http.url else { throw PackageError.invalid("The remote library did not return a valid response.") }
        try RemoteURL.validate(finalURL)
        try CollectionLimits.require(response.expectedContentLength <= limit, "Remote metadata exceeds its size limit.")
        var result = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            try CollectionLimits.require(result.count < limit, "Remote metadata exceeds its size limit.")
            result.append(byte)
        }
        return result
    }
}

@MainActor final class DiscoveryStore: ObservableObject {
    @Published private(set) var catalog: DiscoveryCatalog?
    @Published private(set) var refreshing = false
    @Published private(set) var status: String?
    let identity: CatalogIdentity
    let service: DiscoveryService
    let endpoint: URL?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    init(endpoint: URL?, directory: URL, identity: CatalogIdentity, session: URLSession = .shared) {
        self.identity = identity; self.endpoint = endpoint
        service = DiscoveryService(endpoint: endpoint, directory: directory, identity: identity, session: session)
        if let url = Bundle.main.url(forResource: "Remote-Catalog-001", withExtension: "json"), let data = try? Data(contentsOf: url) {
            catalog = try? DiscoveryCatalog.decode(data, identity: identity)
        }
    }
    func open() {
        task?.cancel(); generation = UUID(); let token = generation
        task = Task {
            if let cached = await service.cached(), token == generation { catalog = cached.catalog; status = "Saved catalog" }
            guard !Task.isCancelled, token == generation else { return }
            guard endpoint != nil else { status = "Library preview · releases are not connected yet"; return }
            await refreshNow(token: token)
        }
    }
    func refresh() { task?.cancel(); generation = UUID(); let token = generation; task = Task { await refreshNow(token: token) } }
    private func refreshNow(token: UUID) async {
        guard token == generation else { return }
        refreshing = true; defer { if token == generation { refreshing = false } }
        do {
            let value = try await service.refresh()
            guard !Task.isCancelled, token == generation else { return }
            catalog = value.catalog; status = nil
        } catch {
            if !Task.isCancelled, token == generation { status = catalog == nil ? "Library unavailable. Try again later." : "Showing saved catalog · refresh unavailable" }
        }
    }
    func cancelRefresh() { task?.cancel(); generation = UUID(); refreshing = false }
}

final class HTTPSRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.flatMap { (try? RemoteURL.validate($0)) != nil ? request : nil })
    }
}
