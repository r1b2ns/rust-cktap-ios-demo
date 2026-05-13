import SwiftUI

struct TapsignerRow: View {
    let card: TapsignerInfo

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(card.cardIdent)
                        .font(.headline)
                        .truncationMode(.middle)
                        .lineLimit(1)

                    if !card.isInitialized {
                        Text("uninitialized")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    Text("v\(card.version)")
                    Text("•")
                    Text("\(card.numBackups) backup\(card.numBackups == 1 ? "" : "s")")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let derived = card.derivedPubkey {
                    Text(derived)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
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
