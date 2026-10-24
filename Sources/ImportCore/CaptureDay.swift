import Foundation

/// The calendar day a photo or video was taken. Only the day matters for the folder layout,
/// so the time of day is not stored.
public struct CaptureDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Creates a day if the values form a real, plausible date.
    /// Years before 1990 or far in the future are treated as a wrong camera clock.
    public init?(year: Int, month: Int, day: Int, now: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        guard (1990...(calendar.component(.year, from: now) + 1)).contains(year),
              (1...12).contains(month),
              (1...31).contains(day) else { return nil }
        // Rejects impossible dates such as 2026-02-30.
        let components = DateComponents(year: year, month: month, day: day)
        guard let date = calendar.date(from: components),
              calendar.component(.day, from: date) == day,
              calendar.component(.month, from: date) == month else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day a moment in time falls on, in the given time zone (the Mac's by default).
    public init?(date: Date, timeZone: TimeZone = .current, now: Date = Date()) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
        self.init(year: year, month: month, day: day, now: now)
    }

    /// Parses the start of an EXIF date such as `2026:10:24 14:03:11`,
    /// or an ISO date such as `2026-10-24T00:30:12+02:00`.
    /// The written date is used as is, because cameras record their own local time.
    public init?(dateString: String, now: Date = Date()) {
        let trimmed = dateString.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 10 else { return nil }
        let datePart = trimmed.prefix(10)
        let pieces = datePart.split(whereSeparator: { $0 == ":" || $0 == "-" })
        guard pieces.count == 3,
              let year = Int(pieces[0]), let month = Int(pieces[1]), let day = Int(pieces[2]) else {
            return nil
        }
        self.init(year: year, month: month, day: day, now: now)
    }

    /// Year folder name, for example `2026`.
    public var yearFolderName: String { String(format: "%04d", year) }

    /// Date folder name, for example `2026-10-24`.
    public var dateFolderName: String { String(format: "%04d-%02d-%02d", year, month, day) }

    public var description: String { dateFolderName }

    public static func < (lhs: CaptureDay, rhs: CaptureDay) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

/// Where the date of a file came from. Shown in the summary.
public enum DateSource: Sendable, Equatable {
    /// The capture date from the photo's or video's own metadata.
    case metadata(CaptureDay)
    /// The file's modification date on the card, used when metadata had no date.
    case fileDate(CaptureDay)
    /// No usable date at all. The file goes to the "Ukjent dato" folder.
    case unknown

    public var day: CaptureDay? {
        switch self {
        case .metadata(let day), .fileDate(let day): return day
        case .unknown: return nil
        }
    }
}
