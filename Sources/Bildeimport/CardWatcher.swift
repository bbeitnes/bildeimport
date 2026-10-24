import AppKit
import ImportCore

/// Watches for memory cards being inserted and removed.
@MainActor
final class CardWatcher {
    /// Called with every memory card currently mounted, whenever any disk is mounted,
    /// unmounted or renamed.
    var onChange: (([MemoryCard]) -> Void)?

    private var observers: [NSObjectProtocol] = []

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]
        for name in names {
            let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            observers.append(observer)
        }
        refresh()
    }

    func refresh() {
        onChange?(Self.mountedCards())
    }

    static func mountedCards() -> [MemoryCard] {
        let keys: [URLResourceKey] = [
            .volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsRootFileSystemKey, .volumeLocalizedNameKey
        ]
        let volumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return volumes.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return nil }
            let removable = (values.volumeIsRemovable ?? false) || (values.volumeIsEjectable ?? false)
            guard MemoryCardRules.isMemoryCard(
                volumeURL: url,
                isRemovableOrEjectable: removable,
                isRootVolume: values.volumeIsRootFileSystem ?? false
            ) else { return nil }
            return MemoryCard(volumeURL: url, name: values.volumeLocalizedName ?? url.lastPathComponent)
        }
    }
}
