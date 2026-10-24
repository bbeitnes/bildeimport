import ImportCore
import SwiftUI

/// 3. «Kopierer bildene …»
struct ImportingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let progress = model.progress ?? ImportProgress(phase: .preparing, completed: 0, total: 0)

        VStack(alignment: .leading, spacing: 22) {
            Text(progress.phase == .preparing ? "Gjør klar …" : "Kopierer bildene …")
                .font(Theme.title)

            VStack(alignment: .leading, spacing: 12) {
                ProgressBar(fraction: progress.fraction)
                    .accessibilityLabel("Fremdrift")
                    .accessibilityValue("\(Format.number(progress.completed)) av \(Format.number(progress.total))")

                HStack(alignment: .firstTextBaseline) {
                    Text(countText(progress))
                        .font(.system(size: 24, weight: .semibold))
                    Spacer()
                    if let remaining = model.remainingTimeText {
                        Text(remaining)
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }

                if let name = progress.currentFileName {
                    Text(currentText(name: name, destination: progress.currentDestination))
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            WarningBox(text: "Ikke ta ut minnekortet mens kopieringen pågår.")

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Button(model.isCancelling ? "Avbryter …" : "Avbryt") { model.cancelImport() }
                    .buttonStyle(SecondaryButtonStyle(fontSize: 19))
                    .frame(minWidth: 200)
                    .disabled(model.isCancelling)
                    .keyboardShortcut(.cancelAction)
                Spacer()
            }
        }
    }

    private func countText(_ progress: ImportProgress) -> String {
        let done = Format.number(progress.completed)
        let total = Format.number(progress.total)
        switch progress.phase {
        case .preparing: return "Leser datoer: \(done) av \(total)"
        case .copying: return "\(done) av \(total) filer"
        }
    }

    private func currentText(name: String, destination: String?) -> String {
        guard let destination else { return "Nå: \(name)" }
        return "Nå: \(name) → \(destination)"
    }
}

/// A tall, clearly visible progress bar.
struct ProgressBar: View {
    let fraction: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: max(20, geometry.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 20)
        .animation(.linear(duration: 0.2), value: fraction)
    }
}
