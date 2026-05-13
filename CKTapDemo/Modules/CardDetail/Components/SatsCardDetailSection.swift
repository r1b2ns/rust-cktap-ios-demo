import SwiftUI

struct SatsCardDetailSection: View {
    let info: SatsCardSavedInfo

    var body: some View {
        Section("Identity") {
            DetailRow(label: "Card Ident", value: info.cardIdent, monospaced: true, copyable: true)
            DetailRow(label: "Version", value: info.version)
        }

        Section("Card") {
            DetailRow(label: "Birth Height", value: "\(info.birth)")
            DetailRow(label: "Active Slot", value: "\(info.activeSlot) of \(info.numSlots)")
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
            if let address = info.address {
                DetailRow(
                    label: "Active Address",
                    value: address,
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
