import Combine
import Foundation
import SwiftUI
import os

@MainActor
final class CardStore: ObservableObject {
    @Published private(set) var tapsigners: [TapsignerInfo] = []
    @Published private(set) var satsCards: [SatsCardSavedInfo] = []
    @Published private(set) var satsChips: [SatsChipInfo] = []

    private let storageURL: URL

    init() {
        let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        storageURL = documents.appendingPathComponent("saved-cards.json")
        load()
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
