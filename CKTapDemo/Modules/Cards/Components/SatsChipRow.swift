import SwiftUI

struct SatsChipRow: View {
    let card: SatsChipInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(card.cardIdent)
                    .font(.headline)
                Text("v\(card.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}
