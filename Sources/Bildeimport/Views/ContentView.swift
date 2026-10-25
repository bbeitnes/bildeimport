import AppKit
import SwiftUI

/// Shows the screen that matches the app's current state.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            QuitBar()
            Group {
                switch model.screen {
                case .waitingForCard: WaitingForCardView()
                case .chooseCard: ChooseCardView()
                case .scanning: ScanningView()
                case .ready: ReadyView()
                case .importing: ImportingView()
                case .done: DoneView()
                case .ejected: EjectedView()
                }
            }
            .padding(.horizontal, 48)
            .padding(.top, 8)
            .padding(.bottom, 36)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: Theme.windowSize.width, height: Theme.windowSize.height, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: model.screen)
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
}

/// A row at the top of the window with the «Avslutt programmet» button.
/// Hidden while copying, so the import is stopped with «Avbryt» first.
struct QuitBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack {
            Spacer()
            if model.screen != .importing {
                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Avslutt programmet", systemImage: "xmark.circle")
                }
                .buttonStyle(SecondaryButtonStyle(fontSize: 17))
                .help("Lukker Bildeimport")
            }
        }
        .frame(height: 50)
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }
}
