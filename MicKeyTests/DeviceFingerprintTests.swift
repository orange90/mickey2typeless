import XCTest
@testable import MicKey

final class DeviceFingerprintTests: XCTestCase {
    func testFullFingerprintMustMatch() {
        let descriptor = HIDDeviceDescriptor(
            registryID: 42,
            transport: "USB",
            product: "Wireless Microphone Receiver",
            manufacturer: "Example Audio",
            vendorID: 0x1234,
            productID: 0x5678,
            primaryUsagePage: 0x0C,
            primaryUsage: 1,
            isBuiltIn: false
        )
        let fingerprint = descriptor.fingerprint(elementUsagePage: 0x0C, elementUsage: 0xE9)

        XCTAssertTrue(fingerprint.matches(descriptor, elementUsagePage: 0x0C, elementUsage: 0xE9))
        XCTAssertFalse(fingerprint.matches(descriptor, elementUsagePage: 0x0C, elementUsage: 0xEA))

        let anotherBatch = HIDDeviceDescriptor(
            registryID: 43,
            transport: "USB",
            product: descriptor.product,
            manufacturer: descriptor.manufacturer,
            vendorID: descriptor.vendorID,
            productID: 0x5679,
            primaryUsagePage: 0x0C,
            primaryUsage: 1,
            isBuiltIn: false
        )
        XCTAssertFalse(fingerprint.matches(anotherBatch, elementUsagePage: 0x0C, elementUsage: 0xE9))
    }

    func testEligibleDeviceMustBeExternalUSBConsumerHID() {
        let eligible = HIDDeviceDescriptor(
            registryID: 1,
            transport: "USB",
            product: "Wireless Microphone Receiver",
            manufacturer: "Example Audio",
            vendorID: 0x1234,
            productID: 0x5678,
            primaryUsagePage: 0x0C,
            primaryUsage: 1,
            isBuiltIn: false
        )
        XCTAssertTrue(eligible.isExternalUSBConsumerDevice)

        let bluetooth = HIDDeviceDescriptor(
            registryID: 2,
            transport: "Bluetooth",
            product: eligible.product,
            manufacturer: eligible.manufacturer,
            vendorID: eligible.vendorID,
            productID: eligible.productID,
            primaryUsagePage: eligible.primaryUsagePage,
            primaryUsage: eligible.primaryUsage,
            isBuiltIn: false
        )
        XCTAssertFalse(bluetooth.isExternalUSBConsumerDevice)
    }
}
