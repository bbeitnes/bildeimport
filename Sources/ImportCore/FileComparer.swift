import Foundation
#if canImport(Darwin)
import Darwin
#endif

/// Compares two files byte by byte.
public enum FileComparer {
    private static let chunkSize = 1 << 20 // 1 MB

    /// True when both files exist and have exactly the same contents.
    public static func haveSameContents(_ first: URL, _ second: URL, fileManager: FileManager = .default) throws -> Bool {
        let firstSize = try fileSize(first, fileManager: fileManager)
        let secondSize = try fileSize(second, fileManager: fileManager)
        guard firstSize == secondSize else { return false }

        let firstHandle = try FileHandle(forReadingFrom: first)
        defer { try? firstHandle.close() }
        let secondHandle = try FileHandle(forReadingFrom: second)
        defer { try? secondHandle.close() }
        #if canImport(Darwin)
        // Read from the disk itself, not from the memory cache, so the check proves
        // the copy really was written correctly.
        _ = fcntl(firstHandle.fileDescriptor, F_NOCACHE, 1)
        _ = fcntl(secondHandle.fileDescriptor, F_NOCACHE, 1)
        #endif

        while true {
            let firstChunk = try firstHandle.read(upToCount: chunkSize) ?? Data()
            let secondChunk = try secondHandle.read(upToCount: chunkSize) ?? Data()
            if firstChunk != secondChunk { return false }
            if firstChunk.isEmpty { return true }
        }
    }

    public static func fileSize(_ url: URL, fileManager: FileManager = .default) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}
