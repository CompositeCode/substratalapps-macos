import os

/// Unified logging. Never log tokens, secrets, emails, IDs of people, or
/// notification content (CLIENT-ARCHITECTURE §11); errors and codes only.
enum Log {
    static let app = Logger(subsystem: "com.substratalapps.hub", category: "app")
}
