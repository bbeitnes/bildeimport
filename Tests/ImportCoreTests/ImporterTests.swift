import XCTest
@testable import ImportCore

/// Returns fixed capture days by file name instead of reading real metadata.
private struct FakeDateReader: CaptureDateReading {
    let days: [String: CaptureDay]
    func metadataDay(for file: MediaFile) async -> CaptureDay? { days[file.fileName] }
}

final class ImporterTests: XCTestCase {
    private var root: URL!
    private var card: URL!
    private var mainFolder: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bildeimport-importer-\(UUID().uuidString)", isDirectory: true)
        card = root.appendingPathComponent("CARD", isDirectory: true)
        mainFolder = root.appendingPathComponent("Bilder", isDirectory: true)
        try FileManager.default.createDirectory(at: card.appendingPathComponent("DCIM/100CANON"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: mainFolder, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func put(_ name: String, _ text: String, modified: Date? = nil) throws {
        let url = card.appendingPathComponent("DCIM/100CANON/\(name)")
        try Data(text.utf8).write(to: url)
        if let modified {
            try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
        }
    }

    private func importer(_ days: [String: CaptureDay]) -> Importer {
        Importer(dateResolver: CaptureDateResolver(reader: FakeDateReader(days: days), timeZone: TimeZone(identifier: "Europe/Oslo")!))
    }

    private func runImport(_ importer: Importer) async throws -> ImportSummary {
        let files = try MediaScanner.scan(folder: card)
        return try await importer.run(
            files: files, cardURL: card, mainFolder: mainFolder,
            availableSpace: { _ in Int64.max / 2 },
            progress: { _ in }
        )
    }

    private func exists(_ relativePath: String) -> Bool {
        FileManager.default.fileExists(atPath: mainFolder.appendingPathComponent(relativePath).path)
    }

    func testImportsIntoYearAndDateFoldersAcrossYears() async throws {
        try put("IMG_0001.CR3", "raw 1")
        try put("IMG_0001.JPG", "jpg 1")
        try put("MVI_0002.MP4", "video 2")
        let days = [
            "IMG_0001.CR3": CaptureDay(year: 2025, month: 12, day: 31)!,
            "IMG_0001.JPG": CaptureDay(year: 2025, month: 12, day: 31)!,
            "MVI_0002.MP4": CaptureDay(year: 2026, month: 10, day: 24)!
        ]

        let summary = try await runImport(importer(days))

        XCTAssertEqual(summary.copiedCount, 3)
        XCTAssertEqual(summary.years, [2025, 2026])
        XCTAssertTrue(exists("2025/2025-12-31/IMG_0001.CR3"))
        XCTAssertTrue(exists("2025/2025-12-31/IMG_0001.JPG"))
        XCTAssertTrue(exists("2026/2026-10-24/MVI_0002.MP4"))
        // Originals stay on the card.
        XCTAssertTrue(FileManager.default.fileExists(atPath: card.appendingPathComponent("DCIM/100CANON/IMG_0001.CR3").path))
    }

    func testSecondImportSkipsEverything() async throws {
        try put("IMG_0001.JPG", "jpg 1")
        let days = ["IMG_0001.JPG": CaptureDay(year: 2026, month: 10, day: 24)!]

        _ = try await runImport(importer(days))
        let second = try await runImport(importer(days))

        XCTAssertEqual(second.copiedCount, 0)
        XCTAssertEqual(second.alreadyImportedCount, 1)
        XCTAssertFalse(exists("2026/2026-10-24/IMG_0001 (2).JPG"))
    }

    func testDifferentFileWithSameNameIsNotOverwritten() async throws {
        let folder = mainFolder.appendingPathComponent("2026/2026-10-24")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("older photo".utf8).write(to: folder.appendingPathComponent("IMG_0001.JPG"))
        try put("IMG_0001.JPG", "newer photo")

        let summary = try await runImport(importer(["IMG_0001.JPG": CaptureDay(year: 2026, month: 10, day: 24)!]))

        XCTAssertEqual(summary.renamedCount, 1)
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("IMG_0001.JPG"), encoding: .utf8), "older photo")
        XCTAssertEqual(try String(contentsOf: folder.appendingPathComponent("IMG_0001 (2).JPG"), encoding: .utf8), "newer photo")
    }

    func testFallsBackToFileDateThenUnknown() async throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let modified = utc.date(from: DateComponents(year: 2024, month: 7, day: 1, hour: 12))!
        let tooOld = utc.date(from: DateComponents(year: 1980, month: 1, day: 1, hour: 12))!
        try put("NODATE.JPG", "a", modified: modified)
        try put("BROKEN.JPG", "b", modified: tooOld)

        let summary = try await runImport(importer([:]))

        XCTAssertEqual(summary.datedFromFileCount, 1)
        XCTAssertEqual(summary.unknownDateCount, 1)
        XCTAssertTrue(exists("2024/2024-07-01/NODATE.JPG"))
        XCTAssertTrue(exists("Ukjent dato/BROKEN.JPG"))
    }

    func testNoTemporaryFilesLeftBehind() async throws {
        try put("IMG_0001.JPG", "jpg 1")
        _ = try await runImport(importer(["IMG_0001.JPG": CaptureDay(year: 2026, month: 10, day: 24)!]))
        let contents = try FileManager.default.contentsOfDirectory(atPath: mainFolder.appendingPathComponent("2026/2026-10-24").path)
        XCTAssertEqual(contents, ["IMG_0001.JPG"])
    }

    func testStopsWhenNotEnoughSpace() async throws {
        try put("IMG_0001.JPG", "jpg 1")
        let files = try MediaScanner.scan(folder: card)
        do {
            _ = try await importer([:]).run(files: files, cardURL: card, mainFolder: mainFolder,
                                            availableSpace: { _ in 1_000 }, progress: { _ in })
            XCTFail("Expected insufficient space")
        } catch let error as ImportError {
            guard case .insufficientSpace = error else { return XCTFail("Wrong error \(error)") }
        }
        XCTAssertFalse(exists("Ukjent dato"))
    }

    func testMainFolderOnCardIsRefused() async throws {
        let onCard = card.appendingPathComponent("Bilder")
        try FileManager.default.createDirectory(at: onCard, withIntermediateDirectories: true)
        do {
            _ = try await importer([:]).run(files: [], cardURL: card, mainFolder: onCard, progress: { _ in })
            XCTFail("Expected destinationOnCard")
        } catch let error as ImportError {
            XCTAssertEqual(error, .destinationOnCard)
        }
    }

    func testLeftoverTemporaryFileIsRemoved() async throws {
        let folder = mainFolder.appendingPathComponent("2026/2026-10-24")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("half".utf8).write(to: folder.appendingPathComponent(".bildeimport-OLD-IMG_0001.JPG"))
        try put("IMG_0001.JPG", "jpg 1")

        _ = try await runImport(importer(["IMG_0001.JPG": CaptureDay(year: 2026, month: 10, day: 24)!]))

        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path), ["IMG_0001.JPG"])
    }

    func testMissingMainFolderIsReported() async throws {
        let missing = root.appendingPathComponent("Unplugged")
        do {
            _ = try await importer([:]).run(files: [], cardURL: card, mainFolder: missing, progress: { _ in })
            XCTFail("Expected destinationUnavailable")
        } catch let error as ImportError {
            XCTAssertEqual(error, .destinationUnavailable(missing))
        }
    }
}
