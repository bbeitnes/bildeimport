import Foundation

/// One photo or video found on the card.
public struct MediaFile: Hashable, Sendable {
    public let url: URL
    public let kind: MediaKind
    public let size: Int64
    public let modificationDate: Date?

    public init(url: URL, kind: MediaKind, size: Int64, modificationDate: Date?) {
        self.url = url
        self.kind = kind
        self.size = size
        self.modificationDate = modificationDate
    }

    public var fileName: String { url.lastPathComponent }
}

/// Finds all photos and videos on a card, including in subfolders.
public enum MediaScanner {
    public static func scan(folder: URL, fileManager: FileManager = .default) throws -> [MediaFile] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = fileManager.enumerator(
            at: folder,
            includingPropertiesForKeys: keys,
            // Hidden files include the "._IMG_0001.JPG" files macOS leaves on FAT cards.
            options: [.skipsHiddenFiles]
        ) else {
            throw ScanError.cannotRead(folder)
        }

        var files: [MediaFile] = []
        for case let url as URL in enumerator {
            let name = url.lastPathComponent
            if name.hasPrefix(".") { continue }
            guard let kind = MediaTypes.kind(forFileName: name) else { continue }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }
            files.append(MediaFile(
                url: url,
                kind: kind,
                size: Int64(values?.fileSize ?? 0),
                modificationDate: values?.contentModificationDate
            ))
        }
        // Stable order: oldest file names first, as the camera numbered them.
        return files.sorted { $0.url.path.localizedStandardCompare($1.url.path) == .orderedAscending }
    }

    public enum ScanError: Error, Equatable {
        case cannotRead(URL)
    }
}
