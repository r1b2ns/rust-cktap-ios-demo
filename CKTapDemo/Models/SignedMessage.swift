import Foundation

nonisolated struct SignedMessage: Sendable, Hashable {
    let message: String
    /// Base64-encoded recoverable ECDSA signature, ready for BIP-137 verification.
    let signature: String
}
