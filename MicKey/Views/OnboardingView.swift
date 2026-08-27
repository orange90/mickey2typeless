import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var settings: AppSettings
    @State private var step = 0

    private let steps = [
        "onboarding.connection",
        "onboarding.identification",
        "onboarding.authorization",
        "onboarding.test"
    ]

    init(controller: AppController) {
        self.controller = controller
        _settings = ObservedObject(wrappedValue: controller.settings)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Image(systemName: index < step ? "checkmark.circle.fill" : "\(index + 1).circle.fill")
                        .foregroundStyle(index <= step ? Color.accentColor : .secondary)
                    if index < steps.count - 1 { Divider().frame(width: 35) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 28)
            .overlay(alignment: .trailing) {
                Picker("settings.language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.localizationKey)).tag(language)
                    }
                }
                .labelsHidden()
                .frame(width: 120)
                .padding(.top, 20)
                .padding(.trailing, 24)
            }

            VStack(spacing: 18) {
                Text("onboarding.title").font(.largeTitle.bold())
                Text(LocalizedStringKey(steps[step])).font(.title2)
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(28)

            Divider()
            HStack {
                if step > 0 { Button("onboarding.back") { step -= 1 } }
                Spacer()
                Button {
                    advance()
                } label: {
                    Text(LocalizedStringKey(step == steps.count - 1 ? "onboarding.done" : "onboarding.next"))
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!canAdvance)
            }
            .padding(20)
        }
        .environment(\.locale, settings.language.locale)
        .sheet(item: $controller.learningCandidate) { candidate in
            CandidateConfirmationView(controller: controller, candidate: candidate)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            VStack(spacing: 12) {
                Image(systemName: controller.discoverableDeviceCount == 0 ? "cable.connector.slash" : "cable.connector")
                    .font(.system(size: 54))
                Text(LocalizedStringKey(controller.discoverableDeviceCount == 0 ? "device.noHIDDetected" : "device.hidDetected"))
                Text(LocalizedStringKey(controller.discoverableDeviceCount == 0 ? "common.notDetected" : "common.detected"))
                    .foregroundStyle(controller.discoverableDeviceCount == 0 ? Color.secondary : Color.green)
                Text("onboarding.connection.help")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        case 1:
            VStack(spacing: 14) {
                if settings.fingerprint != nil {
                    Image(systemName: "checkmark.seal.fill").font(.system(size: 54)).foregroundStyle(.green)
                    if let product = controller.connectedDescriptor?.product {
                        Text(verbatim: product)
                    } else {
                        Text("device.confirmed")
                    }
                } else if controller.isLearning {
                    ProgressView()
                    Text("device.press")
                    Text("device.press.help").foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("device.cancel") { controller.cancelLearning() }
                } else {
                    Image(systemName: "waveform.badge.magnifyingglass").font(.system(size: 54))
                    Text("onboarding.identification.help")
                        .multilineTextAlignment(.center)
                    Button("device.learn") { controller.beginLearning() }
                }
            }
        case 2:
            PermissionSettingsView(permissions: controller.permissions)
                .frame(maxWidth: 560)
        default:
            VStack(spacing: 16) {
                Image(systemName: "character.cursor.ibeam").font(.system(size: 54))
                Text("onboarding.test.help").multilineTextAlignment(.center)
                Button("onboarding.openTypeless") { controller.openTypeless() }
                    .disabled(!controller.isTypelessInstalled)
                Text("onboarding.scope.help")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private var canAdvance: Bool {
        switch step {
        case 0: return controller.discoverableDeviceCount > 0
        case 1: return settings.fingerprint != nil
        case 2: return controller.permissions.hasRequiredPermissions
        default: return true
        }
    }

    private func advance() {
        if step < steps.count - 1 {
            step += 1
        } else {
            settings.onboardingComplete = true
            controller.retry()
        }
    }
}
