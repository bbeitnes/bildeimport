import ImportCore
import SwiftUI

/// 4. «Ferdig!» – summary with buttons to eject the card and show the photos.
struct DoneView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let summary = model.summary {
            VStack(alignment: .leading, spacing: 18) {
                header(summary)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(lines(summary), id: \.text) { line in
                        Text(line.text)
                            .font(.system(size: 19, weight: line.isMain ? .semibold : .regular))
                            .foregroundStyle(line.isWarning ? Color(red: 0.36, green: 0.24, blue: 0.0) : .primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.vertical, 18)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))

                if let location = locationText(summary) {
                    Text(location)
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)

                HStack(spacing: 16) {
                    if model.isSelectedCardPresent {
                        Button("Løs ut minnekortet") { model.ejectCard() }
                            .buttonStyle(PrimaryButtonStyle())
                            .keyboardShortcut(.defaultAction)
                    } else {
                        Button("Start på nytt") { model.startOver() }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    Button("Vis bildene") { model.showPhotos() }
                        .buttonStyle(SecondaryButtonStyle(fontSize: 21, fillsWidth: true))
                        .frame(minHeight: 64)
                }
            }
        }
    }

    @ViewBuilder
    private func header(_ summary: ImportSummary) -> some View {
        let complete = summary.stopReason == nil && summary.failures.isEmpty
        HStack(spacing: 16) {
            Image(systemName: complete ? "checkmark.circle" : "exclamationmark.circle")
                .font(.system(size: 46))
                .foregroundStyle(complete ? Theme.success : Theme.warning)
                .accessibilityHidden(true)
            Text(complete ? "Ferdig!" : "Importen ble ikke helt fullført")
                .font(Theme.title)
        }
    }

    private struct Line {
        let text: String
        var isMain = false
        var isWarning = false
    }

    private func lines(_ summary: ImportSummary) -> [Line] {
        var result: [Line] = []

        switch summary.stopReason {
        case .cancelled:
            result.append(Line(text: "Du avbrøt importen. Det som ble kopiert, er beholdt.", isWarning: true))
        case .cardRemoved:
            result.append(Line(text: "Minnekortet ble tatt ut før importen var ferdig. Sett det inn igjen, så kan du trykke «Importer» for å hente resten.", isWarning: true))
        case .destinationRemoved:
            result.append(Line(text: "Disken med bildemappen ble koblet fra før importen var ferdig. Koble den til igjen og importer på nytt for å hente resten.", isWarning: true))
        case .none:
            break
        }

        if summary.copiedCount == 0 && summary.alreadyImportedCount > 0 && summary.stopReason == nil {
            result.append(Line(text: "Ingen nye bilder. Alt på kortet var importert fra før.", isMain: true))
        } else {
            result.append(Line(
                text: "\(Format.count(summary.copiedCount, "nytt bilde eller video", "nye bilder og videoer")) er kopiert.",
                isMain: true
            ))
        }
        if summary.alreadyImportedCount > 0 {
            result.append(Line(text: "\(Format.number(summary.alreadyImportedCount)) var allerede importert og ble hoppet over."))
        }
        if summary.datedFromFileCount > 0 {
            result.append(Line(text: "\(Format.count(summary.datedFromFileCount, "fil", "filer")) fikk dato fra filen, fordi opptaksdato manglet."))
        }
        if summary.renamedCount > 0 {
            result.append(Line(text: "\(Format.count(summary.renamedCount, "fil", "filer")) fikk et nummer i navnet, fordi en annen fil hadde samme navn."))
        }
        if summary.unknownDateCount > 0 {
            result.append(Line(
                text: "\(Format.count(summary.unknownDateCount, "fil", "filer")) uten dato ligger i mappen «\(DestinationLayout.unknownDateFolderName)».",
                isWarning: true
            ))
        }
        if !summary.failures.isEmpty {
            let names = summary.failures.prefix(3).map(\.fileName).joined(separator: ", ")
            let more = summary.failures.count > 3 ? " med flere" : ""
            result.append(Line(
                text: "\(Format.count(summary.failures.count, "fil", "filer")) kunne ikke kopieres: \(names)\(more). Originalene ligger fortsatt på kortet.",
                isWarning: true
            ))
        }
        return result
    }

    /// «Bildene ligger i Bilder › 2025 og Bilder › 2026.»
    private func locationText(_ summary: ImportSummary) -> String? {
        guard !summary.years.isEmpty else { return nil }
        let name = model.destination.displayName
        let folders = summary.years.map { "\(name) › \(String(format: "%04d", $0))" }
        let joined: String
        if folders.count == 1 {
            joined = folders[0]
        } else {
            joined = folders.dropLast().joined(separator: ", ") + " og " + folders.last!
        }
        return "Bildene ligger i \(joined)."
    }
}

/// After «Løs ut minnekortet».
struct EjectedView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(Theme.success)
                .accessibilityHidden(true)
            Text("Nå kan du trygt ta ut kortet")
                .font(Theme.title)
            Text("Sett inn et kort igjen når du vil hente flere bilder.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
            Spacer()
            Button("Vis bildene") { model.showPhotos() }
                .buttonStyle(SecondaryButtonStyle(fontSize: 21))
        }
        .frame(maxWidth: .infinity)
    }
}
