import Foundation

/// Result of calling `tapSigner.derive(path:cvc:)` — the path used and the
/// hex-encoded pubkey returned by the card.
///
/// Receiving this struct means `rust-cktap`'s internal signature verification
/// passed. See https://github.com/coinkite/coinkite-tap-proto/issues/56 for
/// why this can fail on real cards with non-empty paths.
nonisolated struct DerivedPubkey: Sendable, Hashable {
    let path: [UInt32]
    let pubkey: String

    var pathDisplay: String {
        path.isEmpty ? "m" : "m/" + path.map { "\($0)h" }.joined(separator: "/")
    }
}
