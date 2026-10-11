import Foundation
import Combine
import ImageIO

actor DiscoveryService {
    struct Cache: Codable { var fetchedAt: Date; var catalog: DiscoveryCatalog; var etag: String? = nil }
    let endpoint: URL?
    private let cacheFile: URL
    private let thumbnailDirectory: URL
    private let identity: CatalogIdentity
    private let session: URLSession
    init(endpoint: URL?, directory: URL, identity: CatalogIdentity, session: URLSession = .shared) {
        self.endpoint = endpoint; self.identity = identity; self.session = session
        thumbnailDirectory = directory.appendingPathComponent("Discovery/Thumbnails")
        let key = LibraryDigest.sha256(Data((endpoint?.absoluteString ?? "preview").utf8))
        cacheFile = directory.appendingPathComponent("Discovery/" + key + ".json")
    }
    func cached() -> Cache? {
        guard let size = try? cacheFile.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= DiscoveryCatalog.maximumBytes * 2,
              let data = try? Data(contentsOf: cacheFile), data.count <= DiscoveryCatalog.maximumBytes * 2,
              var value = try? JSONDecoder().decode(Cache.self, from: data),
              let ordered = try? value.catalog.validated(identity: identity) else { return nil }
        value.catalog = ordered
        return value
    }
    func refresh() async throws -> Cache {
        guard let endpoint else { throw PackageError.invalid("The remote library is not configured yet.") }
        let previous = cached()
        let (data, response) = try await fetch(endpoint, limit: DiscoveryCatalog.maximumBytes, etag: previous?.etag)
        var value: Cache
        if response.statusCode == 304, let previous {
            value = previous; value.fetchedAt = Date()
        } else {
            let catalog = try DiscoveryCatalog.decode(data, identity: identity)
            if let previous { try catalog.validateUpdate(from: previous.catalog) }
            value = Cache(fetchedAt: Date(), catalog: catalog, etag: response.value(forHTTPHeaderField: "ETag"))
        }
        try Task.checkCancellation()
        // Another scanner/home service can refresh the same endpoint while this
        // request is in flight. Compare against the latest disk snapshot as well.
        if let latest = cached() { try value.catalog.validateUpdate(from: latest.catalog) }
        let bytes = try JSONEncoder().encode(value)
        try FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try bytes.write(to: cacheFile, options: .atomic)
        return value
    }
    func thumbnail(_ asset: RemoteAsset) async throws -> Data {
        try asset.validate(limit: 512 * 1_024)
        let file = thumbnailDirectory.appendingPathComponent(asset.sha256)
        if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize, size == asset.bytes,
           let cached = try? Data(contentsOf: file), (try? validateThumbnail(cached, asset: asset)) != nil { return cached }
        let (data, _) = try await fetch(asset.url, limit: asset.bytes)
        try validateThumbnail(data, asset: asset)
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: thumbnailDirectory, withIntermediateDirectories: true)
        try data.write(to: file, options: .atomic)
        // Keep thumbnails separately bounded; old versions may be removed and re-fetched.
        let files = (try? FileManager.default.contentsOfDirectory(at: thumbnailDirectory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])) ?? []
        let oldest = files.sorted { ((try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) < ((try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
        var total = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        for candidate in oldest where total > 32 * 1_024 * 1_024 && candidate != file {
            let size = (try? candidate.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            if (try? FileManager.default.removeItem(at: candidate)) != nil { total -= size }
        }
        return data
    }
    private func validateThumbnail(_ data: Data, asset: RemoteAsset) throws {
        try CollectionLimits.require(data.count == asset.bytes && LibraryDigest.sha256(data) == asset.sha256, "Thumbnail integrity check failed.")
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let type = CGImageSourceGetType(source) as String?, ["public.png", "public.jpeg"].contains(type) else {
            throw PackageError.invalid("Library thumbnails must be PNG or JPEG.")
        }
        try CollectionLimits.validateImage(CollectionArtwork(mediaType: type == "public.png" ? "image/png" : "image/jpeg", data: data))
    }
    private func fetch(_ url: URL, limit: Int, etag: String? = nil) async throws -> (Data, HTTPURLResponse) {
        try DistributionURL.validate(url)
        var request = URLRequest(url: url); request.timeoutInterval = 25; request.cachePolicy = .reloadIgnoringLocalCacheData
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let (bytes, response) = try await session.bytes(for: request, delegate: DistributionRedirectDelegate())
        defer { bytes.task.cancel() }
        guard let http = response as? HTTPURLResponse, let finalURL = http.url else { throw RemoteResponse.error(nil) }
        try DistributionURL.validate(finalURL, redirect: true)
        if http.value(forHTTPHeaderField: "X-Library-State") == "planned-only" { throw RemoteResponse.error(503) }
        if http.statusCode == 304, etag != nil { return (Data(), http) }
        guard http.statusCode == 200 else { throw RemoteResponse.error(http.statusCode) }
        try CollectionLimits.require(response.expectedContentLength <= limit, "Remote metadata exceeds its size limit.")
        var result = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            try CollectionLimits.require(result.count < limit, "Remote metadata exceeds its size limit.")
            result.append(byte)
        }
        return (result, http)
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
            if !Task.isCancelled, token == generation { status = (catalog == nil ? "Library unavailable. " : "Showing saved catalog · refresh unavailable. ") + RemoteResponse.message(error) }
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

final class DistributionRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.flatMap { (try? DistributionURL.validate($0, redirect: true)) != nil ? request : nil })
    }
}
enum RemoteResponse {
    static func message(_ error: Error) -> String {
        if let network = error as? URLError {
            switch network.code {
            case .notConnectedToInternet: return "You’re offline. Reconnect and try again when ready."
            case .timedOut: return "The connection took too long. Please retry."
            case .cancelled: return "The request was cancelled. You can try again."
            default: return "Couldn’t reach the library service. Check your connection and retry."
            }
        }
        if let validation = error as? PackageError { return validation.localizedDescription }
        return "The library request could not finish. Please try again."
    }

    static func error(_ status: Int?) -> PackageError {
        let message: String
        switch status {
        case 404: message = "This release is not available (404). Refresh Explore and try again."
        case 401, 403: message = "The library service could not authorize this download. Please try again later."
        case 429: message = "The library service is busy. Wait a little, then retry."
        default: message = "The library service could not respond. Check your connection and retry."
        }
        return .invalid(message)
    }
}
