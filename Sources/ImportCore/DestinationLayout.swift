import Foundation

/// Where a file ends up under the chosen main folder:
///
///     <main folder>/2026/2026-10-24/IMG_1235.HEIC
///     <main folder>/Ukjent dato/file_without_date.jpg
public enum DestinationLayout {
    /// Folder name shown to the user, so it is in Norwegian.
    public static let unknownDateFolderName = "Ukjent dato"

    public static func folder(for day: CaptureDay?, in mainFolder: URL) -> URL {
        guard let day else {
            return mainFolder.appendingPathComponent(unknownDateFolderName, isDirectory: true)
        }
        return mainFolder
            .appendingPathComponent(day.yearFolderName, isDirectory: true)
            .appendingPathComponent(day.dateFolderName, isDirectory: true)
    }
}

/// What to do with one file from the card.
public enum PlacementDecision: Equatable, Sendable {
    /// Copy the file to this new, free location.
    case copy(to: URL)
    /// An identical copy already exists here, so the file is skipped.
    case alreadyImported(at: URL)
}

/// Finds a safe destination name without ever overwriting an existing file.
///
/// - Same name, same size and same modification time already in the folder: the file is
///   skipped at once, without reading it. The importer keeps the card's modification time
///   when copying, so this matches every file imported before and makes re-imports fast.
/// - Same name and size but another modification time: the contents are compared byte by
///   byte, and the file is skipped if they are identical.
/// - Same name but different contents: the copy gets a number, `IMG_1234 (2).JPG`,
///   then `(3)` and so on. Numbered files are checked the same way,
///   so importing the same card twice never creates extra copies.
public enum DuplicateResolver {
    public static let maximumNumber = 9_999
    /// FAT-formatted cards store modification times in 2-second steps.
    public static let modificationTimeTolerance: TimeInterval = 2

    public static func decide(
        source: URL,
        fileName: String,
        folder: URL,
        sourceSize: Int64? = nil,
        sourceModificationDate: Date? = nil,
        fileManager: FileManager = .default
    ) throws -> PlacementDecision {
        let size = try sourceSize ?? FileComparer.fileSize(source, fileManager: fileManager)
        for candidate in candidateNames(for: fileName) {
            let target = folder.appendingPathComponent(candidate, isDirectory: false)
            guard let attributes = try? fileManager.attributesOfItem(atPath: target.path) else {
                if fileManager.fileExists(atPath: target.path) { continue } // Exists but unreadable: never touch it.
                return .copy(to: target)
            }
            let existingSize = (attributes[.size] as? NSNumber)?.int64Value ?? -1
            guard existingSize == size else { continue } // Different size: certainly a different file.

            if let sourceDate = sourceModificationDate,
               let existingDate = attributes[.modificationDate] as? Date,
               abs(existingDate.timeIntervalSince(sourceDate)) <= modificationTimeTolerance {
                return .alreadyImported(at: target)
            }
            if try FileComparer.haveSameContents(source, target, fileManager: fileManager) {
                return .alreadyImported(at: target)
            }
        }
        throw ResolveError.noFreeName(fileName)
    }

    /// Quick estimate without reading file contents, used before importing to check
    /// free space: true when a file with the same name and size already exists.
    public static func probablyAlreadyImported(
        fileName: String,
        size: Int64,
        folder: URL,
        fileManager: FileManager = .default
    ) -> Bool {
        let target = folder.appendingPathComponent(fileName, isDirectory: false)
        guard let existingSize = try? FileComparer.fileSize(target, fileManager: fileManager) else { return false }
        return existingSize == size
    }

    /// `IMG_1234.JPG`, `IMG_1234 (2).JPG`, `IMG_1234 (3).JPG`, …
    public static func candidateNames(for fileName: String) -> AnySequence<String> {
        let nsName = fileName as NSString
        let ext = nsName.pathExtension
        let stem = nsName.deletingPathExtension
        return AnySequence(
            sequence(first: 1, next: { $0 < maximumNumber ? $0 + 1 : nil }).lazy.map { number -> String in
                if number == 1 { return fileName }
                return ext.isEmpty ? "\(stem) (\(number))" : "\(stem) (\(number)).\(ext)"
            }
        )
    }

    public enum ResolveError: Error, Equatable {
        case noFreeName(String)
    }
}
