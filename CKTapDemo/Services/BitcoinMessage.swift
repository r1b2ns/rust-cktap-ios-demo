import CryptoKit
import Foundation

/// BIP-137 / "Bitcoin Signed Message" digest helper.
///
/// Produces the 32-byte digest that gets fed to the secp256k1 signer:
/// `double-SHA256("\x18Bitcoin Signed Message:\n" + varint(len(msg)) + msg)`.
nonisolated enum BitcoinMessage {
    private static let magicPrefix: [UInt8] = Array("\u{18}Bitcoin Signed Message:\n".utf8)

    static func digest(_ message: String) -> Data {
        let messageBytes = Array(message.utf8)
        var data = Data()
        data.append(contentsOf: magicPrefix)
        data.append(contentsOf: varint(UInt64(messageBytes.count)))
        data.append(contentsOf: messageBytes)
        let first = Data(SHA256.hash(data: data))
        let second = Data(SHA256.hash(data: first))
        return second
    }

    /// Encodes a recoverable ECDSA signature as a base64 BIP-137 "Bitcoin
    /// Signed Message" signature: `[27 + recId + 4] || r (32) || s (32)`.
    ///
    /// The `+ 4` flag marks the pubkey as compressed (P2PKH), which is what
    /// Tapsigner produces.
    static func encodeBIP137Signature(rs: Data, recId: UInt8) throws -> String {
        guard rs.count == 64 else {
            throw MessageSigningError.invalidSignatureLength(rs.count)
        }
        guard recId < 4 else {
            throw MessageSigningError.invalidRecoveryId(recId)
        }
        var out = Data(capacity: 65)
        out.append(27 + recId + 4)
        out.append(rs)
        return out.base64EncodedString()
    }

    private static func varint(_ n: UInt64) -> [UInt8] {
        if n < 0xfd {
            return [UInt8(n)]
        }
        if n <= 0xffff {
            return [0xfd, UInt8(n & 0xff), UInt8((n >> 8) & 0xff)]
        }
        if n <= 0xffff_ffff {
            return [
                0xfe,
                UInt8(n & 0xff),
                UInt8((n >> 8) & 0xff),
                UInt8((n >> 16) & 0xff),
                UInt8((n >> 24) & 0xff),
            ]
        }
        var bytes: [UInt8] = [0xff]
        for i in 0..<8 {
            bytes.append(UInt8((n >> (i * 8)) & 0xff))
        }
        return bytes
    }
}
