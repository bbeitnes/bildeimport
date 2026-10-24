import Foundation
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Reads the capture date stored inside a photo or video.
public protocol CaptureDateReading: Sendable {
    func metadataDay(for file: MediaFile) async -> CaptureDay?
}

/// Decides which day a file belongs to:
/// 1. The capture date from the file's metadata.
/// 2. Otherwise the file's modification date on the card.
/// 3. Otherwise unknown.
public struct CaptureDateResolver: Sendable {
    private let reader: CaptureDateReading
    private let timeZone: TimeZone

    public init(reader: CaptureDateReading = SystemCaptureDateReader(), timeZone: TimeZone = .current) {
        self.reader = reader
        self.timeZone = timeZone
    }

    public func dateSource(for file: MediaFile) async -> DateSource {
        if let day = await reader.metadataDay(for: file) {
            return .metadata(day)
        }
        if let modified = file.modificationDate, let day = CaptureDay(date: modified, timeZone: timeZone) {
            return .fileDate(day)
        }
        return .unknown
    }
}

/// Reads capture dates with Apple's own frameworks (ImageIO for photos, AVFoundation for video).
public struct SystemCaptureDateReader: CaptureDateReading {
    public init() {}

    public func metadataDay(for file: MediaFile) async -> CaptureDay? {
        switch file.kind {
        case .photo, .rawPhoto:
            return Self.photoDay(url: file.url)
        case .video:
            if let day = Self.sonyXMLDay(videoURL: file.url) { return day }
            return await Self.videoDay(url: file.url)
        }
    }

    // MARK: Photos

    /// EXIF fields in order of preference. The written camera time is used as is,
    /// because that is the local time where the photo was taken.
    static func photoDay(url: URL) -> CaptureDay? {
        #if canImport(ImageIO)
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, options) as? [CFString: Any] else {
            return nil
        }
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let candidates: [Any?] = [
            exif[kCGImagePropertyExifDateTimeOriginal],
            exif[kCGImagePropertyExifDateTimeDigitized],
            tiff[kCGImagePropertyTIFFDateTime]
        ]
        for case let value as String in candidates {
            if let day = CaptureDay(dateString: value) { return day }
        }
        return nil
        #else
        return nil
        #endif
    }

    // MARK: Video

    /// Sony cameras write an XML file next to each XAVC clip (C0001.MP4 → C0001M01.XML)
    /// holding the exact local recording time with time zone, for example
    /// `<CreationDate value="2026-10-24T00:30:12+02:00"/>`. That is the most reliable date.
    static func sonyXMLDay(videoURL: URL) -> CaptureDay? {
        let stem = videoURL.deletingPathExtension().lastPathComponent
        let folder = videoURL.deletingLastPathComponent()
        for candidate in ["\(stem)M01.XML", "\(stem)M01.xml"] {
            let xmlURL = folder.appendingPathComponent(candidate)
            guard let data = try? Data(contentsOf: xmlURL),
                  let text = String(data: data, encoding: .utf8) else { continue }
            if let day = parseSonyXML(text) { return day }
        }
        return nil
    }

    static func parseSonyXML(_ text: String) -> CaptureDay? {
        guard let range = text.range(of: "CreationDate value=\"") else { return nil }
        let rest = text[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return CaptureDay(dateString: String(rest[..<end]))
    }

    /// Videos usually store the recording moment in UTC. It is converted to the Mac's
    /// time zone, so a clip filmed at 00:30 Norwegian time lands on the right day.
    /// When the file carries a local date with time zone, that date is used directly.
    static func videoDay(url: URL) async -> CaptureDay? {
        #if canImport(AVFoundation)
        let asset = AVURLAsset(url: url)
        if let items = try? await asset.load(.metadata) {
            for item in items where item.identifier == .quickTimeMetadataCreationDate {
                if let text = try? await item.load(.stringValue), let day = CaptureDay(dateString: text) {
                    return day
                }
            }
        }
        if let item = try? await asset.load(.creationDate),
           let date = try? await item.load(.dateValue),
           let day = CaptureDay(date: date) {
            return day
        }
        return nil
        #else
        return nil
        #endif
    }
}
