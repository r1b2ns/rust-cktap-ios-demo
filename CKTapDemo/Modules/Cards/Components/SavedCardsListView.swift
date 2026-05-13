import SwiftUI

struct SavedCardsListView: View {
    let tapsigners: [TapsignerInfo]
    let satsCards: [SatsCardSavedInfo]
    let satsChips: [SatsChipInfo]
    let isScanning: Bool
    let onScan: () -> Void
    let onSelectTapsigner: (TapsignerInfo) -> Void
    let onSelectSatsCard: (SatsCardSavedInfo) -> Void
    let onSelectSatsChip: (SatsChipInfo) -> Void
    let onRemoveTapsigner: (String) -> Void
    let onRemoveSatsCard: (String) -> Void
    let onRemoveSatsChip: (String) -> Void

    var body: some View {
        List {
            if !tapsigners.isEmpty {
                Section("Tapsigner") {
                    ForEach(tapsigners) { card in
                        Button {
                            onSelectTapsigner(card)
                        } label: {
                            TapsignerRow(card: card)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onRemoveTapsigner(card.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !satsCards.isEmpty {
                Section("SatsCard") {
                    ForEach(satsCards) { card in
                        Button {
                            onSelectSatsCard(card)
                        } label: {
                            SatsCardRow(card: card)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onRemoveSatsCard(card.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }

            if !satsChips.isEmpty {
                Section("SatsChip") {
                    ForEach(satsChips) { card in
                        Button {
                            onSelectSatsChip(card)
                        } label: {
                            SatsChipRow(card: card)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                onRemoveSatsChip(card.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Cards")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    onScan()
                } label: {
                    Image(systemName: "wave.3.right.circle")
                        .imageScale(.large)
                }
                .disabled(isScanning)
                .accessibilityLabel("Scan NFC")
            }
        }
    }
}
