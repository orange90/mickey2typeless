import SwiftUI

@main
@MainActor
struct MicKeyApp: App {
    @StateObject private var controller = AppController()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(controller: controller)
                .environment(\.locale, controller.settings.language.locale)
        } label: {
            Label("MicKey", systemImage: controller.status.symbolName)
                .onAppear {
                    controller.start()
                    guard !controller.settings.onboardingComplete else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
        }
        .menuBarExtraStyle(.menu)

        Settings {
            Group {
                if controller.settings.onboardingComplete {
                    SettingsView(controller: controller)
                } else {
                    OnboardingView(controller: controller)
                }
            }
            .environment(\.locale, controller.settings.language.locale)
            .frame(minWidth: 620, minHeight: 500)
        }
    }
}
