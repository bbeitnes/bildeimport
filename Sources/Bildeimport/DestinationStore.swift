import Foundation
import Observation

/// Remembers the main folder between imports.
@MainActor
@Observable
final class DestinationStore {
    private enum Keys {
        static let bookmark = "mainFolderBookmark"
        static let path = "mainFolderPath"
        static let volumeName = "mainFolderVolumeName"
    }

    private let defaults: UserDefaults

    /// The chosen main folder, for example `~/Pictures` (shown as «Bilder» in Finder).
    private(set) var url: URL
    /// The name of the disk the folder is on, used in the "not connected" message.
    private(set) var volumeName: String
    /// False when the folder cannot be found, usually because its external disk is unplugged.
    private(set) var isAvailable = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let resolved = Self.resolveSavedURL(defaults: defaults)
        url = resolved ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures", isDirectory: true)
        volumeName = defaults.string(forKey: Keys.volumeName) ?? ""
        refresh()
    }

    /// The folder name as Finder shows it, so `Pictures` appears as «Bilder».
    var displayName: String {
        FileManager.default.displayName(atPath: url.path)
    }

    func choose(_ newURL: URL) {
        url = newURL
        volumeName = (try? newURL.resourceValues(forKeys: [.volumeLocalizedNameKey]))?.volumeLocalizedName ?? ""
        if let bookmark = try? newURL.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
            defaults.set(bookmark, forKey: Keys.bookmark)
        }
        defaults.set(newURL.path, forKey: Keys.path)
        defaults.set(volumeName, forKey: Keys.volumeName)
        refresh()
    }

    /// Checks again whether the folder is reachable. Called whenever a disk comes or goes.
    func refresh() {
        if !isReachable(url), let resolved = Self.resolveSavedURL(defaults: defaults) {
            url = resolved
        }
        isAvailable = isReachable(url)
        if isAvailable, let name = (try? url.resourceValues(forKeys: [.volumeLocalizedNameKey]))?.volumeLocalizedName {
            volumeName = name
        }
    }

    private func isReachable(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private static func resolveSavedURL(defaults: UserDefaults) -> URL? {
        if let bookmark = defaults.data(forKey: Keys.bookmark) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: [.withoutUI, .withoutMounting],
                                  relativeTo: nil, bookmarkDataIsStale: &isStale) {
                return url
            }
        }
        if let path = defaults.string(forKey: Keys.path) {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return nil
    }
}
