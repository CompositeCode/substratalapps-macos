import Foundation
import OpenAPIRuntime
import SubstratalAPI

/// An error the API returned, decoded from its envelope, or a status the spec
/// doesn't document. Screens map `code` to copy via COPY-AND-STATES.
public struct APIProblem: Error, Equatable, Sendable, CustomStringConvertible {
    public let status: Int?
    public let code: String
    public let message: String

    public init(status: Int?, code: String, message: String) {
        self.status = status
        self.code = code
        self.message = message
    }

    init(_ error: Components.Schemas._Error, status: Int) {
        self.init(status: status, code: error.error.code, message: error.error.message)
    }

    public static func undocumented(_ status: Int) -> APIProblem {
        APIProblem(status: status, code: "undocumented_status", message: "The API returned an unexpected status (\(status)).")
    }

    /// Builds a problem from any generated `Output` that isn't `.ok`, without a
    /// switch per operation: the case name gives the status, and the error
    /// envelope is found inside the associated response.
    public static func from(_ output: Any) -> APIProblem {
        let mirror = Mirror(reflecting: output)
        guard let child = mirror.children.first else {
            return APIProblem(status: nil, code: "unexpected_response", message: "Unexpected response.")
        }
        if child.label == "undocumented", let status = Mirror(reflecting: child.value).children.first?.value as? Int {
            return .undocumented(status)
        }
        let status = child.label.flatMap { statusByCase[$0] }
        if let envelope = firstEnvelope(in: child.value, depth: 0) {
            return APIProblem(envelope, status: status ?? 0)
        }
        return APIProblem(status: status, code: child.label ?? "unexpected_response", message: "Unexpected response.")
    }

    public var description: String { "\(status.map(String.init) ?? "-") \(code): \(message)" }

    /// Generated case names for the statuses the spec uses.
    static let statusByCase: [String: Int] = [
        "badRequest": 400, "unauthorized": 401, "forbidden": 403, "notFound": 404, "conflict": 409,
        "gone": 410, "unprocessableContent": 422, "tooManyRequests": 429, "internalServerError": 500,
        "notImplemented": 501, "serviceUnavailable": 503,
    ]

    private static func firstEnvelope(in value: Any, depth: Int) -> Components.Schemas._Error? {
        if let envelope = value as? Components.Schemas._Error { return envelope }
        guard depth < 4 else { return nil }
        for child in Mirror(reflecting: value).children {
            if let found = firstEnvelope(in: child.value, depth: depth + 1) { return found }
        }
        return nil
    }
}

public extension APIProblem {
    /// True when the request never got an answer (offline, DNS, TLS, timeout).
    /// The generated client wraps transport errors in `ClientError`.
    static func isConnectivity(_ error: Error) -> Bool {
        if error is URLError { return true }
        if let clientError = error as? ClientError { return isConnectivity(clientError.underlyingError) }
        return false
    }
}
