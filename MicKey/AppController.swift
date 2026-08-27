import AppKit
import Combine
import IOKit.hid

@MainActor
final class AppController: ObservableObject {
    @Published private(set) var status: AppRuntimeStatus = .disconnected
    @Published private(set) var connectedDescriptor: HIDDeviceDescriptor?
    @Published var learningCandidate: LearningCandidate?
    @Published private(set) var isLearning = false
    @Published private(set) var discoverableDeviceCount = 0

    let settings: AppSettings
    let permissions: PermissionManager

    private let hidService: HIDService
    private let outputEngine: KeyOutputEngine
    private var selectedRegistryID: UInt64?
    private var selectedUsagePage: Int?
    private var selectedUsage: Int?
    private var cancellables: Set<AnyCancellable> = []
    private var workspaceObservers: [NSObjectProtocol] = []

    var isTypelessInstalled: Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "now.typeless.desktop") != nil
    }

    init(
        settings: AppSettings = AppSettings(),
        permissions: PermissionManager = PermissionManager(),
        hidService: HIDService = HIDService(),
        outputEngine: KeyOutputEngine = KeyOutputEngine()
    ) {
        self.settings = settings
        self.permissions = permissions
        self.hidService = hidService
        self.outputEngine = outputEngine
        configureCallbacks()
        observeSettingsAndLifecycle()
    }

    func start() {
        permissions.startMonitoring()
        hidService.start()
        if settings.isPaused { status = .paused }
    }

    func shutdown() {
        outputEngine.cancelAndRelease()
        hidService.stop()
        permissions.stopMonitoring()
        workspaceObservers.forEach(NotificationCenter.default.removeObserver)
        workspaceObservers.removeAll()
    }

    func togglePause() {
        settings.isPaused.toggle()
        if settings.isPaused {
            outputEngine.cancelAndRelease()
            hidService.releaseSeizedDevice()
            status = .paused
        } else {
            retry()
        }
    }

    func retry() {
        permissions.refresh()
        guard !settings.isPaused else { status = .paused; return }
        guard let selectedRegistryID,
              let device = hidService.device(registryID: selectedRegistryID) else {
            status = .disconnected
            return
        }
        activate(device)
    }

    func beginLearning() {
        outputEngine.cancelAndRelease()
        hidService.releaseSeizedDevice()
        learningCandidate = nil
        isLearning = true
        status = .learning
    }

    func cancelLearning() {
        isLearning = false
        learningCandidate = nil
        retry()
    }

    func confirmLearningCandidate() {
        guard let candidate = learningCandidate,
              let device = hidService.device(registryID: candidate.descriptor.registryID) else { return }
        settings.fingerprint = candidate.fingerprint
        selectedRegistryID = candidate.descriptor.registryID
        selectedUsagePage = candidate.usagePage
        selectedUsage = candidate.usage
        connectedDescriptor = candidate.descriptor
        isLearning = false
        learningCandidate = nil
        activate(device)
    }

    func forgetDevice() {
        outputEngine.cancelAndRelease()
        hidService.releaseSeizedDevice()
        settings.fingerprint = nil
        selectedRegistryID = nil
        selectedUsagePage = nil
        selectedUsage = nil
        connectedDescriptor = nil
        status = .disconnected
    }

    func openTypeless() {
        let workspace = NSWorkspace.shared
        if let url = workspace.urlForApplication(withBundleIdentifier: "now.typeless.desktop") {
            let configuration = NSWorkspace.OpenConfiguration()
            workspace.openApplication(at: url, configuration: configuration)
        }
    }

    func quit() {
        shutdown()
        NSApplication.shared.terminate(nil)
    }

    private func configureCallbacks() {
        hidService.onDeviceConnected = { [weak self] device, descriptor in
            self?.handleConnected(device, descriptor: descriptor)
        }
        hidService.onDeviceRemoved = { [weak self] _, descriptor in
            self?.handleRemoved(descriptor)
        }
        hidService.onInputValue = { [weak self] device, descriptor, element, value in
            self?.handleInput(device, descriptor: descriptor, element: element, value: value)
        }
    }

    private func observeSettingsAndLifecycle() {
        settings.$mapping
            .dropFirst()
            .sink { [weak self] _ in self?.outputEngine.cancelAndRelease() }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            permissions.$hasInputMonitoring,
            permissions.$hasAccessibility
        )
        .removeDuplicates { previous, current in
            previous.0 == current.0 && previous.1 == current.1
        }
        .dropFirst()
        .sink { [weak self] inputMonitoring, accessibility in
            guard let self else { return }
            if inputMonitoring && accessibility {
                if self.status == .permissionRequired { self.retry() }
            } else if self.status == .mapping || self.status == .recognized {
                self.outputEngine.cancelAndRelease()
                self.hidService.releaseSeizedDevice()
                self.status = .permissionRequired
            }
        }
        .store(in: &cancellables)

        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.prepareForSleep() }
        })
        workspaceObservers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.retry() }
        })
        workspaceObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.permissions.refresh()
                if self?.status == .permissionRequired { self?.retry() }
            }
        })
        workspaceObservers.append(NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.shutdown() }
        })
    }

    private func handleConnected(_ device: IOHIDDevice, descriptor: HIDDeviceDescriptor) {
        discoverableDeviceCount = hidService.devicesByRegistryID.count

        if let fingerprint = settings.fingerprint,
           fingerprint.matches(descriptor, elementUsagePage: fingerprint.usagePage, elementUsage: fingerprint.usage),
           hidService.matchingElement(on: device, usagePage: fingerprint.usagePage, usage: fingerprint.usage) != nil {
            select(device, descriptor: descriptor, usagePage: fingerprint.usagePage, usage: fingerprint.usage)
        }
    }

    private func select(_ device: IOHIDDevice, descriptor: HIDDeviceDescriptor, usagePage: Int, usage: Int) {
        selectedRegistryID = descriptor.registryID
        selectedUsagePage = usagePage
        selectedUsage = usage
        connectedDescriptor = descriptor
        status = .recognized
        if !isLearning { activate(device) }
    }

    private func activate(_ device: IOHIDDevice) {
        guard !settings.isPaused else { status = .paused; return }
        guard permissions.hasRequiredPermissions else {
            hidService.releaseSeizedDevice()
            status = .permissionRequired
            return
        }
        let result = hidService.seize(device)
        switch result {
        case kIOReturnSuccess:
            status = .mapping
        case kIOReturnExclusiveAccess, kIOReturnCannotLock:
            status = .deviceBusy
        default:
            status = .error(String(format: "IOKit 0x%08X", result))
        }
    }

    private func handleRemoved(_ descriptor: HIDDeviceDescriptor) {
        discoverableDeviceCount = hidService.devicesByRegistryID.count
        guard selectedRegistryID == descriptor.registryID else { return }
        outputEngine.cancelAndRelease()
        selectedRegistryID = nil
        connectedDescriptor = nil
        status = settings.isPaused ? .paused : .disconnected
    }

    private func handleInput(_ device: IOHIDDevice, descriptor: HIDDeviceDescriptor, element: IOHIDElement, value: Int) {
        let usagePage = Int(IOHIDElementGetUsagePage(element))
        let usage = Int(IOHIDElementGetUsage(element))

        if isLearning {
            guard learningCandidate == nil, value != 0, usagePage == 0x0C else { return }
            learningCandidate = LearningCandidate(descriptor: descriptor, usagePage: usagePage, usage: usage)
            return
        }

        guard status == .mapping,
              selectedRegistryID == descriptor.registryID,
              selectedUsagePage == usagePage,
              selectedUsage == usage else { return }
        outputEngine.handlePhysicalButton(isDown: value != 0, configuration: settings.mapping)
    }

    private func prepareForSleep() {
        outputEngine.cancelAndRelease()
        hidService.releaseSeizedDevice()
        if !settings.isPaused { status = .disconnected }
    }
}
