import Foundation
import IOKit.hid

struct DeviceFingerprint: Codable, Hashable, Sendable {
    let transport: String
    let product: String
    let manufacturer: String
    let vendorID: Int
    let productID: Int
    let usagePage: Int
    let usage: Int

    func matches(_ descriptor: HIDDeviceDescriptor, elementUsagePage: Int, elementUsage: Int) -> Bool {
        transport == descriptor.transport &&
        product == descriptor.product &&
        manufacturer == descriptor.manufacturer &&
        vendorID == descriptor.vendorID &&
        productID == descriptor.productID &&
        usagePage == elementUsagePage &&
        usage == elementUsage
    }
}

struct HIDDeviceDescriptor: Hashable, Sendable {
    let registryID: UInt64
    let transport: String
    let product: String
    let manufacturer: String
    let vendorID: Int
    let productID: Int
    let primaryUsagePage: Int
    let primaryUsage: Int
    let isBuiltIn: Bool

    var isExternalUSBConsumerDevice: Bool {
        guard !isBuiltIn,
              transport.caseInsensitiveCompare("USB") == .orderedSame,
              primaryUsagePage == 0x0C else { return false }

        let excludedNames = ["keyboard", "trackpad", "touch bar", "virtual"]
        let haystack = "\(manufacturer) \(product)".lowercased()
        return !excludedNames.contains(where: haystack.contains)
    }

    func fingerprint(elementUsagePage: Int, elementUsage: Int) -> DeviceFingerprint {
        DeviceFingerprint(
            transport: transport,
            product: product,
            manufacturer: manufacturer,
            vendorID: vendorID,
            productID: productID,
            usagePage: elementUsagePage,
            usage: elementUsage
        )
    }
}

struct LearningCandidate: Identifiable, Hashable, Sendable {
    let id: UUID
    let descriptor: HIDDeviceDescriptor
    let usagePage: Int
    let usage: Int

    init(descriptor: HIDDeviceDescriptor, usagePage: Int, usage: Int) {
        id = UUID()
        self.descriptor = descriptor
        self.usagePage = usagePage
        self.usage = usage
    }

    var fingerprint: DeviceFingerprint {
        descriptor.fingerprint(elementUsagePage: usagePage, elementUsage: usage)
    }
}

enum HIDProperty {
    static func integer(_ key: CFString, from device: IOHIDDevice) -> Int {
        guard let value = IOHIDDeviceGetProperty(device, key) else { return 0 }
        if CFGetTypeID(value) == CFNumberGetTypeID() {
            var number: Int64 = 0
            CFNumberGetValue((value as! CFNumber), .sInt64Type, &number)
            return Int(number)
        }
        return 0
    }

    static func string(_ key: CFString, from device: IOHIDDevice) -> String {
        guard let value = IOHIDDeviceGetProperty(device, key) else { return "" }
        return (value as? String) ?? ""
    }

    static func boolean(_ key: CFString, from device: IOHIDDevice) -> Bool {
        guard let value = IOHIDDeviceGetProperty(device, key) else { return false }
        if CFGetTypeID(value) == CFBooleanGetTypeID() {
            return CFBooleanGetValue((value as! CFBoolean))
        }
        return integer(key, from: device) != 0
    }

    static func descriptor(for device: IOHIDDevice) -> HIDDeviceDescriptor {
        let service = IOHIDDeviceGetService(device)
        var registryID: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(service, &registryID)
        return HIDDeviceDescriptor(
            registryID: registryID,
            transport: string(kIOHIDTransportKey as CFString, from: device),
            product: string(kIOHIDProductKey as CFString, from: device),
            manufacturer: string(kIOHIDManufacturerKey as CFString, from: device),
            vendorID: integer(kIOHIDVendorIDKey as CFString, from: device),
            productID: integer(kIOHIDProductIDKey as CFString, from: device),
            primaryUsagePage: integer(kIOHIDPrimaryUsagePageKey as CFString, from: device),
            primaryUsage: integer(kIOHIDPrimaryUsageKey as CFString, from: device),
            isBuiltIn: boolean("Built-In" as CFString, from: device)
        )
    }
}
