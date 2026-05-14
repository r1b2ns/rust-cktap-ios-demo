import CKTap
import Foundation

/// Maps the raw `CKTap*Error` types — which surface as nested debug strings —
/// into short, user-facing messages.
nonisolated enum CKTapErrorFormatter {

    static func userMessage(for error: Error) -> String {
        switch error {
        case let signingError as MessageSigningError:
            return signingError.userMessage
        case let cardError as CardError:
            return message(forCard: cardError)
        case let ckTapError as CkTapError:
            return message(forCkTap: ckTapError)
        case let readError as ReadError:
            return unwrap(readError)
        case let changeError as ChangeError:
            return unwrap(changeError)
        case let deriveError as DeriveError:
            return unwrap(deriveError)
        case let xpubError as XpubError:
            return unwrap(xpubError)
        case let unsealError as UnsealError:
            return unwrap(unsealError)
        case let statusError as StatusError:
            return unwrap(statusError)
        case let certsError as CertsError:
            return unwrap(certsError)
        case let dumpError as DumpError:
            return unwrap(dumpError)
        case let signError as SignPsbtError:
            return unwrap(signError)
        case let signError as SignDigestError:
            return unwrap(signError)
        case let keyError as KeyError:
            return message(forKey: keyError)
        default:
            return error.localizedDescription
        }
    }

    // MARK: - Card

    private static func message(forCard error: CardError) -> String {
        switch error {
        case .BadAuth:
            return String(localized: "Wrong CVC/PIN. Check the code printed on the back of the card.")
        case .NeedsAuth:
            return String(localized: "Card requires authentication (CVC).")
        case .UnluckyNumber:
            return String(localized: "The card got an unlucky number. Try again.")
        case .BadArguments:
            return String(localized: "Invalid arguments sent to the card.")
        case .UnknownCommand:
            return String(localized: "Unknown command for this card.")
        case .InvalidCommand:
            return String(localized: "Invalid command for this card.")
        case .InvalidState:
            return String(localized: "Card is in an invalid state for this operation.")
        case .WeakNonce:
            return String(localized: "Weak nonce detected. Try again.")
        case .BadCbor:
            return String(localized: "Malformed response from the card.")
        case .BackupFirst:
            return String(localized: "Back up the card before this operation.")
        case .RateLimited:
            return String(localized: "Card is rate-limited. Wait a moment and try again.")
        }
    }

    // MARK: - CkTap

    private static func message(forCkTap error: CkTapError) -> String {
        switch error {
        case .Card(let inner):
            return message(forCard: inner)
        case .CborDe(let msg):
            return String(localized: "Decoding error: \(msg)")
        case .CborValue(let msg):
            return String(localized: "Card data error: \(msg)")
        case .Transport(let msg):
            return String(localized: "NFC transport error: \(msg)")
        case .UnknownCardType:
            return String(localized: "Unsupported card type.")
        }
    }

    // MARK: - Key

    private static func message(forKey error: KeyError) -> String {
        switch error {
        case .Secp256k1(let msg):
            return String(localized: "Cryptography error: \(msg)")
        case .KeyFromSlice(let msg):
            return String(localized: "Invalid key bytes: \(msg)")
        }
    }

    // MARK: - Wrappers

    private static func unwrap(_ error: ReadError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .Key(let inner): return message(forKey: inner)
        }
    }

    private static func unwrap(_ error: ChangeError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .TooShort(let len):
            return String(localized: "PIN too short (\(len) characters).")
        case .TooLong(let len):
            return String(localized: "PIN too long (\(len) characters).")
        case .SameAsOld:
            return String(localized: "New PIN can't be the same as the current one.")
        }
    }

    private static func unwrap(_ error: DeriveError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .Key(let inner): return message(forKey: inner)
        case .InvalidChainCode(let msg):
            return String(localized: "Invalid chain code: \(msg)")
        }
    }

    private static func unwrap(_ error: XpubError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .Bip32(let msg):
            return String(localized: "BIP32 error: \(msg)")
        }
    }

    private static func unwrap(_ error: UnsealError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .Key(let inner): return message(forKey: inner)
        }
    }

    private static func unwrap(_ error: StatusError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .Key(let inner): return message(forKey: inner)
        }
    }

    private static func unwrap(_ error: CertsError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .Key(let inner): return message(forKey: inner)
        case .InvalidRootCert(let msg):
            return String(localized: "Invalid root certificate: \(msg)")
        }
    }

    private static func unwrap(_ error: DumpError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .Key(let inner): return message(forKey: inner)
        case .SlotSealed(let slot):
            return String(localized: "Slot \(slot) is sealed.")
        case .SlotUnused(let slot):
            return String(localized: "Slot \(slot) is unused.")
        @unknown default:
            return error.localizedDescription
        }
    }

    private static func unwrap(_ error: SignDigestError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .InvalidDigestLength(let len):
            return String(localized: "Invalid digest length: \(len) bytes (expected 32).")
        case .RecoveryId(let msg):
            return String(localized: "Could not recover signature pubkey: \(msg)")
        }
    }

    private static func unwrap(_ error: SignPsbtError) -> String {
        switch error {
        case .CkTap(let inner): return message(forCkTap: inner)
        case .InvalidPath(let index):
            return String(localized: "Invalid path on input \(index).")
        case .InvalidScript(let index):
            return String(localized: "Invalid script on input \(index).")
        case .MissingPubkey(let index):
            return String(localized: "Missing pubkey on input \(index).")
        case .MissingUtxo(let index):
            return String(localized: "Missing UTXO on input \(index).")
        case .PubkeyMismatch(let index):
            return String(localized: "Pubkey mismatch on input \(index).")
        case .SighashError(let msg):
            return String(localized: "Sighash error: \(msg)")
        case .SignatureError(let msg):
            return String(localized: "Signature error: \(msg)")
        case .SlotNotUnsealed(let slot):
            return String(localized: "Slot \(slot) is not unsealed.")
        case .WitnessProgram(let msg):
            return String(localized: "Witness program error: \(msg)")
        case .PsbtEncoding(let msg):
            return String(localized: "PSBT encoding error: \(msg)")
        @unknown default:
            return error.localizedDescription
        }
    }
}
