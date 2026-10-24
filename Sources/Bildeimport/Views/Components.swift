import SwiftUI

/// Shared look: large text, high contrast, one clear main button per screen.
enum Theme {
    static let accent = Color(red: 0.04, green: 0.36, blue: 0.77)        // #0A5BC4
    static let accentSoft = Color(red: 0.92, green: 0.95, blue: 0.99)    // #EAF2FD
    static let panel = Color(nsColor: .controlBackgroundColor)
    static let secondaryText = Color.primary.opacity(0.72)
    static let success = Color(red: 0.12, green: 0.48, blue: 0.20)       // #1E7B34
    static let warning = Color(red: 0.54, green: 0.35, blue: 0.0)        // #8A5A00
    static let warningSoft = Color(red: 1.0, green: 0.96, blue: 0.88)    // #FFF6E0

    static let title = Font.system(size: 34, weight: .bold)
    static let body = Font.system(size: 20)
    static let bodyBold = Font.system(size: 20, weight: .semibold)
    static let caption = Font.system(size: 15)

    static let windowSize = CGSize(width: 680, height: 540)
}

/// The big blue button, for example «Importer».
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 23, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isEnabled ? Theme.accent : Color.gray.opacity(0.5))
            )
            .opacity(configuration.isPressed ? 0.8 : 1)
            .contentShape(Rectangle())
    }
}

/// White button with a border, for less important actions.
struct SecondaryButtonStyle: ButtonStyle {
    var fontSize: CGFloat = 19
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize))
            .foregroundStyle(Color.primary)
            .padding(.horizontal, 20)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.primary.opacity(0.25), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Rectangle())
    }
}

/// A rounded box with an icon, a small caption and a large line of text.
struct InfoBox<Trailing: View>: View {
    let systemImage: String
    let caption: String
    let text: String
    var tint: Color = .primary
    var background: Color = Theme.panel
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 30))
                .foregroundStyle(tint)
                .frame(width: 40)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(caption)
                    .font(Theme.caption)
                    .foregroundStyle(Theme.secondaryText)
                Text(text)
                    .font(.system(size: 21, weight: .semibold))
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(RoundedRectangle(cornerRadius: 12).fill(background))
        .accessibilityElement(children: .contain)
    }
}

extension InfoBox where Trailing == EmptyView {
    init(systemImage: String, caption: String, text: String, tint: Color = .primary, background: Color = Theme.panel) {
        self.init(systemImage: systemImage, caption: caption, text: text, tint: tint, background: background) { EmptyView() }
    }
}

/// Shows where the photos are saved, with a button to choose another folder.
struct DestinationBox: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            InfoBox(systemImage: "folder", caption: "Bildene lagres i", text: model.destination.displayName) {
                Button("Velg en annen mappe") { model.chooseDestination() }
                    .buttonStyle(SecondaryButtonStyle(fontSize: 17))
            }
            if !model.destination.isAvailable {
                WarningBox(text: unavailableText)
            }
        }
    }

    private var unavailableText: String {
        let disk = model.destination.volumeName
        if disk.isEmpty {
            return "Finner ikke mappen. Koble til disken den ligger på, eller velg en annen mappe."
        }
        return "Disken «\(disk)» er ikke koblet til. Koble den til, eller velg en annen mappe."
    }
}

struct WarningBox: View {
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 24))
                .foregroundStyle(Theme.warning)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color(red: 0.36, green: 0.24, blue: 0.0))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.warningSoft))
    }
}

/// Norwegian number formatting: 1 204.
enum Format {
    static let norwegian = Locale(identifier: "nb_NO")

    static func number(_ value: Int) -> String {
        value.formatted(.number.locale(norwegian))
    }

    /// «1 fil», «2 filer».
    static func count(_ value: Int, _ singular: String, _ plural: String) -> String {
        "\(number(value)) \(value == 1 ? singular : plural)"
    }
}
