import SwiftUI

/// Shows the screen that matches the app's current state.
struct ContentView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model

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
        .padding(.top, 32)
        .padding(.bottom, 36)
        .frame(width: Theme.windowSize.width, height: Theme.windowSize.height, alignment: .top)
        .animation(.easeInOut(duration: 0.2), value: model.screen)
        .alert(item: $model.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
}
