import Foundation

/// Wraps `NFCTagReaderSession.readingAvailable` so view-models don't have to
/// import CoreNFC directly.
nonisolated enum NFCReaderAvailability {
    static var isReadingAvailable: Bool {
        #if canImport(CoreNFC)
        return _CoreNFCAvailability.isReadingAvailable
        #else
        return false
        #endif
    }
}

#if canImport(CoreNFC)
import CoreNFC

private enum _CoreNFCAvailability {
    static var isReadingAvailable: Bool { NFCTagReaderSession.readingAvailable }
}
#endif
