import SwiftUI

/// Two-line row used in the card detail sections: a small label on top and
/// the value below. Long monospace values become a long-press menu target so
/// the user can copy hex strings.
struct DetailRow: View {
    let label: String
    let value: String
    var monospaced: Bool = false
    var copyable: Bool = false

    var body: some View {
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
        .padding(.vertical, 2)
        .contextMenu {
            if copyable {
                Button {
                    UIPasteboard.general.string = value
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
            }
        }
    }
}
