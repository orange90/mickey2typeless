@preconcurrency import IOKit.hid
import Foundation

final class HIDService: @unchecked Sendable {
    typealias DeviceHandler = @MainActor (IOHIDDevice, HIDDeviceDescriptor) -> Void
    typealias RemovalHandler = @MainActor (IOHIDDevice, HIDDeviceDescriptor) -> Void
    typealias ValueHandler = @MainActor (IOHIDDevice, HIDDeviceDescriptor, IOHIDElement, Int) -> Void

    var onDeviceConnected: DeviceHandler?
    var onDeviceRemoved: RemovalHandler?
    var onInputValue: ValueHandler?

    private var manager: IOHIDManager?
    private(set) var devicesByRegistryID: [UInt64: IOHIDDevice] = [:]
    private(set) var seizedDevice: IOHIDDevice?

    @MainActor
    func start() {
        guard manager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        self.manager = manager

        let consumerMatch = [kIOHIDDeviceUsagePageKey: 0x0C] as CFDictionary
        IOHIDManagerSetDeviceMatching(manager, consumerMatch)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            let service = Unmanaged<HIDService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.didConnect(device) }
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, device in
            guard let context else { return }
            let service = Unmanaged<HIDService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.didRemove(device) }
        }, context)
        IOHIDManagerRegisterInputValueCallback(manager, { context, _, _, value in
            guard let context else { return }
            let service = Unmanaged<HIDService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.didReceive(value) }
        }, context)

        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
    }

    @MainActor
    func stop() {
        releaseSeizedDevice()
        guard let manager else { return }
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        devicesByRegistryID.removeAll()
        self.manager = nil
    }

    @MainActor
    @discardableResult
    func seize(_ device: IOHIDDevice) -> IOReturn {
        if seizedDevice === device { return kIOReturnSuccess }
        releaseSeizedDevice()

        // The manager opened devices non-exclusively for discovery. Reopen only the
        // confirmed interface with seize; the receiver's audio interface is separate.
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        let result = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if result == kIOReturnSuccess {
            seizedDevice = device
        } else {
            // Restore observation after an unsuccessful exclusive-open attempt.
            IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        return result
    }

    @MainActor
    func releaseSeizedDevice() {
        guard let seizedDevice else { return }
        IOHIDDeviceClose(seizedDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDDeviceOpen(seizedDevice, IOOptionBits(kIOHIDOptionsTypeNone))
        self.seizedDevice = nil
    }

    @MainActor
    func device(registryID: UInt64) -> IOHIDDevice? {
        devicesByRegistryID[registryID]
    }

    func matchingElement(on device: IOHIDDevice, usagePage: Int, usage: Int) -> IOHIDElement? {
        let match = [
            kIOHIDElementUsagePageKey: usagePage,
            kIOHIDElementUsageKey: usage
        ] as CFDictionary
        guard let rawElements = IOHIDDeviceCopyMatchingElements(device, match, IOOptionBits(kIOHIDOptionsTypeNone)) else {
            return nil
        }
        let elements = rawElements as! [IOHIDElement]
        return elements.first { element in
            let type = IOHIDElementGetType(element)
            return type == kIOHIDElementTypeInput_Button ||
                type == kIOHIDElementTypeInput_Misc ||
                type == kIOHIDElementTypeInput_ScanCodes
        }
    }

    @MainActor
    private func didConnect(_ device: IOHIDDevice) {
        let descriptor = HIDProperty.descriptor(for: device)
        guard descriptor.isExternalUSBConsumerDevice else { return }
        devicesByRegistryID[descriptor.registryID] = device
        onDeviceConnected?(device, descriptor)
    }

    @MainActor
    private func didRemove(_ device: IOHIDDevice) {
        let descriptor = HIDProperty.descriptor(for: device)
        devicesByRegistryID.removeValue(forKey: descriptor.registryID)
        if seizedDevice === device { seizedDevice = nil }
        onDeviceRemoved?(device, descriptor)
    }

    @MainActor
    private func didReceive(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(element)
        let descriptor = HIDProperty.descriptor(for: device)
        guard descriptor.isExternalUSBConsumerDevice else { return }
        onInputValue?(device, descriptor, element, IOHIDValueGetIntegerValue(value))
    }
}
