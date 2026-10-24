import AppKit
import ImportCore
import Observation

/// A message shown in a dialog.
struct AlertMessage: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// Holds the app's state and runs the import. The views only read from it and call its methods.
@MainActor
@Observable
final class AppModel {
    enum Screen: Equatable {
        /// No card inserted.
        case waitingForCard
        /// More than one card inserted: the user picks one.
        case chooseCard
        /// Looking for photos and videos on the card.
        case scanning
        /// Card found and scanned: ready to press «Importer».
        case ready
        /// Copying.
        case importing
        /// Summary after the import.
        case done
        /// The card has been ejected and can be removed.
        case ejected
    }

    private(set) var screen: Screen = .waitingForCard
    private(set) var cards: [MemoryCard] = []
    private(set) var selectedCard: MemoryCard?
    private(set) var mediaFiles: [MediaFile] = []
    private(set) var progress: ImportProgress?
    private(set) var summary: ImportSummary?
    private(set) var isCancelling = false
    private(set) var copyStartedAt: Date?
    var alert: AlertMessage?

    let destination = DestinationStore()

    private let cardWatcher = CardWatcher()
    private var scanTask: Task<Void, Never>?
    private var importWork: Task<ImportSummary, Error>?
    private var activity: NSObjectProtocol?
    private var started = false

    // MARK: Cards

    func start() {
        guard !started else { return }
        started = true
        cardWatcher.onChange = { [weak self] cards in self?.cardsChanged(cards) }
        cardWatcher.start()
    }

    private func cardsChanged(_ newCards: [MemoryCard]) {
        cards = newCards
        destination.refresh()

        switch screen {
        case .importing:
            // The importer notices a removed card itself and stops safely.
            return
        case .done:
            // The card was pulled out during the import and is now back:
            // go straight to «Klar til å importere» so the rest can be fetched.
            if summary?.stopReason == .cardRemoved,
               let previous = selectedCard,
               let returned = newCards.first(where: { $0.name == previous.name }) {
                summary = nil
                select(returned)
            }
            // Otherwise stay on the summary. The eject button disappears if the card is gone.
            return
        case .waitingForCard, .chooseCard, .scanning, .ready, .ejected:
            if let selectedCard, newCards.contains(selectedCard), screen != .ejected {
                return
            }
            selectedCard = nil
            mediaFiles = []
            if newCards.count == 1 {
                select(newCards[0])
            } else if newCards.count > 1 {
                screen = .chooseCard
            } else if screen != .ejected {
                screen = .waitingForCard
            }
        }
    }

    var isSelectedCardPresent: Bool {
        guard let selectedCard else { return false }
        return cards.contains(selectedCard)
    }

    func select(_ card: MemoryCard) {
        selectedCard = card
        screen = .scanning
        scanTask?.cancel()
        scanTask = Task { [weak self] in
            let url = card.volumeURL
            let result = await Task.detached(priority: .userInitiated) {
                try? MediaScanner.scan(folder: url)
            }.value
            guard let self, !Task.isCancelled, self.selectedCard == card else { return }
            self.mediaFiles = result ?? []
            self.screen = .ready
        }
    }

    // MARK: Main folder

    func chooseDestination() {
        let panel = NSOpenPanel()
        panel.title = "Velg hovedmappe"
        panel.message = "Velg mappen bildene skal lagres i, for eksempel «Bilder». Mapper for år og dato lages automatisk inni den."
        panel.prompt = "Bruk denne mappen"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = destination.url
        guard panel.runModal() == .OK, let url = panel.url else { return }

        if let card = cards.first(where: { isInside(url, volume: $0.volumeURL) }) {
            alert = AlertMessage(
                title: "Velg en annen mappe",
                message: "Mappen ligger på minnekortet «\(card.name)». Bildene må lagres på Macen eller på en annen disk."
            )
            return
        }
        destination.choose(url)
    }

    private func isInside(_ url: URL, volume: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let volumePath = volume.standardizedFileURL.path
        return path == volumePath || path.hasPrefix(volumePath + "/")
    }

    // MARK: Import

    var canImport: Bool {
        screen == .ready && !mediaFiles.isEmpty && destination.isAvailable && isSelectedCardPresent
    }

    func startImport() {
        guard canImport, let card = selectedCard else { return }
        let files = mediaFiles
        let mainFolder = destination.url

        progress = ImportProgress(phase: .preparing, completed: 0, total: files.count)
        summary = nil
        isCancelling = false
        copyStartedAt = nil
        screen = .importing
        // Keeps the Mac from sleeping while copying.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Importerer bilder fra minnekort"
        )

        let work = Task.detached(priority: .userInitiated) {
            try await Importer().run(files: files, cardURL: card.volumeURL, mainFolder: mainFolder) { update in
                Task { @MainActor [weak self] in self?.receive(update) }
            }
        }
        importWork = work

        Task { [weak self] in
            let result = await work.result
            self?.finishImport(result)
        }
    }

    private func receive(_ update: ImportProgress) {
        guard screen == .importing else { return }
        if update.phase == .copying, copyStartedAt == nil {
            copyStartedAt = Date()
        }
        progress = update
    }

    func cancelImport() {
        isCancelling = true
        importWork?.cancel()
    }

    private func finishImport(_ result: Result<ImportSummary, Error>) {
        if let activity {
            ProcessInfo.processInfo.endActivity(activity)
        }
        activity = nil
        importWork = nil

        switch result {
        case .success(let summary):
            self.summary = summary
            screen = .done
        case .failure(let error):
            screen = isSelectedCardPresent ? .ready : .waitingForCard
            alert = Self.alert(for: error, folderName: destination.displayName)
        }
        cardWatcher.refresh()
    }

    /// Rough time left, shown as «Ca. 4 minutter igjen».
    var remainingTimeText: String? {
        guard let progress, progress.phase == .copying, let copyStartedAt,
              progress.completed >= 5, progress.completed < progress.total else { return nil }
        let elapsed = Date().timeIntervalSince(copyStartedAt)
        let remaining = elapsed / Double(progress.completed) * Double(progress.total - progress.completed)
        let minutes = Int((remaining / 60).rounded(.up))
        if minutes <= 1 { return "Under ett minutt igjen" }
        return "Ca. \(minutes) minutter igjen"
    }

    // MARK: After the import

    func ejectCard() {
        guard let card = selectedCard else { return }
        do {
            try NSWorkspace.shared.unmountAndEjectDevice(at: card.volumeURL)
            screen = .ejected
            selectedCard = nil
            mediaFiles = []
        } catch {
            alert = AlertMessage(
                title: "Kortet kunne ikke løses ut",
                message: "Lukk andre programmer som kan bruke kortet, og prøv igjen."
            )
        }
    }

    func showPhotos() {
        let folder = summary.flatMap { summary in
            summary.years.last.map { summary.mainFolder.appendingPathComponent(String(format: "%04d", $0)) }
        } ?? destination.url
        NSWorkspace.shared.open(FileManager.default.fileExists(atPath: folder.path) ? folder : destination.url)
    }

    /// From the summary back to the start, for example to import the rest after a cancel.
    func startOver() {
        summary = nil
        progress = nil
        selectedCard = nil
        screen = .waitingForCard
        cardWatcher.refresh()
    }

    // MARK: Messages

    private static func alert(for error: Error, folderName: String) -> AlertMessage {
        switch error as? ImportError {
        case .insufficientSpace(let needed, let available):
            let formatter = ByteCountFormatter()
            formatter.countStyle = .file
            return AlertMessage(
                title: "Ikke nok plass",
                message: "Bildene trenger ca. \(formatter.string(fromByteCount: needed)), men det er bare \(formatter.string(fromByteCount: available)) ledig på disken. Frigjør plass eller velg en annen mappe."
            )
        case .destinationUnavailable:
            return AlertMessage(
                title: "Finner ikke mappen",
                message: "Mappen «\(folderName)» finnes ikke lenger. Koble til disken, eller velg en annen mappe."
            )
        case .destinationOnCard:
            return AlertMessage(
                title: "Velg en annen mappe",
                message: "Mappen ligger på minnekortet. Bildene må lagres på Macen eller på en annen disk."
            )
        case .none:
            return AlertMessage(title: "Noe gikk galt", message: "Importen kunne ikke fullføres. Prøv igjen.")
        }
    }
}
