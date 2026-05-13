//
//  CardStore.swift
//  TapsignerDemo
//

import Foundation
import Observation
import SwiftUI
import os

@Observable
@MainActor
final class CardStore {
    private(set) var tapsigners: [TapsignerInfo] = []
    private(set) var satsCards: [SatsCardSavedInfo] = []
    private(set) var satsChips: [SatsChipInfo] = []

    @ObservationIgnored
    private let storageURL: URL

    init() {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        storageURL = documents.appendingPathComponent("saved-cards.json")
        load()
    }

    var isEmpty: Bool {
        tapsigners.isEmpty && satsCards.isEmpty && satsChips.isEmpty
    }

    func save(_ result: CardReadResult) {
        switch result {
        case .tapsigner(let info):
            upsert(info, into: &tapsigners)
        case .satsCard(let info):
            upsert(info, into: &satsCards)
        case .satsChip(let info):
            upsert(info, into: &satsChips)
        }
        persist()
    }

    func remove(tapsignerAt offsets: IndexSet) {
        tapsigners.remove(atOffsets: offsets)
        persist()
    }

    func remove(satsCardAt offsets: IndexSet) {
        satsCards.remove(atOffsets: offsets)
        persist()
    }

    func remove(satsChipAt offsets: IndexSet) {
        satsChips.remove(atOffsets: offsets)
        persist()
    }

    func removeTapsigner(id: String) {
        tapsigners.removeAll { $0.id == id }
        persist()
    }

    func removeSatsCard(id: String) {
        satsCards.removeAll { $0.id == id }
        persist()
    }

    func removeSatsChip(id: String) {
        satsChips.removeAll { $0.id == id }
        persist()
    }

    private func upsert<T: Identifiable>(_ value: T, into array: inout [T]) where T.ID == String {
        if let index = array.firstIndex(where: { $0.id == value.id }) {
            array[index] = value
        } else {
            array.append(value)
        }
    }

    private struct Payload: Codable {
        var tapsigners: [TapsignerInfo]
        var satsCards: [SatsCardSavedInfo]
        var satsChips: [SatsChipInfo]
    }

    private func load() {
        do {
            let data = try Data(contentsOf: storageURL)
            let payload = try JSONDecoder().decode(Payload.self, from: data)
            tapsigners = payload.tapsigners
            satsCards = payload.satsCards
            satsChips = payload.satsChips
            Log.ui.info(
                "Loaded cards: tapsigners=\(self.tapsigners.count) satsCards=\(self.satsCards.count) satsChips=\(self.satsChips.count)"
            )
        } catch CocoaError.fileReadNoSuchFile {
            Log.ui.debug("No saved cards file yet")
        } catch let error as NSError where error.code == NSFileReadNoSuchFileError {
            Log.ui.debug("No saved cards file yet")
        } catch {
            Log.ui.error("Failed to load cards: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func persist() {
        do {
            let payload = Payload(
                tapsigners: tapsigners,
                satsCards: satsCards,
                satsChips: satsChips
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(payload)
            try data.write(to: storageURL, options: .atomic)
            Log.ui.info("Persisted cards to disk")
        } catch {
            Log.ui.error("Failed to save cards: \(error.localizedDescription, privacy: .public)")
        }
    }
}
