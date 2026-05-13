import SwiftUI

struct EmptyStateView: View {
    let isScanning: Bool
    let onScan: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "wave.3.right.circle")
                .imageScale(.large)
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            Text("Tapsigner or SatsBuddy")
                .font(.title2)
                .bold()

            Button {
                onScan()
            } label: {
                Label("Scan NFC", systemImage: "dot.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isScanning)
        }
        .padding()
    }
}
