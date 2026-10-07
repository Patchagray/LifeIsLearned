import Foundation
import Combine

/// One transfer owns its URLSession and staging file. Only URLSession-issued resume
/// data is retained, in memory, and it is bound to the entire expected asset.
private final class PackageTransfer: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<URL, Error>?
    private var task: URLSessionDownloadTask?
    private var session: URLSession?
    private var cancelled = false
    private var result: Result<URL, Error>?
    private let destination: URL
    private let expected: Int
    private let progress: @Sendable (Double) -> Void
    init(destination: URL, expected: Int, progress: @escaping @Sendable (Double) -> Void) {
        self.destination = destination; self.expected = expected; self.progress = progress
    }
    func run(url: URL, resume: Data?, configuration: URLSessionConfiguration) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock(); defer { lock.unlock() }
            if cancelled { continuation.resume(throwing: CancellationError()); return }
            self.continuation = continuation
            let queue = OperationQueue(); queue.maxConcurrentOperationCount = 1
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
            self.session = session
            if let resume { task = session.downloadTask(withResumeData: resume) }
            else {
                var request = URLRequest(url: url); request.timeoutInterval = 60
                task = session.downloadTask(with: request)
            }
            task?.resume()
        }
    }
    func cancel() async -> Data? {
        await withCheckedContinuation { response in
            lock.lock(); cancelled = true; let current = task; lock.unlock()
            guard let current else { response.resume(returning: nil); return }
            current.cancel(byProducingResumeData: { response.resume(returning: $0) })
        }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url.flatMap { (try? RemoteURL.validate($0)) != nil ? request : nil })
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesWritten > expected || totalBytesExpectedToWrite > expected {
            result = .failure(PackageError.invalid("The download exceeds its declared byte size.")); downloadTask.cancel(); return
        }
        progress(min(1, Double(totalBytesWritten) / Double(expected)))
    }
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, [200, 206].contains(response.statusCode), let url = response.url else {
                throw PackageError.invalid("The book download did not return a valid response.")
            }
            try RemoteURL.validate(url)
            try FileManager.default.moveItem(at: location, to: destination)
            result = .success(destination)
        } catch { result = .failure(error) }
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock(); let continuation = self.continuation; self.continuation = nil
        let wasCancelled = cancelled; self.task = nil; self.session = nil; lock.unlock()
        session.finishTasksAndInvalidate()
        if wasCancelled { try? FileManager.default.removeItem(at: destination); continuation?.resume(throwing: CancellationError()) }
        else { continuation?.resume(with: result ?? .failure(error ?? PackageError.invalid("The download did not produce a file."))) }
    }
}

actor PackageDownloadService {
    private let directory: URL
    private let configuration: URLSessionConfiguration
    private var active: PackageTransfer?
    private var activeKey: String?
    private var resumes: [String: Data] = [:]
    init(directory: URL, configuration: URLSessionConfiguration = .ephemeral) {
        self.directory = directory.appendingPathComponent("Library-v3/Downloads/staging")
        self.configuration = configuration
    }
    private func key(_ asset: RemoteAsset) -> String { asset.url.absoluteString + "|" + asset.sha256 + "|" + String(asset.bytes) }
    func canResume(_ asset: RemoteAsset) -> Bool { resumes[key(asset)] != nil }
    func cancel() async {
        guard let active, let key = activeKey else { return }
        if let data = await active.cancel() { resumes[key] = data }
    }
    func download(_ book: DiscoveryBook, progress: @escaping @Sendable (Double) -> Void) async throws -> LessonPackage {
        guard active == nil else { throw PackageError.invalid("Another book is already downloading.") }
        guard book.availability == .available, let metadata = book.package else { throw PackageError.invalid("This book has no prepared download yet.") }
        try metadata.asset.validate(limit: CollectionLimits.packageBytes)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(UUID().uuidString + ".download")
        let transfer = PackageTransfer(destination: file, expected: metadata.bytes, progress: progress)
        let identity = key(metadata.asset)
        active = transfer; activeKey = identity
        defer { active = nil; activeKey = nil; try? FileManager.default.removeItem(at: file) }
        let resume = resumes.removeValue(forKey: identity)
        let result = try await withTaskCancellationHandler {
            try await transfer.run(url: metadata.url, resume: resume, configuration: configuration)
        } onCancel: { Task { await self.cancel() } }
        try Task.checkCancellation()
        return try Self.validate(file: result, book: book)
    }
    nonisolated static func validate(file: URL, book: DiscoveryBook) throws -> LessonPackage {
        guard let metadata = book.package else { throw PackageError.invalid("Missing package metadata.") }
        try metadata.asset.validate(limit: CollectionLimits.packageBytes)
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize
        try CollectionLimits.require(size == metadata.bytes, "The book download has the wrong byte size.")
        let data = try Data(contentsOf: file, options: .mappedIfSafe)
        try CollectionLimits.require(LibraryDigest.sha256(data) == metadata.sha256, "The book download failed its SHA-256 integrity check.")
        // Integrity is checked before JSON decoding or touching installed state.
        let package = try LessonPackage.decodeImport(data)
        try CollectionLimits.require(package.formatVersion == 2 && package.book.id == book.id && package.collectionNumber == metadata.collectionRevision,
                                     "Downloaded book identity or revision does not match the catalog.")
        return package
    }
}

@MainActor final class BookDownloadManager: ObservableObject {
    @Published private(set) var bookID: String?
    @Published private(set) var progress: Double = 0
    @Published private(set) var message: String?
    @Published private(set) var resumable = false
    @Published private(set) var busy = false
    @Published private(set) var canCancel = false
    private let service: PackageDownloadService
    private var task: Task<Void, Never>?
    private var asset: RemoteAsset?
    init(directory: URL, configuration: URLSessionConfiguration = .ephemeral) { service = PackageDownloadService(directory: directory, configuration: configuration) }
    func start(_ book: DiscoveryBook, source: BookSourceRecord, library: LibraryStore) {
        guard !busy else { return }
        bookID = book.id; asset = book.package?.asset; progress = 0; message = "Downloading…"; busy = true; canCancel = true; resumable = false
        task = Task {
            defer { busy = false; canCancel = false }
            do {
                let package = try await service.download(book) { value in Task { @MainActor [weak self] in self?.progress = value } }
                try Task.checkCancellation()
                var review = try await library.storage.review(package: package, catalog: library.catalog)
                try Task.checkCancellation()
                try CollectionLimits.require(!library.isCommitting && !library.isLoading && !library.readOnly, "The library cannot install right now. Finish its current change or resolve its recovery warning, then try again.")
                canCancel = false
                review.source = source
                if !review.removed.isEmpty { library.importReview = review; message = "Review removed ideas before installing." }
                else {
                    message = "Installing…"
                    await library.commitImport(review)
                    message = library.errorMessage == nil ? "In Library" : library.errorMessage
                }
            } catch {
                if Task.isCancelled || error is CancellationError { message = "Download cancelled. Your library is unchanged." }
                else { message = error.localizedDescription }
                if let asset = book.package?.asset { resumable = await service.canResume(asset) }
            }
        }
    }
    func cancel() {
        guard canCancel else { return }
        // Also cancel verification/install preparation after the network task finishes.
        task?.cancel()
        let expected = asset
        Task {
            await service.cancel()
            if let expected { resumable = await service.canResume(expected) }
        }
    }
}
