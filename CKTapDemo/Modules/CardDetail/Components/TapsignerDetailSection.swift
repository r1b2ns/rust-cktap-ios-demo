import SwiftUI

struct TapsignerDetailSection: View {
    let info: TapsignerInfo

    var body: some View {
        Section("Identity") {
            DetailRow(label: "Card Ident", value: info.cardIdent, monospaced: true, copyable: true)
            DetailRow(label: "Version", value: info.version)
            DetailRow(label: "Status", value: info.isInitialized ? "Initialized" : "Uninitialized")
        }

        Section("Card") {
            DetailRow(label: "Birth Height", value: "\(info.birth)")
            DetailRow(label: "Backups", value: "\(info.numBackups)")
            if let delay = info.authDelay, delay > 0 {
                DetailRow(label: "Auth Delay", value: "\(delay)s")
            }
        }

        Section("Keys") {
            DetailRow(
                label: "Card Pubkey",
                value: info.pubkey,
                monospaced: true,
                copyable: true
            )
            if let path = info.path, !path.isEmpty {
                DetailRow(
                    label: "Derivation Path",
                    value: "m/\(path.map(String.init).joined(separator: "/"))",
                    monospaced: true,
                    copyable: true
                )
            } else {
                DetailRow(label: "Derivation Path", value: "—")
            }
            if let derived = info.derivedPubkey {
                DetailRow(
                    label: "Derived Pubkey",
                    value: derived,
                    monospaced: true,
                    copyable: true
                )
            }
        }

        Section("Metadata") {
            DetailRow(
                label: "Saved At",
                value: info.savedAt.formatted(date: .abbreviated, time: .shortened)
            )
        }
    }
}
