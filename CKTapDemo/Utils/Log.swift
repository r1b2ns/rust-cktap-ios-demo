//
//  Log.swift
//  TapsignerDemo
//

import Foundation
import os

#if DEBUG
nonisolated enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "br.com.zeroSixteen.TapsignerDemo"

    static let nfc = Logger(subsystem: subsystem, category: "NFC")
    static let cktap = Logger(subsystem: subsystem, category: "CKTap")
    static let ui = Logger(subsystem: subsystem, category: "UI")
}
#else
nonisolated enum Log {
    static let subsystem = Bundle.main.bundleIdentifier ?? "br.com.zeroSixteen.TapsignerDemo"

    static let nfc = Logger(OSLog.disabled)
    static let cktap = Logger(OSLog.disabled)
    static let ui = Logger(OSLog.disabled)
}
#endif

extension Data {
    func hexEncodedString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }
}
