import SwiftUI

struct MenuContentView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings
    @State private var didStart = false

    init(controller: AppController) {
        self.controller = controller
        _settings = ObservedObject(wrappedValue: controller.settings)
    }

    var body: some View {
        Group {
            Label {
                Text(LocalizedStringKey(controller.status.localizationKey))
            } icon: {
                Image(systemName: controller.status.symbolName)
            }

            if case let .error(message) = controller.status {
                Text(message)
            }
            if controller.status == .deviceBusy {
                Text("conflict.help")
            }

            Divider()

            Button {
                controller.togglePause()
            } label: {
                Text(LocalizedStringKey(settings.isPaused ? "menu.resume" : "menu.pause"))
            }
            .disabled(controller.connectedDescriptor == nil && !settings.isPaused)

            if controller.status == .deviceBusy || controller.status == .permissionRequired || controller.status == .disconnected {
                Button("menu.retry") { controller.retry() }
            }

            Button("menu.settings") { openSettings() }
                .keyboardShortcut(",")

            Divider()

            Button("menu.quit") { controller.quit() }
                .keyboardShortcut("q")
                .onAppear {
                    guard !didStart else { return }
                    didStart = true
                    controller.start()
                    if !settings.onboardingComplete {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { openSettings() }
                    }
                }
        }
        .environment(\.locale, settings.language.locale)
    }
}
