import Foundation
import CoreGraphics

public struct Emote: Codable, Identifiable, Equatable {
    public let id: Int
    public let title: String
    public let gameName: String
    public let image: String
    public let sound: String
    public let aliases: [String]
    public let category: EmoteCategory
    public let animation: String?

    public init(id: Int, title: String, gameName: String, image: String, sound: String,
                aliases: [String] = [], category: EmoteCategory = .classic, animation: String? = nil) {
        self.id = id; self.title = title; self.gameName = gameName
        self.image = image; self.sound = sound; self.aliases = aliases
        self.category = category; self.animation = animation
    }
    private enum CodingKeys: String, CodingKey { case id, title, gameName, image, sound, aliases, category, animation }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Int.self, forKey: .id)
        title = try values.decode(String.self, forKey: .title)
        gameName = try values.decode(String.self, forKey: .gameName)
        image = try values.decode(String.self, forKey: .image)
        sound = try values.decode(String.self, forKey: .sound)
        aliases = try values.decodeIfPresent([String].self, forKey: .aliases) ?? []
        category = try values.decodeIfPresent(EmoteCategory.self, forKey: .category) ?? .classic
        animation = try values.decodeIfPresent(String.self, forKey: .animation)
    }
    public func matches(_ query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace)
        let text = ([title, gameName] + aliases).joined(separator: " ")
        return words.allSatisfy { text.localizedStandardContains(String($0)) }
    }
}

public enum EmoteCategory: String, Codable, CaseIterable, Identifiable {
    case classic, fun, esports
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .classic: return "峡谷常青树"
        case .fun: return "整活型精品"
        case .esports: return "电竞趣味"
        }
    }
}

/// Frames are prepared from game assets, including their original layer timing.
public struct EmoteAnimation: Codable, Equatable {
    public struct Frame: Codable, Equatable {
        public let time: Double
        public let image: String
    }
    public let duration: Double
    public let canvasScale: Double
    public let frames: [Frame]
    public func frame(at time: Double) -> Frame? {
        guard time >= 0, time < duration, !frames.isEmpty else { return nil }
        var low = 0, high = frames.count
        while low < high {
            let middle = (low + high) / 2
            if frames[middle].time <= time { low = middle + 1 } else { high = middle }
        }
        return low > 0 ? frames[low - 1] : nil
    }
    public var isValid: Bool {
        duration.isFinite && duration > 0 && canvasScale.isFinite && canvasScale > 0 &&
        !frames.isEmpty && frames[0].time == 0 &&
        frames.allSatisfy { $0.time.isFinite && $0.time >= 0 && $0.time < duration && !$0.image.isEmpty } &&
        zip(frames, frames.dropFirst()).allSatisfy { $0.time < $1.time }
    }
}

public enum WheelSlot: Int, CaseIterable, Codable, Identifiable {
    case north, northEast, east, southEast, south, southWest, west, northWest, center
    public var id: Int { rawValue }
    public static var outer: [WheelSlot] { Array(allCases.prefix(8)) }
    public var title: String {
        ["上", "右上", "右", "右下", "下", "左下", "左", "左上", "中央"][rawValue]
    }
}

public struct Loadout: Codable, Equatable {
    public private(set) var slots: [Int?]
    public static let defaults = Loadout(slots: [3239, 3709, 4091, 1468, 4730, nil, nil, nil, 1492])
    public init(slots: [Int?]) { self.slots = slots }
    public subscript(_ slot: WheelSlot) -> Int? { slots.indices.contains(slot.rawValue) ? slots[slot.rawValue] : nil }
    public mutating func set(_ emoteID: Int?, at slot: WheelSlot) { slots[slot.rawValue] = emoteID }
    public func sanitized(available: Set<Int>) -> Loadout {
        guard slots.count == 9 else { return Self.defaults.sanitized(available: available) }
        return Loadout(slots: slots.map { id in id.flatMap { available.contains($0) ? $0 : nil } })
    }
}

public enum WheelGeometry {
    public static let centerRadius: CGFloat = 48
    public static let iconRadius: CGFloat = 106
    public static let outerRadius: CGFloat = 150
    public static let panelSide: CGFloat = 324
    public static func direction(at point: CGPoint, center: CGPoint, deadZone: CGFloat) -> CGFloat? {
        let dx = point.x-center.x, dy = point.y-center.y
        return hypot(dx, dy) <= deadZone ? nil : atan2(dx, dy)
    }
    public static func selection(at point: CGPoint, center: CGPoint, deadZone: CGFloat) -> WheelSlot {
        guard let angle = direction(at: point, center: center, deadZone: deadZone) else { return .center }
        let index = Int(floor((angle + .pi/8) / (.pi/4)))
        return WheelSlot.outer[(index % 8 + 8) % 8]
    }
    public static func clampedCenter(anchor: CGPoint, frame: CGRect, radius: CGFloat) -> CGPoint {
        func clamp(_ value: CGFloat, _ low: CGFloat, _ high: CGFloat) -> CGFloat {
            low > high ? (low+high)/2 : min(max(value, low), high)
        }
        return CGPoint(x: clamp(anchor.x, frame.minX+radius, frame.maxX-radius),
                       y: clamp(anchor.y, frame.minY+radius, frame.maxY-radius))
    }
}

public enum EffectTimeline {
    public static let duration = 3.0
    public struct Frame {
        public let scale: Double
        public let opacity: Double
        public let glow: Double
    }
    public static func frame(at time: Double) -> Frame {
        func smooth(_ t: Double) -> Double { let x = min(1, max(0, t)); return x*x*(3-2*x) }
        guard time >= 0 && time < duration else { return Frame(scale: 1, opacity: 0, glow: 0) }
        let scale: Double
        if time < 0.18 { scale = 0.4 + 0.66*smooth(time/0.18) }
        else if time < 0.38 { scale = 1.06 - 0.06*smooth((time-0.18)/0.2) }
        else { scale = 1 }
        return Frame(scale: scale, opacity: smooth(time/0.08)*(1-smooth((time-2.55)/0.45)),
                     glow: (1-smooth(time/0.7))*0.3)
    }
}
