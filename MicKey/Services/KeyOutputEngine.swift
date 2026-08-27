import CoreGraphics
import Foundation

protocol KeyEventPosting: AnyObject {
    func post(keyCode: CGKeyCode, eventType: CGEventType, flags: CGEventFlags)
}

final class CGKeyEventPoster: KeyEventPosting {
    func post(keyCode: CGKeyCode, eventType: CGEventType, flags: CGEventFlags) {
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: keyCode,
            keyDown: eventType == .keyDown ||
                (eventType == .flagsChanged && flags.contains(.maskSecondaryFn))
        ) else { return }
        event.type = eventType
        event.flags = flags
        event.post(tap: .cghidEventTap)
    }
}

@MainActor
final class KeyOutputEngine {
    private let poster: KeyEventPosting
    private var isPhysicalDown = false
    private var emittedConfiguration: MappingConfiguration?
    private var holdWorkItem: DispatchWorkItem?
    private var clickWorkItem: DispatchWorkItem?
    private var tapCount = 0

    init(poster: KeyEventPosting = CGKeyEventPoster()) {
        self.poster = poster
    }

    func handlePhysicalButton(isDown: Bool, configuration: MappingConfiguration) {
        guard isDown != isPhysicalDown else { return }
        isPhysicalDown = isDown

        switch configuration.responseMode {
        case .immediate:
            handleImmediate(isDown: isDown, configuration: configuration)
        case .preserveHardwareGestures:
            handleGesturePreserving(isDown: isDown, configuration: configuration)
        }
    }

    func cancelAndRelease() {
        holdWorkItem?.cancel()
        clickWorkItem?.cancel()
        holdWorkItem = nil
        clickWorkItem = nil
        tapCount = 0
        isPhysicalDown = false
        if let emittedConfiguration {
            emit(emittedConfiguration, isDown: false)
            self.emittedConfiguration = nil
        }
    }

    private func handleImmediate(isDown: Bool, configuration: MappingConfiguration) {
        if isDown {
            emittedConfiguration = configuration
            emit(configuration, isDown: true)
        } else if let emittedConfiguration {
            emit(emittedConfiguration, isDown: false)
            self.emittedConfiguration = nil
        }
    }

    private func handleGesturePreserving(isDown: Bool, configuration: MappingConfiguration) {
        if isDown {
            clickWorkItem?.cancel()
            scheduleHold(configuration)
            return
        }

        holdWorkItem?.cancel()
        holdWorkItem = nil
        if let emittedConfiguration {
            emit(emittedConfiguration, isDown: false)
            self.emittedConfiguration = nil
            tapCount = 0
            return
        }

        tapCount += 1
        scheduleClickResolution(configuration)
    }

    private func scheduleHold(_ configuration: MappingConfiguration) {
        holdWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.isPhysicalDown, self.tapCount == 0 else { return }
            self.emittedConfiguration = configuration
            self.emit(configuration, isDown: true)
        }
        holdWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(180), execute: work)
    }

    private func scheduleClickResolution(_ configuration: MappingConfiguration) {
        clickWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let shouldEmitSingleClick = self.tapCount == 1
            self.tapCount = 0
            if shouldEmitSingleClick {
                self.emit(configuration, isDown: true)
                let keyUp = DispatchWorkItem { [weak self] in self?.emit(configuration, isDown: false) }
                self.clickWorkItem = keyUp
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50), execute: keyUp)
            }
        }
        clickWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(320), execute: work)
    }

    private func emit(_ configuration: MappingConfiguration, isDown: Bool) {
        if configuration.kind == .globe {
            // Fn/Globe is a modifier. A physical Fn key produces flagsChanged
            // events, and its release clears maskSecondaryFn. Sending ordinary
            // keyDown/keyUp events (or retaining the flag on release) makes
            // shortcut listeners such as Typeless treat Fn as being held.
            poster.post(
                keyCode: configuration.keyCode,
                eventType: .flagsChanged,
                flags: isDown ? .maskSecondaryFn : []
            )
            return
        }

        poster.post(
            keyCode: configuration.keyCode,
            eventType: isDown ? .keyDown : .keyUp,
            flags: configuration.flags
        )
    }
}
