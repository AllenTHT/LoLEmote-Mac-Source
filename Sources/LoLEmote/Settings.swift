import Foundation
import EmoteCore

struct Settings: Codable, Equatable {
    var loadout = Loadout.defaults
    var chord = TriggerChord.controlOptionShift.rawValue
    var size = 96.0
    var volume = 0.55
    var muted = false
    var enabled = false
    var trigger: TriggerChord { TriggerChord(rawValue: chord) ?? .controlOptionShift }
    static let key = "settings.v1"
    static func read(from defaults: UserDefaults) -> Settings {
        guard let data = defaults.data(forKey: key),
              var settings = try? JSONDecoder().decode(Self.self, from: data) else { return Settings() }
        settings.loadout = settings.loadout.sanitized(available: Set(Assets.emotes.map(\.id)))
        settings.size = settings.size.isFinite ? min(128, max(64, settings.size)) : 96
        settings.volume = settings.volume.isFinite ? min(1, max(0, settings.volume)) : 0.55
        settings.chord = settings.trigger.rawValue
        return settings
    }
    func save(to defaults: UserDefaults) {
        if let data = try? JSONEncoder().encode(self) { defaults.set(data, forKey: Self.key) }
    }
}
