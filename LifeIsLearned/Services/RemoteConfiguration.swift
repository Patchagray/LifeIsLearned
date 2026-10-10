import Foundation

/// Provisioned once by the reviewer at release time. No credentials or transport
/// assumptions are embedded in lesson packages or scattered through views.
struct RemoteConfiguration: Sendable {
    var catalogURL: URL?
    var requestURL: URL?
    static func bundled() -> Self {
        func url(_ key: String) -> URL? {
            guard let text = Bundle.main.object(forInfoDictionaryKey: key) as? String,
                  let url = URL(string: text), (try? RemoteURL.validate(url)) != nil else { return nil }
            return url
        }
        let catalogURL = DistributionURL.catalog
        return Self(catalogURL: catalogURL, requestURL: url("BookRequestAPIURL"))
    }
}
