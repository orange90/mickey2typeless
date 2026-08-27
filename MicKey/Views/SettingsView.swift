import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var settings: AppSettings
    @State private var selection: SettingsSection = .general

    enum SettingsSection: Hashable {
        case general, device, mapping, permissions
    }

    init(controller: AppController) {
        self.controller = controller
        _settings = ObservedObject(wrappedValue: controller.settings)
    }

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsView(settings: controller.settings)
                .tabItem { Label("settings.general", systemImage: "gearshape") }
                .tag(SettingsSection.general)

            DeviceSettingsView(controller: controller)
                .tabItem { Label("settings.device", systemImage: "mic") }
                .tag(SettingsSection.device)

            MappingSettingsView(settings: controller.settings)
                .tabItem { Label("settings.mapping", systemImage: "keyboard") }
                .tag(SettingsSection.mapping)

            PermissionSettingsView(permissions: controller.permissions)
                .tabItem { Label("settings.permissions", systemImage: "hand.raised") }
                .tag(SettingsSection.permissions)
        }
        .environment(\.locale, settings.language.locale)
        .padding(20)
        .sheet(item: $controller.learningCandidate) { candidate in
            CandidateConfirmationView(controller: controller, candidate: candidate)
        }
    }
}

private struct GeneralSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("settings.language", selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(LocalizedStringKey(language.localizationKey)).tag(language)
                    }
                }
                Text("settings.language.help")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct DeviceSettingsView: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var settings: AppSettings

    init(controller: AppController) {
        self.controller = controller
        _settings = ObservedObject(wrappedValue: controller.settings)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("device.product") {
                    if let product = controller.connectedDescriptor?.product {
                        Text(verbatim: product)
                    } else {
                        Text("device.none")
                    }
                }
                LabeledContent("device.status") {
                    Label {
                        Text(LocalizedStringKey(controller.status.localizationKey))
                    } icon: {
                        Image(systemName: controller.status.symbolName)
                    }
                }
                if let descriptor = controller.connectedDescriptor {
                    LabeledContent("device.vidpid") {
                        Text(hex(descriptor.vendorID) + " / " + hex(descriptor.productID))
                            .monospacedDigit()
                    }
                }
            }

            if controller.isLearning {
                Section {
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text("device.press")
                    }
                    Text("device.press.help")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("device.cancel") { controller.cancelLearning() }
                }
            } else {
                Section {
                    Button("device.learn") { controller.beginLearning() }
                    if settings.fingerprint != nil {
                        Button("device.forget", role: .destructive) { controller.forgetDevice() }
                    }
                }
            }

            if controller.status == .deviceBusy {
                Section {
                    Label("conflict.help", systemImage: "exclamationmark.triangle")
                    Button("menu.retry") { controller.retry() }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct MappingSettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("mapping.key", selection: mappingBinding(\.kind)) {
                    ForEach(MappingKind.allCases) { kind in
                        if kind.displayNameIsLocalized {
                            Text(LocalizedStringKey(kind.displayName)).tag(kind)
                        } else {
                            Text(verbatim: kind.displayName).tag(kind)
                        }
                    }
                }

                if settings.mapping.kind == .letterOrDigit {
                    Picker("custom.key", selection: mappingBinding(\.alphanumericKey)) {
                        ForEach(AlphanumericKey.allCases) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                }

                if settings.mapping.kind == .customShortcut {
                    Picker("custom.key", selection: mappingBinding(\.shortcutKey)) {
                        ForEach(AlphanumericKey.allCases) { key in
                            Text(key.displayName).tag(key)
                        }
                    }
                    modifierControls
                }
            }

            Section {
                Picker("mapping.mode", selection: mappingBinding(\.responseMode)) {
                    ForEach(ResponseMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.localizationKey)).tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Text(LocalizedStringKey(settings.mapping.responseMode == .immediate ? "mapping.instant.help" : "mapping.gesture.help"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private var modifierControls: some View {
        LabeledContent("mapping.modifiers") {
            HStack {
                modifierToggle("⌘", value: .command)
                modifierToggle("⌥", value: .option)
                modifierToggle("⌃", value: .control)
                modifierToggle("⇧", value: .shift)
            }
        }
    }

    private func modifierToggle(_ label: String, value: ShortcutModifiers) -> some View {
        Toggle(label, isOn: Binding(
            get: { settings.mapping.shortcutModifiers.contains(value) },
            set: { enabled in
                var mapping = settings.mapping
                if enabled { mapping.shortcutModifiers.insert(value) }
                else { mapping.shortcutModifiers.remove(value) }
                settings.mapping = mapping
            }
        ))
        .toggleStyle(.button)
    }

    private func mappingBinding<Value>(_ keyPath: WritableKeyPath<MappingConfiguration, Value>) -> Binding<Value> {
        Binding(
            get: { settings.mapping[keyPath: keyPath] },
            set: { value in
                var mapping = settings.mapping
                mapping[keyPath: keyPath] = value
                settings.mapping = mapping
            }
        )
    }
}

struct PermissionSettingsView: View {
    @ObservedObject var permissions: PermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                permissionRow(
                    title: "permissions.input",
                    granted: permissions.hasInputMonitoring,
                    action: permissions.openInputMonitoringSettings
                )
                Divider()
                    .padding(.leading, 42)
                permissionRow(
                    title: "permissions.accessibility",
                    granted: permissions.hasAccessibility,
                    action: permissions.openAccessibilitySettings
                )
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

            Button("permissions.request") { permissions.request() }

            Text("permissions.help")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { permissions.refresh() }
    }

    private func permissionRow(title: LocalizedStringKey, granted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.circle")
            }
                .foregroundStyle(granted ? .green : .orange)
            Spacer(minLength: 16)
            Text(LocalizedStringKey(granted ? "permissions.granted" : "permissions.missing"))
                .foregroundStyle(.secondary)
            if !granted {
                Button("permissions.open", action: action)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct CandidateConfirmationView: View {
    @ObservedObject var controller: AppController
    let candidate: LearningCandidate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("device.confirm.title").font(.title2.bold())
            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 9) {
                row("device.product", candidate.descriptor.product)
                row("device.manufacturer", candidate.descriptor.manufacturer)
                row("device.transport", candidate.descriptor.transport)
                row("device.vendor", decimalAndHex(candidate.descriptor.vendorID))
                row("device.productID", decimalAndHex(candidate.descriptor.productID))
                row("device.usagePage", hex(candidate.usagePage))
                row("device.usage", hex(candidate.usage))
            }
            HStack {
                Spacer()
                Button("device.cancel") {
                    controller.learningCandidate = nil
                    dismiss()
                }
                Button("device.confirm") {
                    controller.confirmLearningCandidate()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
    }

    private func row(_ key: LocalizedStringKey, _ value: String) -> some View {
        GridRow {
            Text(key).foregroundStyle(.secondary)
            if value.isEmpty {
                Text("common.unknown").textSelection(.enabled)
            } else {
                Text(verbatim: value).textSelection(.enabled)
            }
        }
    }
}

private func hex(_ value: Int) -> String { String(format: "0x%04X", value) }
private func decimalAndHex(_ value: Int) -> String { "\(value) / \(hex(value))" }
