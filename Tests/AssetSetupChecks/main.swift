import AppKit
import SwiftUI
import EmoteCore

let mode = CommandLine.arguments[1]
_ = NSApplication.shared
var count = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fputs("FAIL [\(mode)] \(message)\n", stderr); exit(1) }
    count += 1
}
let suite = "local.allentu.LoLEmote.assets.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let model = AppModel(defaults: defaults)
defer { model.shutdown() }
if mode == "invalid" {
    check(!Assets.errors.isEmpty, "invalid catalog is fatal")
    model.setEnabled(true)
    check(!model.enabled && !model.awaitingPermission && GlobalInput.permissionRequests == 0, "invalid catalog never requests global permission")
} else {
    check(Assets.errors.isEmpty && Assets.emotes.count == 30, "catalog configuration remains complete")
    model.restoreState()
    if mode == "empty" {
        check(Assets.availableEmotes.isEmpty && model.message == Assets.setupMessage, "empty setup guidance")
        model.setEnabled(true)
        check(!model.enabled && !model.awaitingPermission && GlobalInput.permissionRequests == 0, "empty setup blocks input before permission prompt")
        model.assign(Assets.emotes[0]); model.preview(Assets.emotes[0])
        check(model.previewEmote == nil && !model.sound.isPlaying && model.settings.loadout == Loadout.defaults, "missing PNG cannot equip or preview")
    } else {
        let first = Assets.emote(3239)!
        check(Assets.isReady(first), "synthetic image is usable")
        if mode == "image" { check(!Assets.isReady(Assets.emote(1492)!), "corrupt PNG remains unconfigured") }
        model.editingSlot = .center; model.assign(first)
        check(model.settings.loadout[.center] == first.id, "single image can be equipped")
        model.preview(first)
        check(model.previewEmote == first, "single image can be previewed without global permission")
        model.cancelEffects()
        GlobalInput.isTrusted = false; model.setEnabled(true)
        check(model.awaitingPermission && !model.enabled, "ready image reaches permission guidance")
        GlobalInput.isTrusted = true; model.checkPermission()
        check(model.enabled && model.input.running, "ready subset can enable input")
        let point = CGPoint(x: NSScreen.main!.visibleFrame.midX, y: NSScreen.main!.visibleFrame.midY)
        model.input.onAction?(.show(point))
        check(model.overlay.wheel?.isVisible == true, "subset wheel opens")
        model.input.onAction?(.hide)
        model.input.onAction?(.commit(.center, point))
        check(model.overlay.effect?.isVisible == true && model.overlay.wheel == nil, "desktop commit with subset")
        if mode == "image" || mode == "corrupt" {
            check(!model.sound.isPlaying && Assets.soundDuration(first) == nil, "missing or corrupt audio silently degrades")
        }
        let dynamic = Assets.emote(3277)!
        if mode == "corrupt" {
            check(Assets.animation(dynamic) == nil && Assets.duration(dynamic) == 3, "missing frame invalidates the entire animation")
            check(Assets.warnings.contains { $0.contains("动画") }, "animation degradation reported")
        }
        if mode == "complete" {
            check(Assets.soundDuration(first) == 1, "synthetic WAV decodes")
            check(Assets.animation(dynamic) != nil && Assets.duration(dynamic) == 0.8, "complete animation uses authored duration")
            let sound = SoundPlayer()
            try sound.play(first, volume: 0.001, muted: false)
            check(sound.isPlaying && sound.currentEmote == first.id, "optional valid sound starts")
            sound.stop(); check(!sound.isPlaying, "optional sound stops")
            model.preview(dynamic)
            check(model.previewEmote == dynamic, "complete animation preview")
            model.cancelEffects()
        }
        model.setEnabled(false)
        check(model.overlay.effect == nil && !model.sound.isPlaying && model.previewEmote == nil, "disable cleanup after subset playback")
        check(Settings.read(from: defaults) == model.settings, "settings round trip with subset")
        let before = model.settings.loadout
        let missing = Assets.emotes.first { !Assets.isReady($0) }!
        model.assign(missing)
        check(model.settings.loadout == before, "unconfigured entry cannot replace equipped image")
    }
    if CommandLine.arguments.count > 2 {
        let host = NSHostingView(rootView: ControlView(model: model))
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 900, height: 920), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        window.appearance = NSAppearance(named: .darkAqua)
        host.frame = CGRect(x: 0, y: 0, width: 900, height: 920)
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.15))
        let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
        host.cacheDisplay(in: host.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
        window.close()
    }
}
print("PASS \(mode): \(count) asset setup checks; isolated settings, controlled global-input boundary.")
