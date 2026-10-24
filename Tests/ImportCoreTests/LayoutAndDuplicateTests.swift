import XCTest
@testable import ImportCore

final class LayoutAndDuplicateTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("bildeimport-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ text: String, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    // MARK: Folder layout

    func testFolderForKnownDay() throws {
        let day = try XCTUnwrap(CaptureDay(year: 2026, month: 10, day: 24))
        let folder = DestinationLayout.folder(for: day, in: root)
        XCTAssertEqual(folder.pathComponents.suffix(2), ["2026", "2026-10-24"])
    }

    func testFolderForUnknownDay() {
        let folder = DestinationLayout.folder(for: nil, in: root)
        XCTAssertEqual(folder.lastPathComponent, "Ukjent dato")
        XCTAssertEqual(folder.deletingLastPathComponent().standardizedFileURL, root.standardizedFileURL)
    }

    // MARK: Duplicates

    func testCandidateNames() {
        let names = Array(DuplicateResolver.candidateNames(for: "IMG_1234.JPG").prefix(3))
        XCTAssertEqual(names, ["IMG_1234.JPG", "IMG_1234 (2).JPG", "IMG_1234 (3).JPG"])
    }

    func testFreeNameIsUsedDirectly() throws {
        let source = root.appendingPathComponent("card/IMG_1.JPG")
        try write("A", to: source)
        let folder = root.appendingPathComponent("dest")
        let decision = try DuplicateResolver.decide(source: source, fileName: "IMG_1.JPG", folder: folder)
        XCTAssertEqual(decision, .copy(to: folder.appendingPathComponent("IMG_1.JPG")))
    }

    func testIdenticalFileIsSkipped() throws {
        let source = root.appendingPathComponent("card/IMG_1.JPG")
        let existing = root.appendingPathComponent("dest/IMG_1.JPG")
        try write("same", to: source)
        try write("same", to: existing)
        let decision = try DuplicateResolver.decide(source: source, fileName: "IMG_1.JPG", folder: existing.deletingLastPathComponent())
        XCTAssertEqual(decision, .alreadyImported(at: existing))
    }

    func testDifferentFileWithSameNameGetsNumber() throws {
        let source = root.appendingPathComponent("card/IMG_1.JPG")
        let existing = root.appendingPathComponent("dest/IMG_1.JPG")
        try write("new photo", to: source)
        try write("old photo", to: existing)
        let folder = existing.deletingLastPathComponent()
        let decision = try DuplicateResolver.decide(source: source, fileName: "IMG_1.JPG", folder: folder)
        XCTAssertEqual(decision, .copy(to: folder.appendingPathComponent("IMG_1 (2).JPG")))
    }

    func testIdenticalNumberedCopyIsSkippedOnSecondImport() throws {
        let source = root.appendingPathComponent("card/IMG_1.JPG")
        let folder = root.appendingPathComponent("dest")
        try write("new photo", to: source)
        try write("old photo", to: folder.appendingPathComponent("IMG_1.JPG"))
        try write("new photo", to: folder.appendingPathComponent("IMG_1 (2).JPG"))
        let decision = try DuplicateResolver.decide(source: source, fileName: "IMG_1.JPG", folder: folder)
        XCTAssertEqual(decision, .alreadyImported(at: folder.appendingPathComponent("IMG_1 (2).JPG")))
    }

    // MARK: Scanning

    func testScannerFindsMediaInSubfoldersAndSkipsOtherFiles() throws {
        let card = root.appendingPathComponent("card")
        try write("x", to: card.appendingPathComponent("DCIM/100CANON/IMG_0001.CR3"))
        try write("x", to: card.appendingPathComponent("DCIM/100CANON/IMG_0001.JPG"))
        try write("x", to: card.appendingPathComponent("DCIM/100CANON/MVI_0002.MP4"))
        try write("x", to: card.appendingPathComponent("DCIM/100CANON/MVI_0002.THM"))
        try write("x", to: card.appendingPathComponent("DCIM/100OLYMP/P1010001.ORF"))
        try write("x", to: card.appendingPathComponent("PRIVATE/M4ROOT/CLIP/C0001.MP4"))
        try write("x", to: card.appendingPathComponent("PRIVATE/M4ROOT/CLIP/C0001M01.XML"))
        try write("x", to: card.appendingPathComponent("DCIM/100CANON/._IMG_0001.JPG"))
        try write("x", to: card.appendingPathComponent(".Trashes/IMG_9999.JPG"))

        let names = try MediaScanner.scan(folder: card).map(\.fileName).sorted()
        XCTAssertEqual(names, ["C0001.MP4", "IMG_0001.CR3", "IMG_0001.JPG", "MVI_0002.MP4", "P1010001.ORF"])
    }

    func testMediaKinds() {
        XCTAssertEqual(MediaTypes.kind(forFileName: "P1010001.ORF"), .rawPhoto)
        XCTAssertEqual(MediaTypes.kind(forFileName: "DSC01234.ARW"), .rawPhoto)
        XCTAssertEqual(MediaTypes.kind(forFileName: "IMG_0001.cr3"), .rawPhoto)
        XCTAssertEqual(MediaTypes.kind(forFileName: "IMG_0001.HEIC"), .photo)
        XCTAssertEqual(MediaTypes.kind(forFileName: "00001.MTS"), .video)
        XCTAssertNil(MediaTypes.kind(forFileName: "MVI_0002.THM"))
        XCTAssertNil(MediaTypes.kind(forFileName: "C0001M01.XML"))
        XCTAssertNil(MediaTypes.kind(forFileName: "README"))
    }

    func testMemoryCardRequiresCameraFolder() throws {
        let card = root.appendingPathComponent("EOS_DIGITAL")
        let usbDrive = root.appendingPathComponent("USB")
        try FileManager.default.createDirectory(at: card.appendingPathComponent("DCIM"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: usbDrive.appendingPathComponent("Documents"), withIntermediateDirectories: true)

        XCTAssertTrue(MemoryCardRules.isMemoryCard(volumeURL: card, isRemovableOrEjectable: true, isRootVolume: false))
        XCTAssertFalse(MemoryCardRules.isMemoryCard(volumeURL: usbDrive, isRemovableOrEjectable: true, isRootVolume: false))
        XCTAssertFalse(MemoryCardRules.isMemoryCard(volumeURL: card, isRemovableOrEjectable: false, isRootVolume: false))
        XCTAssertFalse(MemoryCardRules.isMemoryCard(volumeURL: card, isRemovableOrEjectable: true, isRootVolume: true))
    }
}
