import Foundation

/// Errors specific to the message-signing flow on the Tapsigner.
nonisolated enum MessageSigningError: Error, Sendable {
    /// Raised at the call site where `rust-cktap`'s `signDigest` would be invoked
    /// but the FFI does not expose it yet. Tracked upstream as
    /// https://github.com/bitcoindevkit/rust-cktap/issues/70 — once the binding
    /// lands, replace the throw with the real call.
    case notImplemented
}

extension MessageSigningError {
    var userMessage: String {
        switch self {
        case .notImplemented:
            return String(
                localized: "Sign message isn't available yet — waiting on rust-cktap signDigest (upstream issue #70)."
            )
        }
    }
}
