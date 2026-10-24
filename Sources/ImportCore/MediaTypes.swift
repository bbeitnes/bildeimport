import Foundation

/// The kinds of media files the app imports.
public enum MediaKind: Sendable, Equatable {
    case photo
    case rawPhoto
    case video
}

/// File extensions the app recognises as photos or videos.
///
/// The list is deliberately broad. Everything else on the card (sidecar files such as
/// `.THM`, `.XML`, `.XMP`, camera databases and system files) is skipped.
public enum MediaTypes {
    public static let photoExtensions: Set<String> = [
        "jpg", "jpeg", "jpe", "heic", "heif", "hif", "png", "tif", "tiff",
        "gif", "bmp", "webp", "avif", "jxl"
    ]

    public static let rawExtensions: Set<String> = [
        // Olympus / OM System
        "orf", "ori",
        // Canon
        "cr2", "cr3", "crw",
        // Sony
        "arw", "srf", "sr2",
        // Others, in case another camera is used later
        "dng", "nef", "nrw", "raf", "rw2", "pef", "rwl", "srw", "3fr",
        "iiq", "erf", "mrw", "x3f", "kdc", "dcr", "mos"
    ]

    public static let videoExtensions: Set<String> = [
        "mov", "mp4", "m4v", "mts", "m2ts", "m2t", "mpg", "mpeg", "avi",
        "3gp", "mkv", "wmv", "mod", "tod", "vob"
    ]

    /// Returns the media kind for a file name, or `nil` when the file should not be imported.
    public static func kind(forFileName fileName: String) -> MediaKind? {
        let ext = (fileName as NSString).pathExtension.lowercased()
        guard !ext.isEmpty else { return nil }
        if photoExtensions.contains(ext) { return .photo }
        if rawExtensions.contains(ext) { return .rawPhoto }
        if videoExtensions.contains(ext) { return .video }
        return nil
    }
}
