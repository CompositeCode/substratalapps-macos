import Foundation

/// What the server has told this build about its API version. Drives the GLB-03
/// "Update available" / "Update required" states (CLIENT-ARCHITECTURE §4.1).
public enum APIVersionStatus: Equatable, Sendable {
    /// The served version matches and isn't deprecated.
    case current
    /// The response carried `Deprecation` (RFC 9745) and maybe `Sunset` (RFC 8594).
    case deprecated(sunset: Date?)
    /// `400 unsupported_api_version`: stop API traffic until the app is updated.
    case unsupported(supported: [String])
}

/// Collects version signals from every response. Thread-safe; observers read
/// `status` and subscribe with `onChange`.
public final class APIVersionMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var _status: APIVersionStatus = .current
    private var _mismatchedEcho: String?
    private var observers: [@Sendable (APIVersionStatus) -> Void] = []

    public init() {}

    public var status: APIVersionStatus { lock.withLock { _status } }
    /// Set when a response echoed a different `Substratal-Version` than was sent:
    /// a proxy or a misconfigured environment. Logged, never acted on.
    public var mismatchedEcho: String? { lock.withLock { _mismatchedEcho } }

    public func onChange(_ observer: @escaping @Sendable (APIVersionStatus) -> Void) {
        lock.withLock { observers.append(observer) }
    }

    func record(echo: String?) {
        guard let echo, echo != APIVersion.headerValue else { return }
        lock.withLock { _mismatchedEcho = echo }
    }

    func record(deprecation: String?, sunset: String?) {
        guard deprecation != nil else { return }
        update(.deprecated(sunset: sunset.flatMap(Self.parseHTTPDate)))
    }

    func recordUnsupported(supported: [String]) {
        update(.unsupported(supported: supported))
    }

    private func update(_ new: APIVersionStatus) {
        let (changed, callbacks): (Bool, [@Sendable (APIVersionStatus) -> Void]) = lock.withLock {
            // Unsupported is terminal for this run; deprecation never downgrades it.
            if case .unsupported = _status { return (false, []) }
            guard _status != new else { return (false, []) }
            _status = new
            return (true, observers)
        }
        if changed { callbacks.forEach { $0(new) } }
    }

    /// `Sunset` is an HTTP-date (`Sun, 26 Apr 2027 00:00:00 GMT`).
    static func parseHTTPDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }
}
