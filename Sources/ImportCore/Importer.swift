import Foundation

/// Progress reported while importing.
public struct ImportProgress: Sendable, Equatable {
    public enum Phase: Sendable, Equatable {
        /// Reading capture dates and checking free space.
        case preparing
        /// Copying and verifying files.
        case copying
    }

    public var phase: Phase
    public var completed: Int
    public var total: Int
    public var currentFileName: String?
    /// For example `2026 › 2026-10-24`, or `Ukjent dato`.
    public var currentDestination: String?

    public init(phase: Phase, completed: Int, total: Int,
                currentFileName: String? = nil, currentDestination: String? = nil) {
        self.phase = phase
        self.completed = completed
        self.total = total
        self.currentFileName = currentFileName
        self.currentDestination = currentDestination
    }

    public var fraction: Double { total == 0 ? 0 : Double(completed) / Double(total) }
}

/// A file that could not be imported, with a short reason in Norwegian for the summary.
public struct ImportFailure: Sendable, Equatable {
    public let fileName: String
    public let reason: String
}

/// The result shown on the "Ferdig" screen.
public struct ImportSummary: Sendable, Equatable {
    public enum StopReason: Sendable, Equatable {
        case cancelled
        case cardRemoved
        /// The disk with the main folder was disconnected during the import.
        case destinationRemoved
    }

    public var mainFolder: URL
    public var totalFiles = 0
    /// New files copied to the main folder.
    public var copiedCount = 0
    /// Files skipped because an identical copy already existed.
    public var alreadyImportedCount = 0
    /// New files whose day came from the file date because the metadata had none.
    public var datedFromFileCount = 0
    /// New files placed in "Ukjent dato".
    public var unknownDateCount = 0
    /// New files that were renamed, e.g. `IMG_1234 (2).JPG`, because a different file had the same name.
    public var renamedCount = 0
    public var failures: [ImportFailure] = []
    /// Years that received new files, for the "Bildene ligger i …" line.
    public var years: [Int] = []
    public var stopReason: StopReason?

    public init(mainFolder: URL) {
        self.mainFolder = mainFolder
    }
}

public enum ImportError: Error, Equatable {
    /// Not enough free space on the destination disk.
    case insufficientSpace(needed: Int64, available: Int64)
    /// The main folder is missing, for example because its disk is not connected.
    case destinationUnavailable(URL)
    /// The main folder is on the memory card itself.
    case destinationOnCard
}

/// Copies photos and videos from the card into year and date folders under the main folder.
///
/// Safety rules:
/// - The card is only read. Nothing on it is moved, changed or deleted.
/// - Existing files are never overwritten (see `DuplicateResolver`).
/// - Each file is first copied under a hidden temporary name, compared byte by byte with
///   the original, and only then given its real name. A half-copied file never appears.
public struct Importer: Sendable {
    public static let temporaryFilePrefix = ".bildeimport-"
    /// Extra free space kept on the destination disk.
    public static let safetyMargin: Int64 = 200 * 1_024 * 1_024

    private let dateResolver: CaptureDateResolver

    public init(dateResolver: CaptureDateResolver = CaptureDateResolver()) {
        self.dateResolver = dateResolver
    }

    private struct PlannedFile {
        let file: MediaFile
        let dateSource: DateSource
        let folder: URL
    }

    public func run(
        files: [MediaFile],
        cardURL: URL,
        mainFolder: URL,
        availableSpace: (@Sendable (URL) -> Int64?)? = nil,
        progress: @escaping @Sendable (ImportProgress) -> Void
    ) async throws -> ImportSummary {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: mainFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ImportError.destinationUnavailable(mainFolder)
        }
        if Self.isSameVolumeOrInside(mainFolder, cardURL) {
            throw ImportError.destinationOnCard
        }

        var summary = ImportSummary(mainFolder: mainFolder)
        summary.totalFiles = files.count

        // 1. Read dates.
        var plan: [PlannedFile] = []
        plan.reserveCapacity(files.count)
        for (index, file) in files.enumerated() {
            if Task.isCancelled {
                summary.stopReason = .cancelled
                return summary
            }
            progress(ImportProgress(phase: .preparing, completed: index, total: files.count,
                                    currentFileName: file.fileName, currentDestination: nil))
            let source = await dateResolver.dateSource(for: file)
            plan.append(PlannedFile(file: file, dateSource: source,
                                    folder: DestinationLayout.folder(for: source.day, in: mainFolder)))
        }

        // 2. Check free space, not counting files that are probably imported already.
        let needed = plan.reduce(Int64(0)) { total, item in
            DuplicateResolver.probablyAlreadyImported(fileName: item.file.fileName, size: item.file.size, folder: item.folder)
                ? total : total + item.file.size
        }
        let available = availableSpace.map { $0(mainFolder) } ?? Self.availableSpace(at: mainFolder)
        if let available, needed + Self.safetyMargin > available {
            throw ImportError.insufficientSpace(needed: needed, available: available)
        }

        // 3. Copy.
        Self.removeLeftoverTemporaryFiles(in: Set(plan.map(\.folder)), fileManager: fileManager)
        var years = Set<Int>()
        for (index, item) in plan.enumerated() {
            if Task.isCancelled {
                summary.stopReason = .cancelled
                break
            }
            progress(ImportProgress(phase: .copying, completed: index, total: plan.count,
                                    currentFileName: item.file.fileName,
                                    currentDestination: Self.describe(item.dateSource.day)))
            do {
                try fileManager.createDirectory(at: item.folder, withIntermediateDirectories: true)
                let decision = try DuplicateResolver.decide(
                    source: item.file.url,
                    fileName: item.file.fileName,
                    folder: item.folder,
                    sourceSize: item.file.size,
                    sourceModificationDate: item.file.modificationDate
                )
                switch decision {
                case .alreadyImported:
                    summary.alreadyImportedCount += 1
                case .copy(let target):
                    try Self.copyVerified(from: item.file.url, to: target, fileManager: fileManager)
                    summary.copiedCount += 1
                    if target.lastPathComponent != item.file.fileName { summary.renamedCount += 1 }
                    switch item.dateSource {
                    case .metadata(let day): years.insert(day.year)
                    case .fileDate(let day):
                        years.insert(day.year)
                        summary.datedFromFileCount += 1
                    case .unknown:
                        summary.unknownDateCount += 1
                    }
                }
            } catch {
                if !fileManager.fileExists(atPath: cardURL.path) {
                    summary.stopReason = .cardRemoved
                    break
                }
                if !fileManager.fileExists(atPath: mainFolder.path) {
                    summary.stopReason = .destinationRemoved
                    break
                }
                summary.failures.append(ImportFailure(fileName: item.file.fileName, reason: Self.describe(error)))
            }
        }
        progress(ImportProgress(phase: .copying, completed: plan.count, total: plan.count,
                                currentFileName: nil, currentDestination: nil))
        summary.years = years.sorted()
        return summary
    }

    /// Copies to a hidden temporary file, verifies it, then gives it its final name.
    /// `moveItem` fails instead of overwriting if the final name was taken meanwhile.
    static func copyVerified(from source: URL, to target: URL, fileManager: FileManager) throws {
        let temporary = target.deletingLastPathComponent()
            .appendingPathComponent("\(temporaryFilePrefix)\(UUID().uuidString)-\(target.lastPathComponent)")
        do {
            try fileManager.copyItem(at: source, to: temporary)
            guard try FileComparer.haveSameContents(source, temporary, fileManager: fileManager) else {
                throw CopyError.verificationFailed
            }
            // The copy keeps the card's modification time. Set it explicitly as well,
            // because the fast duplicate check on the next import depends on it.
            if let modified = try? fileManager.attributesOfItem(atPath: source.path)[.modificationDate] as? Date {
                try? fileManager.setAttributes([.modificationDate: modified], ofItemAtPath: temporary.path)
            }
            try fileManager.moveItem(at: temporary, to: target)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    enum CopyError: Error {
        case verificationFailed
    }

    /// Removes hidden temporary files left behind if the app was quit in the middle of a copy.
    /// Only the date folders this import writes to are checked.
    static func removeLeftoverTemporaryFiles(in folders: Set<URL>, fileManager: FileManager) {
        for folder in folders {
            guard let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { continue }
            for name in names where name.hasPrefix(temporaryFilePrefix) {
                try? fileManager.removeItem(at: folder.appendingPathComponent(name))
            }
        }
    }

    /// True when the main folder lies on the card (the card's mount point, e.g. `/Volumes/EOS_DIGITAL`).
    /// Symlinks are resolved first, so a link pointing into the card is caught too.
    static func isSameVolumeOrInside(_ folder: URL, _ cardURL: URL) -> Bool {
        let folderPath = folder.resolvingSymlinksInPath().standardizedFileURL.path
        let cardPath = cardURL.resolvingSymlinksInPath().standardizedFileURL.path
        return folderPath == cardPath || folderPath.hasPrefix(cardPath + "/")
    }

    static func describe(_ day: CaptureDay?) -> String {
        guard let day else { return DestinationLayout.unknownDateFolderName }
        return "\(day.yearFolderName) › \(day.dateFolderName)"
    }

    static func describe(_ error: Error) -> String {
        if error as? CopyError == .verificationFailed {
            return "Kopien ble ikke lik originalen."
        }
        if error is DuplicateResolver.ResolveError {
            return "Fant ikke et ledig filnavn."
        }
        return "Filen kunne ikke kopieres."
    }

    static func availableSpace(at url: URL) -> Int64? {
        #if os(macOS)
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeAvailableCapacityKey])
        if let important = values?.volumeAvailableCapacityForImportantUsage, important > 0 { return important }
        return values?.volumeAvailableCapacity.map(Int64.init)
        #else
        let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacity.map(Int64.init)
        #endif
    }
}
