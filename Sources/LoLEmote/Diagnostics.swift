import AppKit
import SwiftUI
import AVFoundation
import EmoteCore

enum Diagnostics {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "LoLEmote.Check", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func bitmap(size: CGSize, scale: CGFloat = 2, draw: () -> Void) -> NSBitmapImageRep {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width*scale), pixelsHigh: Int(size.height*scale), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(srgbRed: 0.035, green: 0.060, blue: 0.080, alpha: 1).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()
        draw(); NSGraphicsContext.restoreGraphicsState()
        return rep
    }
    static func draw(_ view: NSView, at point: CGPoint) {
        let context = NSGraphicsContext.current!.cgContext
        context.saveGState(); context.translateBy(x: point.x, y: point.y)
        view.draw(view.bounds)
        context.setBlendMode(.destinationOver)
        context.setFillColor(NSColor(srgbRed: 0.035, green: 0.060, blue: 0.080, alpha: 1).cgColor)
        context.fill(view.bounds); context.restoreGState()
    }
    static func pixels(_ rep: NSBitmapImageRep) -> Data { Data(bytes: rep.bitmapData!, count: rep.bytesPerRow*rep.pixelsHigh) }
    static func save(_ rep: NSBitmapImageRep, to url: URL) throws { try rep.representation(using: .png, properties: [:])!.write(to: url) }
    static func visuals(to directory: URL) throws {
        _ = NSApplication.shared
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let wheelGrid = bitmap(size: CGSize(width: 972, height: 972)) {
            for slot in WheelSlot.allCases {
                let view = WheelView(frame: CGRect(x: 0, y: 0, width: 324, height: 324)); view.selected = slot
                draw(view, at: CGPoint(x: (slot.rawValue%3)*324, y: (2-slot.rawValue/3)*324))
            }
        }
        try save(wheelGrid, to: directory.appendingPathComponent("wheel-nine-selections-2x.png"))
        let wheel = WheelView(frame: CGRect(x: 0, y: 0, width: 324, height: 324))
        try save(bitmap(size: wheel.bounds.size, scale: 1) { draw(wheel, at: .zero) }, to: directory.appendingPathComponent("wheel-1x.png"))
        for size in [64.0, 96.0, 128.0] {
            let rows = max(1, (Assets.availableEmotes.count + 2)/3)
            let grid = bitmap(size: CGSize(width: 576, height: rows*192)) {
                for (index, emote) in Assets.availableEmotes.enumerated() {
                    let effect = EmoteEffectView(frame: CGRect(x: 0, y: 0, width: 192, height: 192), emote: emote, size: size)
                    effect.seek(to: 1)
                    draw(effect, at: CGPoint(x: (index%3)*192, y: (rows-1-index/3)*192))
                }
            }
            try save(grid, to: directory.appendingPathComponent("emotes-\(Int(size))pt-2x.png"))
        }
        let times = [0.04, 0.18, 1.0, 2.8, 3.0]
        let phases = bitmap(size: CGSize(width: 960, height: 1152)) {
            for (row, emote) in Assets.availableEmotes.prefix(6).enumerated() {
                for (column, time) in times.enumerated() {
                    let effect = EmoteEffectView(frame: CGRect(x: 0, y: 0, width: 192, height: 192), emote: emote, size: 128)
                    effect.seek(to: time); draw(effect, at: CGPoint(x: column*192, y: (5-row)*192))
                }
            }
        }
        try save(phases, to: directory.appendingPathComponent("animation-phases-2x.png"))
        for emote in Assets.availableEmotes where emote.animation != nil {
            let duration = Assets.duration(emote)
            let snapshots = bitmap(size: CGSize(width: 1600, height: 320)) {
                for (column, time) in [0.18, 0.55, 0.85, 1.2, duration-0.12].enumerated() {
                    let effect = EmoteEffectView(frame: CGRect(x: 0, y: 0, width: 320, height: 320), emote: emote, size: 96)
                    effect.seek(to: time)
                    draw(effect, at: CGPoint(x: column*320, y: 0))
                }
            }
            try save(snapshots, to: directory.appendingPathComponent("dynamic-\(emote.id)-phases.png"))
        }
        for emote in Assets.availableEmotes {
            let view = EmoteEffectView(frame: CGRect(x: 0, y: 0, width: 192, height: 192), emote: emote, size: 96)
            let blank = pixels(bitmap(size: view.bounds.size) {})
            view.seek(to: 0.18); let a = pixels(bitmap(size: view.bounds.size) { draw(view, at: .zero) })
            view.seek(to: 2.8); let b = pixels(bitmap(size: view.bounds.size) { draw(view, at: .zero) })
            view.stop(); let stopped = pixels(bitmap(size: view.bounds.size) { draw(view, at: .zero) })
            try require(a != blank && b != a && stopped == blank, "Effect animation/stop pixels: \(emote.title)")
        }
        let suite = "local.allentu.LoLEmote.visual.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        let hosting = NSHostingView(rootView: ControlView(model: model))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 820, height: 860), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = hosting
        window.appearance = NSAppearance(named: .darkAqua)
        hosting.frame = CGRect(x: 0, y: 0, width: 820, height: 860)
        hosting.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds)!
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        try save(rep, to: directory.appendingPathComponent("control-window.png"))
        model.shutdown(); window.close()
        print("PASS render lifecycle comparisons; exported nine selections, 64/96/128pt Retina emotes, animation phases, and control window.")
    }
    static func behavior() throws {
        _ = NSApplication.shared
        let suite = "local.allentu.LoLEmote.check.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = AppModel(defaults: defaults)
        defer { model.shutdown() }
        try require(!model.enabled && !model.settings.enabled && model.settings.size == 96 && model.settings.volume == 0.55, "First-run defaults")
        model.setSize(128); model.setVolume(0.27); model.setMuted(true); model.setChord(.controlCommandShift)
        let ready = Assets.availableEmotes
        if let first = ready.first {
            let replacement = ready.dropFirst().first ?? first
            model.editingSlot = .northWest; model.assign(first)
            model.preview(first)
            try require(model.previewEmote?.id == first.id && !model.sound.isPlaying && !model.enabled, "Permission-free muted preview")
            model.preview(replacement)
            try require(model.previewEmote?.id == replacement.id, "Preview replacement")
            model.setEnabled(false)
            try require(model.previewEmote == nil && !model.sound.isPlaying, "Disable clears preview/audio")
            if let screen = NSScreen.main {
                let point = CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY)
                let priorApp = NSWorkspace.shared.frontmostApplication?.processIdentifier
                model.overlay.showWheel(at: point, loadout: model.settings.loadout)
                try require(model.overlay.wheel?.ignoresMouseEvents == true && model.overlay.wheel?.canBecomeKey == false && model.overlay.wheel?.isVisible == true, "Wheel visibility/click-through/focus flags")
                model.overlay.showEmote(first, at: point, size: 128)
                let old = model.overlay.effect!
                model.overlay.showEmote(replacement, at: point, size: 96)
                try require(!old.isVisible && (model.overlay.effect?.contentView as? EmoteEffectView)?.emote.id == replacement.id, "Desktop effect replacement")
                try require(NSWorkspace.shared.frontmostApplication?.processIdentifier == priorApp, "Overlay stole application focus")
                model.setEnabled(false)
                try require(model.overlay.effect == nil && model.overlay.wheel == nil, "Disable clears panels")
            }
        } else {
            model.restoreState()
            try require(model.message == Assets.setupMessage && !model.enabled, "Empty asset setup guidance")
            model.setEnabled(true)
            try require(!model.enabled && !model.awaitingPermission, "No permission request without usable images")
        }
        try require(Settings.read(from: defaults) == model.settings, "Settings reload differs")
        print("PASS defaults, isolated settings, setup guidance or available-media preview/overlay checks.")
        print("Accessibility for this process: \(GlobalInput.isTrusted). Actual global input requires a separate live check.")
    }
    static func audio() throws {
        let sound = SoundPlayer()
        let ready = Assets.availableEmotes.filter { Assets.soundDuration($0) != nil }
        guard let first = ready.first else { print("SKIP audio playback: no usable local sounds."); return }
        for emote in ready {
            let decoded = try AVAudioPlayer(contentsOf: Assets.sound(emote))
            try sound.play(emote, volume: 0.55, muted: false)
            try require(sound.isPlaying && sound.currentEmote == emote.id, "Cannot start \(emote.title)")
            print("Playing \(emote.title) (\(String(format: "%.3f", decoded.duration))s)")
            RunLoop.main.run(until: Date().addingTimeInterval(decoded.duration+0.15))
            try require(!sound.isPlaying, "Audio did not finish: \(emote.title)")
        }
        let replacement = ready.dropFirst().first ?? first
        try sound.play(first, volume: 0.55, muted: false)
        try sound.play(replacement, volume: 0.55, muted: false)
        try require(sound.currentEmote == replacement.id, "Audio replacement")
        sound.stop(); try require(!sound.isPlaying && sound.currentEmote == nil, "Audio stop")
        print("PASS \(ready.count) audio files played through the output device, replacement, and immediate stop. Listening assessment is separate.")
    }
}
