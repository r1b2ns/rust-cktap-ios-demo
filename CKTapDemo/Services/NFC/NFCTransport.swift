//
//  NFCTransport.swift
//  TapsignerDemo
//

import CKTap
@preconcurrency import CoreNFC
import Foundation
import os

final class NFCTransport: NSObject, CkTransport, @unchecked Sendable {

    private let tag: NFCISO7816Tag

    init(tag: NFCISO7816Tag) {
        self.tag = tag
        Log.nfc.debug("NFCTransport initialized")
    }

    func transmitApdu(commandApdu: Data) throws -> Data {
        let start = Date()
        Log.nfc.debug(
            "APDU -> (len: \(commandApdu.count)) \(commandApdu.hexEncodedString(), privacy: .public)"
        )

        guard let iso7816Apdu = NFCISO7816APDU(data: commandApdu) else {
            Log.nfc.error(
                "Failed to construct NFCISO7816APDU from data (len: \(commandApdu.count))"
            )
            throw CkTapError.Transport(msg: "Invalid APDU data")
        }

        var responseData: Data?
        var responseError: Swift.Error?
        let semaphore = DispatchSemaphore(value: 0)

        tag.sendCommand(apdu: iso7816Apdu) { data, sw1, sw2, error in
            if let error {
                Log.nfc.error("sendCommand error: \(error.localizedDescription, privacy: .public)")
                responseError = error
            } else {
                var response = data
                response.append(sw1)
                response.append(sw2)
                Log.nfc.debug(
                    "APDU <- (len: \(response.count), sw=\(String(format: "%02X%02X", sw1, sw2), privacy: .public)) \(response.hexEncodedString(), privacy: .public)"
                )
                responseData = response
            }
            semaphore.signal()
        }

        let waitResult = semaphore.wait(timeout: .now() + 15.0)
        if waitResult == .timedOut {
            Log.nfc.error("APDU wait timed out after 15s")
        }

        if let responseError {
            throw CkTapError.Transport(msg: responseError.localizedDescription)
        }

        guard let responseData else {
            throw CkTapError.Transport(msg: "NFC command timed out or returned no data.")
        }

        let sw = responseData.suffix(2)
        if sw != Data([0x90, 0x00]) {
            Log.nfc.warning(
                "APDU SW not OK: \(sw.hexEncodedString(), privacy: .public)"
            )
        }

        let elapsed = Date().timeIntervalSince(start)
        Log.nfc.debug("APDU round-trip: \(String(format: "%.2f", elapsed))s")
        return responseData
    }
}
