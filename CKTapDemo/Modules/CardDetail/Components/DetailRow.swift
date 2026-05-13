import SwiftUI

/// Two-line row used in the card detail sections: a small label on top, the
/// value below, and a trailing copy button that puts the value on the
/// clipboard.
struct DetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(monospaced ? .footnote.monospaced() : .body)
                    .textSelection(.enabled)
                    .lineLimit(monospaced ? 4 : nil)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 0)

            Button {
                UIPasteboard.general.string = value
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.callout)
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Copy \(label)")
        }
        .padding(.vertical, 2)
    }
}
