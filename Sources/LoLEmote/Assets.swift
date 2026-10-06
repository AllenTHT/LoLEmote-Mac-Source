import AppKit
import AVFoundation
import EmoteCore

enum Assets {
    static let root: URL = {
        // Used by isolated checks and advanced local builds, never persisted.
        if let path = ProcessInfo.processInfo.environment["LOLEMOTE_ASSET_ROOT"], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        let bundled = Bundle.main.resourceURL ?? Bundle.main.bundleURL
        if FileManager.default.fileExists(atPath: bundled.appendingPathComponent("emotes.json").path) { return bundled }
        return URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources")
    }()
    private static let catalog: Result<[Emote], Error> = Result {
        try JSONDecoder().decode([Emote].self, from: Data(contentsOf: root.appendingPathComponent("emotes.json")))
    }
    static let emotes: [Emote] = (try? catalog.get()) ?? []
    private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.totalCostLimit = 32 * 1024 * 1024
        cache.countLimit = 96
        return cache
    }()
    private static var animations: [Int: EmoteAnimation] = [:]
    private static var checkedAnimations = Set<Int>()
    private static var audioDurations: [Int: Double] = [:]
    private static var checkedAudio = Set<Int>()
    static func emote(_ id: Int?) -> Emote? { emotes.first { $0.id == id } }
    static func image(_ id: Int?) -> NSImage? { emote(id).flatMap { image(path: $0.image) } }
    static func image(path: String) -> NSImage? {
        let key = path as NSString
        if let cached = imageCache.object(forKey: key) { return cached }
        guard let image = NSImage(contentsOf: root.appendingPathComponent(path)), image.isValid else { return nil }
        let pixels = image.representations.map { $0.pixelsWide * $0.pixelsHigh }.max() ?? 0
        imageCache.setObject(image, forKey: key, cost: pixels * 4)
        return image
    }
    static func isReady(_ emote: Emote) -> Bool { image(emote.id) != nil }
    static var availableEmotes: [Emote] { emotes.filter(isReady) }
    static func animation(_ emote: Emote) -> EmoteAnimation? {
        if checkedAnimations.contains(emote.id) { return animations[emote.id] }
        checkedAnimations.insert(emote.id)
        guard let path = emote.animation,
              let data = try? Data(contentsOf: root.appendingPathComponent(path)),
              let decoded = try? JSONDecoder().decode(EmoteAnimation.self, from: data), decoded.isValid,
              decoded.frames.allSatisfy({ image(path: $0.image) != nil }) else { return nil }
        animations[emote.id] = decoded
        return decoded
    }
    static func duration(_ emote: Emote) -> Double { animation(emote)?.duration ?? EffectTimeline.duration }
    static func sound(_ emote: Emote) -> URL { root.appendingPathComponent(emote.sound) }
    static func soundDuration(_ emote: Emote) -> Double? {
        if checkedAudio.contains(emote.id) { return audioDurations[emote.id] }
        checkedAudio.insert(emote.id)
        guard !emote.sound.isEmpty, let player = try? AVAudioPlayer(contentsOf: sound(emote)),
              player.duration.isFinite, player.duration > 0 else { return nil }
        audioDurations[emote.id] = player.duration
        return player.duration
    }
    static func status(_ emote: Emote) -> String {
        guard isReady(emote) else { return "未配置" }
        return "\(animation(emote) == nil ? "静态" : "动态") · \(soundDuration(emote) == nil ? "无声音" : "有声音")"
    }
    static func draw(_ id: Int?, in rect: CGRect, opacity: CGFloat = 1) {
        guard let image = image(id) else { return }
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: opacity, respectFlipped: true, hints: nil)
    }
    // Configuration errors are fatal. Individual missing media are warnings.
    static var errors: [String] {
        if case .failure(let error) = catalog { return ["表情清单无法读取：\(error.localizedDescription)"] }
        guard !emotes.isEmpty else { return ["表情清单为空"] }
        var result: [String] = []
        if Set(emotes.map(\.id)).count != emotes.count { result.append("表情清单含重复编号") }
        if emotes.contains(where: { $0.id <= 0 || $0.title.isEmpty || $0.image.isEmpty }) {
            result.append("表情清单中的编号、名称或图片路径无效")
        }
        return result
    }
    static var warnings: [String] {
        emotes.flatMap { emote -> [String] in
            var result: [String] = []
            if !isReady(emote) { result.append("\(emote.title)：图片缺失或无法读取，尚未配置") }
            if soundDuration(emote) == nil { result.append("\(emote.title)：声音缺失或无法读取，将静音播放") }
            if emote.animation != nil && animation(emote) == nil {
                result.append("\(emote.title)：动画缺失或不完整，将使用静态效果")
            }
            return result
        }
    }
    static let setupMessage = "尚未配置可用图片。请按 README 将 PNG 放入源码的 Resources/Emotes，重新构建并打开 App；声音和动态可稍后添加。"
}

final class SoundPlayer {
    private var player: AVAudioPlayer?
    private(set) var currentEmote: Int?
    var isPlaying: Bool { player?.isPlaying ?? false }
    func play(_ emote: Emote, volume: Double, muted: Bool) throws {
        stop()
        guard !muted, volume > 0, Assets.soundDuration(emote) != nil,
              let next = try? AVAudioPlayer(contentsOf: Assets.sound(emote)) else { return }
        next.volume = Float(volume)
        next.prepareToPlay()
        guard next.play() else { throw NSError(domain: "LoLEmote.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "声音无法播放，请检查音频输出设备。"]) }
        player = next; currentEmote = emote.id
    }
    func update(volume: Double, muted: Bool) { player?.volume = muted ? 0 : Float(volume) }
    func stop() { player?.stop(); player = nil; currentEmote = nil }
}
