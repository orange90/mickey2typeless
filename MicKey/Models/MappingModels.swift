import CoreGraphics
import Foundation

enum ResponseMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case immediate
    case preserveHardwareGestures

    var id: String { rawValue }
    var localizationKey: String {
        switch self {
        case .immediate: return "mapping.instant"
        case .preserveHardwareGestures: return "mapping.gesture"
        }
    }
}

enum MappingKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case globe, escape, returnKey, space, tab, up, down, left, right
    case f1, f2, f3, f4, f5, f6, f7, f8, f9, f10
    case f11, f12, f13, f14, f15, f16, f17, f18, f19, f20
    case letterOrDigit
    case customShortcut

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .globe: return "Fn (Globe)"
        case .escape: return "Esc"
        case .returnKey: return "Return"
        case .space: return "Space"
        case .tab: return "Tab"
        case .up: return "↑"
        case .down: return "↓"
        case .left: return "←"
        case .right: return "→"
        case .letterOrDigit: return "A–Z / 0–9"
        case .customShortcut: return "mapping.shortcut"
        default: return rawValue.uppercased()
        }
    }

    var displayNameIsLocalized: Bool { self == .customShortcut }

    var fixedKeyCode: CGKeyCode? {
        switch self {
        case .globe: return 63
        case .escape: return 53
        case .returnKey: return 36
        case .space: return 49
        case .tab: return 48
        case .up: return 126
        case .down: return 125
        case .left: return 123
        case .right: return 124
        case .f1: return 122
        case .f2: return 120
        case .f3: return 99
        case .f4: return 118
        case .f5: return 96
        case .f6: return 97
        case .f7: return 98
        case .f8: return 100
        case .f9: return 101
        case .f10: return 109
        case .f11: return 103
        case .f12: return 111
        case .f13: return 105
        case .f14: return 107
        case .f15: return 113
        case .f16: return 106
        case .f17: return 64
        case .f18: return 79
        case .f19: return 80
        case .f20: return 90
        case .letterOrDigit, .customShortcut: return nil
        }
    }
}

enum AlphanumericKey: String, Codable, CaseIterable, Identifiable, Sendable {
    case a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z
    case zero, one, two, three, four, five, six, seven, eight, nine

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        default: return rawValue.uppercased()
        }
    }

    var keyCode: CGKeyCode {
        let codes: [AlphanumericKey: CGKeyCode] = [
            .a: 0, .s: 1, .d: 2, .f: 3, .h: 4, .g: 5, .z: 6, .x: 7,
            .c: 8, .v: 9, .b: 11, .q: 12, .w: 13, .e: 14, .r: 15,
            .y: 16, .t: 17, .one: 18, .two: 19, .three: 20, .four: 21,
            .six: 22, .five: 23, .nine: 25, .seven: 26, .eight: 28,
            .zero: 29, .o: 31, .u: 32, .i: 34, .p: 35, .l: 37,
            .j: 38, .k: 40, .n: 45, .m: 46
        ]
        return codes[self] ?? 0
    }
}

struct ShortcutModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int
    static let command = ShortcutModifiers(rawValue: 1 << 0)
    static let option = ShortcutModifiers(rawValue: 1 << 1)
    static let control = ShortcutModifiers(rawValue: 1 << 2)
    static let shift = ShortcutModifiers(rawValue: 1 << 3)

    var eventFlags: CGEventFlags {
        var result: CGEventFlags = []
        if contains(.command) { result.insert(.maskCommand) }
        if contains(.option) { result.insert(.maskAlternate) }
        if contains(.control) { result.insert(.maskControl) }
        if contains(.shift) { result.insert(.maskShift) }
        return result
    }
}

struct MappingConfiguration: Codable, Equatable, Sendable {
    var kind: MappingKind = .globe
    var alphanumericKey: AlphanumericKey = .a
    var shortcutKey: AlphanumericKey = .a
    var shortcutModifiers: ShortcutModifiers = [.command]
    var responseMode: ResponseMode = .immediate

    var keyCode: CGKeyCode {
        kind.fixedKeyCode ?? (kind == .customShortcut ? shortcutKey.keyCode : alphanumericKey.keyCode)
    }

    var flags: CGEventFlags {
        if kind == .globe { return .maskSecondaryFn }
        if kind == .customShortcut { return shortcutModifiers.eventFlags }
        return []
    }
}
