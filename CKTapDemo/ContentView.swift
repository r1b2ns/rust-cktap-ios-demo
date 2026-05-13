//
//  ContentView.swift
//  TapsignerDemo
//
//  Created by Rubens Machion on 12/05/26.
//

import SwiftUI

struct ContentView: View {
    @State private var reader = CardReader()
    @State private var store = CardStore()

    var body: some View {
        rootContent
            .alert(reader.pinAlertTitle, isPresented: $reader.isAskingPIN) {
                SecureField("CVC / PIN", text: $reader.pin)
                    .textContentType(.password)
                    .keyboardType(.numberPad)

                Button("Cancel", role: .cancel) {}
                Button(reader.pinAlertConfirm) {
                    reader.scan()
                }
            } message: {
                Text(reader.pinAlertMessage)
            }
            .alert(
                "Tapsigner not initialized",
                isPresented: Binding(
                    get: { reader.pendingUninitialized != nil },
                    set: { if !$0 { reader.pendingUninitialized = nil } }
                ),
                presenting: reader.pendingUninitialized
            ) { info in
                Button("No", role: .cancel) {
                    reader.saveUninitialized(info)
                }
                Button("Yes") {
                    reader.startInitFlow()
                }
            } message: { _ in
                Text("Do you want to init now?")
            }
            .alert(
                reader.lastResult?.title ?? "Card",
                isPresented: Binding(
                    get: { reader.lastResult != nil },
                    set: { if !$0 { reader.lastResult = nil } }
                ),
                presenting: reader.lastResult
            ) { _ in
                Button("OK") { reader.lastResult = nil }
            } message: { result in
                Text(result.displayText)
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { reader.errorMessage != nil },
                    set: { if !$0 { reader.errorMessage = nil } }
                ),
                presenting: reader.errorMessage
            ) { _ in
                Button("OK") { reader.errorMessage = nil }
            } message: { message in
                Text(message)
            }
            .onChange(of: reader.lastResult) { _, newValue in
                if let newValue {
                    store.save(newValue)
                }
            }
    }

    @ViewBuilder
    private var rootContent: some View {
        if store.isEmpty {
            EmptyStateView(reader: reader)
        } else {
            SavedCardsView(reader: reader, store: store)
        }
    }
}

// MARK: - Empty state

private struct EmptyStateView: View {
    let reader: CardReader

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
                reader.startScan()
            } label: {
                Label("Scan NFC", systemImage: "dot.radiowaves.left.and.right")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(reader.isScanning)
        }
        .padding()
    }
}

// MARK: - List

private struct SavedCardsView: View {
    let reader: CardReader
    let store: CardStore

    var body: some View {
        NavigationStack {
            List {
                if !store.tapsigners.isEmpty {
                    Section("Tapsigner") {
                        ForEach(store.tapsigners) { card in
                            TapsignerRow(card: card)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.removeTapsigner(id: card.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                if !store.satsCards.isEmpty {
                    Section("SatsCard") {
                        ForEach(store.satsCards) { card in
                            SatsCardRow(card: card)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.removeSatsCard(id: card.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                }

                if !store.satsChips.isEmpty {
                    Section("SatsChip") {
                        ForEach(store.satsChips) { card in
                            SatsChipRow(card: card)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        store.removeSatsChip(id: card.id)
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
                        reader.startScan()
                    } label: {
                        Image(systemName: "wave.3.right.circle")
                            .imageScale(.large)
                    }
                    .disabled(reader.isScanning)
                    .accessibilityLabel("Scan NFC")
                }
            }
        }
    }
}

// MARK: - Rows

private struct TapsignerRow: View {
    let card: TapsignerInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(card.cardIdent)
                    .font(.headline)
                    .truncationMode(.middle)
                    .lineLimit(1)
                
                if !card.isInitialized {
                    Spacer()
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
        .padding(.vertical, 2)
    }
}

private struct SatsCardRow: View {
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

private struct SatsChipRow: View {
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

#Preview {
    ContentView()
}
