import CoreGraphics
import XCTest
@testable import MicKey

@MainActor
final class KeyOutputEngineTests: XCTestCase {
    final class Poster: KeyEventPosting {
        struct Event: Equatable {
            let keyCode: CGKeyCode
            let eventType: CGEventType
            let flags: CGEventFlags
        }
        var events: [Event] = []
        func post(keyCode: CGKeyCode, eventType: CGEventType, flags: CGEventFlags) {
            events.append(Event(keyCode: keyCode, eventType: eventType, flags: flags))
        }
    }

    func testImmediateModePreservesDownAndUp() {
        let poster = Poster()
        let engine = KeyOutputEngine(poster: poster)
        let configuration = MappingConfiguration(kind: .escape, responseMode: .immediate)

        engine.handlePhysicalButton(isDown: true, configuration: configuration)
        engine.handlePhysicalButton(isDown: false, configuration: configuration)

        XCTAssertEqual(poster.events, [
            .init(keyCode: 53, eventType: .keyDown, flags: []),
            .init(keyCode: 53, eventType: .keyUp, flags: [])
        ])
    }

    func testGlobeUsesModifierEventsAndClearsFnFlagOnRelease() {
        let poster = Poster()
        let engine = KeyOutputEngine(poster: poster)
        let configuration = MappingConfiguration(kind: .globe, responseMode: .immediate)

        engine.handlePhysicalButton(isDown: true, configuration: configuration)
        engine.handlePhysicalButton(isDown: false, configuration: configuration)

        XCTAssertEqual(poster.events, [
            .init(keyCode: 63, eventType: .flagsChanged, flags: .maskSecondaryFn),
            .init(keyCode: 63, eventType: .flagsChanged, flags: [])
        ])
    }

    func testDoubleClickProducesNoMappedKey() async throws {
        let poster = Poster()
        let engine = KeyOutputEngine(poster: poster)
        let configuration = MappingConfiguration(kind: .escape, responseMode: .preserveHardwareGestures)

        engine.handlePhysicalButton(isDown: true, configuration: configuration)
        engine.handlePhysicalButton(isDown: false, configuration: configuration)
        try await Task.sleep(for: .milliseconds(80))
        engine.handlePhysicalButton(isDown: true, configuration: configuration)
        engine.handlePhysicalButton(isDown: false, configuration: configuration)
        try await Task.sleep(for: .milliseconds(380))

        XCTAssertTrue(poster.events.isEmpty)
    }

    func testSingleClickProducesFiftyMillisecondPress() async throws {
        let poster = Poster()
        let engine = KeyOutputEngine(poster: poster)
        let configuration = MappingConfiguration(kind: .escape, responseMode: .preserveHardwareGestures)

        engine.handlePhysicalButton(isDown: true, configuration: configuration)
        engine.handlePhysicalButton(isDown: false, configuration: configuration)
        try await Task.sleep(for: .milliseconds(390))

        XCTAssertEqual(poster.events, [
            .init(keyCode: 53, eventType: .keyDown, flags: []),
            .init(keyCode: 53, eventType: .keyUp, flags: [])
        ])
    }

    func testHoldEmitsAfterThresholdAndReleasesWithPhysicalButton() async throws {
        let poster = Poster()
        let engine = KeyOutputEngine(poster: poster)
        let configuration = MappingConfiguration(kind: .escape, responseMode: .preserveHardwareGestures)

        engine.handlePhysicalButton(isDown: true, configuration: configuration)
        try await Task.sleep(for: .milliseconds(220))
        XCTAssertEqual(poster.events, [.init(keyCode: 53, eventType: .keyDown, flags: [])])
        engine.handlePhysicalButton(isDown: false, configuration: configuration)
        XCTAssertEqual(poster.events, [
            .init(keyCode: 53, eventType: .keyDown, flags: []),
            .init(keyCode: 53, eventType: .keyUp, flags: [])
        ])
    }
}
