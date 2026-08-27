import Combine
import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case simplifiedChinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }
    var locale: Locale { Locale(identifier: rawValue) }

    var localizationKey: String {
        switch self {
        case .simplifiedChinese: return "language.chinese"
        case .english: return "language.english"
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var mapping: MappingConfiguration { didSet { save(mapping, key: Keys.mapping) } }
    @Published var fingerprint: DeviceFingerprint? { didSet { save(fingerprint, key: Keys.fingerprint) } }
    @Published var onboardingComplete: Bool { didSet { defaults.set(onboardingComplete, forKey: Keys.onboarding) } }
    @Published var isPaused: Bool { didSet { defaults.set(isPaused, forKey: Keys.paused) } }
    @Published var language: AppLanguage { didSet { defaults.set(language.rawValue, forKey: Keys.language) } }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let mapping = "mapping.configuration.v1"
        static let fingerprint = "device.fingerprint.v1"
        static let onboarding = "onboarding.complete.v1"
        static let paused = "mapping.paused.v1"
        static let language = "app.language.v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mapping = Self.decode(MappingConfiguration.self, key: Keys.mapping, defaults: defaults) ?? MappingConfiguration()
        fingerprint = Self.decode(DeviceFingerprint.self, key: Keys.fingerprint, defaults: defaults)
        onboardingComplete = defaults.bool(forKey: Keys.onboarding)
        isPaused = defaults.bool(forKey: Keys.paused)
        language = defaults.string(forKey: Keys.language).flatMap(AppLanguage.init(rawValue:)) ?? .simplifiedChinese
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }

    private func save<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        save(value, key: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

enum AppRuntimeStatus: Equatable, Sendable {
    case disconnected
    case recognized
    case mapping
    case paused
    case permissionRequired
    case deviceBusy
    case learning
    case error(String)

    var localizationKey: String {
        switch self {
        case .disconnected: return "status.disconnected"
        case .recognized: return "status.recognized"
        case .mapping: return "status.mapping"
        case .paused: return "status.paused"
        case .permissionRequired: return "status.permission"
        case .deviceBusy: return "status.busy"
        case .learning: return "status.learning"
        case .error: return "status.error"
        }
    }

    var symbolName: String {
        switch self {
        case .mapping: return "mic.badge.plus"
        case .recognized: return "mic.fill"
        case .paused: return "pause.circle"
        case .permissionRequired: return "exclamationmark.shield"
        case .deviceBusy, .error: return "exclamationmark.triangle"
        case .learning: return "waveform.badge.magnifyingglass"
        case .disconnected: return "mic.slash"
        }
    }
}
