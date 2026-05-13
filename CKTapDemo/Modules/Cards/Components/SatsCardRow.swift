import SwiftUI

struct SatsCardRow: View {
    let card: SatsCardSavedInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.cardIdent)
                .font(.headline)
            HStack(spacing: 8) {
                Text("v\(card.version)")
                Text("•")
                Text("slot \(card.activeSlot) of \(card.numSlots)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let address = card.address {
                Text(address)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(.vertical, 2)
    }
}
