import ApplicationServices
import AppKit
import Combine
import IOKit.hidsystem

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var hasInputMonitoring = false
    @Published private(set) var hasAccessibility = false
    private var monitoringCancellable: AnyCancellable?

    var hasRequiredPermissions: Bool { hasInputMonitoring && hasAccessibility }

    func refresh() {
        hasInputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        hasAccessibility = AXIsProcessTrusted()
    }

    func startMonitoring() {
        guard monitoringCancellable == nil else { return }
        refresh()
        monitoringCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refresh()
            }
    }

    func stopMonitoring() {
        monitoringCancellable?.cancel()
        monitoringCancellable = nil
    }

    func request() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        // String value of kAXTrustedCheckOptionPrompt; spelling it here avoids
        // Swift 6 treating the imported CF global as mutable shared state.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refresh()
    }

    func openInputMonitoringSettings() {
        openSettings(anchor: "Privacy_ListenEvent")
    }

    func openAccessibilitySettings() {
        openSettings(anchor: "Privacy_Accessibility")
    }

    private func openSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
