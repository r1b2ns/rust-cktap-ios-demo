import SwiftUI

struct SatsChipRow: View {
    let card: SatsChipInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(card.cardIdent)
                .font(.headline)
            Text("v\(card.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
