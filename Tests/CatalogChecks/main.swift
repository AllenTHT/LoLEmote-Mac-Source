import AppKit
import Darwin
import EmoteCore

var checks = 0
func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL: \(message)\n", stderr); exit(1) }
    checks += 1
}
func spin(_ duration: Double) { RunLoop.main.run(until: Date().addingTimeInterval(duration)) }
func memoryBytes() -> UInt64 {
    var info = mach_task_basic_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info)/MemoryLayout<integer_t>.size)
    let status = withUnsafeMutablePointer(to: &info) { pointer in
        pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }
    require(status == KERN_SUCCESS, "memory measurement")
    return UInt64(info.resident_size)
}

_ = NSApplication.shared
require(Assets.errors.isEmpty, "all catalog resources available")
let suite = "local.allentu.LoLEmote.catalog.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let model = AppModel(defaults: defaults)
model.setMuted(true)
for emote in Assets.emotes {
    for slot in WheelSlot.allCases {
        model.editingSlot = slot; model.assign(emote)
        require(model.settings.loadout[slot] == emote.id, "equip \(emote.id) in \(slot)")
    }
    require(Settings.read(from: defaults) == model.settings, "reload expanded ID \(emote.id)")
    model.preview(emote)
    require(model.previewEmote == emote && !model.sound.isPlaying, "muted preview \(emote.id)")
    model.cancelEffects()
    require(model.previewEmote == nil && !model.sound.isPlaying, "cancel \(emote.id)")
}
for category in EmoteCategory.allCases {
    require(Assets.emotes.contains { $0.category == category }, "category has entries: \(category)")
}
let animated = Assets.emotes.filter { $0.animation != nil }
require(animated.count == 2, "verified animated originals")
let penguin = Assets.emote(3277)!
require(Assets.duration(penguin) > 3, "original animation is longer than legacy timeline")
model.preview(penguin)
spin(3.04)
require(model.previewEmote?.id == penguin.id, "preview must not be truncated at three seconds")
spin(0.3)
require(model.previewEmote == nil, "preview finishes at its own duration")

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 200, pixelsHigh: 200,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
var memory: [UInt64] = []
for pass in 0..<12 {
    for emote in animated {
        let sequence = Assets.animation(emote)!
        autoreleasepool {
            let view = EmoteEffectView(frame: CGRect(x: 0, y: 0, width: 200, height: 200), emote: emote, size: 64)
            for frame in sequence.frames {
                autoreleasepool {
                    NSGraphicsContext.saveGraphicsState()
                    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
                    view.seek(to: frame.time); view.draw(view.bounds)
                    NSGraphicsContext.restoreGraphicsState()
                }
            }
            view.start(); view.stop()
            require(view.elapsed == sequence.duration, "stop animated renderer")
        }
    }
    memory.append(memoryBytes())
    print("render pass \(pass): resident memory \(memory.last! / 1024 / 1024) MiB")
}
require(memory.last! <= memory[7] + 16*1024*1024, "cache memory remains bounded after repeated full animation playback")
model.shutdown()
print("PASS \(checks) catalog checks: every ID in every slot, persistence, muted preview, replacement/cancellation, original duration, full-frame render loops, and bounded cache memory.")
