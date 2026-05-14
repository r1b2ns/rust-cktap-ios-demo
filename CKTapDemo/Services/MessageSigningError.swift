import Foundation

/// Errors specific to the message-signing flow on the Tapsigner.
nonisolated enum MessageSigningError: Error, Sendable {
    /// `rust-cktap`'s `signDigest` returned an `r||s` blob whose length is not
    /// 64 bytes. Should never happen in practice — the FFI always returns the
    /// canonical 32+32 layout — but guard against it so a malformed response
    /// surfaces as a typed error instead of an out-of-bounds crash.
    case invalidSignatureLength(Int)

    /// `recId` outside the BIP-137 valid range `0..<4`.
    case invalidRecoveryId(UInt8)
}

extension MessageSigningError {
    var userMessage: String {
        switch self {
        case .invalidSignatureLength(let len):
            return String(localized: "Unexpected signature length from card: \(len) bytes.")
        case .invalidRecoveryId(let id):
            return String(localized: "Unexpected recovery id from card: \(id).")
        }
    }
}
