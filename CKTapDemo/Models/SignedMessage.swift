import Foundation

nonisolated struct SignedMessage: Sendable, Hashable {
    let message: String
    /// Base64-encoded recoverable ECDSA signature, ready for BIP-137 verification.
    /// Encoded as `[27 + recId + 4 (compressed)] || r (32) || s (32)`.
    let signature: String
    /// Hex-encoded compressed pubkey (33 bytes) that produced the signature.
    /// Needed by verifiers that don't recover the pubkey from the signature.
    let pubkey: String
}
