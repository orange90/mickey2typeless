import Foundation
import XCTest
@testable import MicKey

@MainActor
final class AppSettingsTests: XCTestCase {
    func testLanguageDefaultsToSimplifiedChinese() {
        let defaults = makeDefaults()

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.language, .simplifiedChinese)
    }

    func testLanguagePersistsAcrossSettingsInstances() {
        let defaults = makeDefaults()
        let settings = AppSettings(defaults: defaults)

        settings.language = .english
        let restoredSettings = AppSettings(defaults: defaults)

        XCTAssertEqual(restoredSettings.language, .english)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
