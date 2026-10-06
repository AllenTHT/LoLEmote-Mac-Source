import Foundation

public struct Modifiers: OptionSet, Equatable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let control = Modifiers(rawValue: 1)
    public static let option = Modifiers(rawValue: 2)
    public static let command = Modifiers(rawValue: 4)
    public static let shift = Modifiers(rawValue: 8)
}

public enum TriggerChord: String, CaseIterable, Identifiable {
    case controlOptionCommand, controlOptionShift, controlCommandShift
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .controlOptionCommand: return "⌃ ⌥ ⌘  Control + Option + Command"
        case .controlOptionShift: return "⌃ ⌥ ⇧  Control + Option + Shift"
        case .controlCommandShift: return "⌃ ⌘ ⇧  Control + Command + Shift"
        }
    }
    public var symbols: String {
        switch self {
        case .controlOptionCommand: return "⌃  ⌥  ⌘"
        case .controlOptionShift: return "⌃  ⌥  ⇧"
        case .controlCommandShift: return "⌃  ⌘  ⇧"
        }
    }
    public var modifiers: Modifiers {
        switch self {
        case .controlOptionCommand: return [.control, .option, .command]
        case .controlOptionShift: return [.control, .option, .shift]
        case .controlCommandShift: return [.control, .command, .shift]
        }
    }
}
