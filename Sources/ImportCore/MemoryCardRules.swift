import Foundation

/// A memory card the app can import from.
public struct MemoryCard: Identifiable, Hashable, Sendable {
    public var id: URL { volumeURL }
    public let volumeURL: URL
    public let name: String

    public init(volumeURL: URL, name: String) {
        self.volumeURL = volumeURL
        self.name = name
    }
}

/// Rules for deciding whether a mounted volume is a camera memory card.
public enum MemoryCardRules {
    /// Folders cameras create at the root of a card. Finding one of these is what makes
    /// a removable disk count as a memory card, so ordinary USB drives are ignored.
    public static let cameraFolderMarkers: [String] = [
        "DCIM",                 // All still cameras (DCF standard)
        "PRIVATE/M4ROOT",       // Sony XAVC video
        "PRIVATE/AVCHD",        // Sony / Canon AVCHD video
        "AVF_INFO",             // Older Sony video
        "MP_ROOT"               // Older Sony MP4 video
    ]

    /// Returns true when the volume looks like a camera card.
    ///
    /// - Parameters:
    ///   - volumeURL: The mount point, for example `/Volumes/EOS_DIGITAL`.
    ///   - isRemovableOrEjectable: From the volume's resource values.
    ///   - isRootVolume: True for the Mac's system disk.
    public static func isMemoryCard(
        volumeURL: URL,
        isRemovableOrEjectable: Bool,
        isRootVolume: Bool,
        fileManager: FileManager = .default
    ) -> Bool {
        guard isRemovableOrEjectable, !isRootVolume else { return false }
        return cameraFolderMarkers.contains { marker in
            var isDirectory: ObjCBool = false
            let path = volumeURL.appendingPathComponent(marker).path
            return fileManager.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }
}
