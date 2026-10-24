import ImportCore
import SwiftUI

/// 1. «Sett inn minnekortet»
struct WaitingForCardView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "sdcard")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(Theme.accent)
                .padding(.top, 12)
                .accessibilityHidden(true)
            Text("Sett inn minnekortet")
                .font(Theme.title)
            Text("Appen finner kortet av seg selv. Du trenger ikke trykke på noe før kortet er funnet.")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            DestinationBox()
        }
    }
}

/// Shown when more than one card is inserted.
struct ChooseCardView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Flere minnekort funnet")
                .font(Theme.title)
            Text("Hvilket kort vil du hente bilder fra?")
                .font(Theme.body)
                .foregroundStyle(Theme.secondaryText)
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(model.cards) { card in
                        Button {
                            model.select(card)
                        } label: {
                            Label(card.name, systemImage: "sdcard")
                        }
                        .buttonStyle(SecondaryButtonStyle(fontSize: 21, fillsWidth: true))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Brief step while the card is searched.
struct ScanningView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Ser etter bilder og videoer på kortet …")
                .font(Theme.body)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

/// 2. «Klar til å importere»
struct ReadyView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Klar til å importere")
                .font(Theme.title)

            if model.mediaFiles.isEmpty {
                InfoBox(
                    systemImage: "sdcard",
                    caption: "Minnekort funnet",
                    text: "Fant ingen bilder eller videoer på kortet",
                    tint: Theme.warning,
                    background: Theme.warningSoft
                )
            } else {
                InfoBox(
                    systemImage: "sdcard",
                    caption: "Minnekort funnet",
                    text: Format.count(model.mediaFiles.count, "bilde eller video", "bilder og videoer"),
                    tint: Theme.accent,
                    background: Theme.accentSoft
                )
            }

            DestinationBox()

            Text(explanation)
                .font(.system(size: 18))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button("Importer") { model.startImport() }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!model.canImport)
                .keyboardShortcut(.defaultAction)
        }
    }

    /// «Mapper for år og dato lages automatisk, for eksempel Bilder › 2026 › 2026-10-24.»
    private var explanation: AttributedString {
        let today = CaptureDay(date: Date()) ?? CaptureDay(year: 2026, month: 1, day: 1)!
        let example = "\(model.destination.displayName) › \(today.yearFolderName) › \(today.dateFolderName)"
        var text = AttributedString("Mapper for år og dato lages automatisk, for eksempel ")
        var bold = AttributedString(example)
        bold.font = .system(size: 18, weight: .semibold)
        bold.foregroundColor = .primary
        text += bold
        text += AttributedString(". Bildene blir også liggende på kortet.")
        return text
    }
}
