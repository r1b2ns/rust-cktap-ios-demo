import SwiftUI

struct SatsChipDetailSection: View {
    let info: SatsChipInfo

    var body: some View {
        Section("Identity") {
            DetailRow(label: "Card Ident", value: info.cardIdent, monospaced: true, copyable: true)
            DetailRow(label: "Version", value: info.version)
        }

        Section("Card") {
            DetailRow(label: "Birth Height", value: "\(info.birth)")
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
