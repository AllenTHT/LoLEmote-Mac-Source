import Foundation
import EmoteCore

var count = 0
func check(_ condition: @autoclosure () -> Bool, _ name: String) {
    guard condition() else { fputs("FAIL: \(name)\n", stderr); exit(1) }
    count += 1
}
func commits(_ actions: [GestureMachine.Action]) -> Int {
    actions.filter { if case .commit = $0 { return true }; return false }.count
}
func permutations<T>(_ items: [T]) -> [[T]] {
    items.isEmpty ? [[]] : items.indices.flatMap { i in
        var rest = items; let item = rest.remove(at: i)
        return permutations(rest).map { [item]+$0 }
    }
}
let anchor = CGPoint(x: 500, y: 500)
for chord in TriggerChord.allCases {
    let bits: [Modifiers] = [.control, .option, .command, .shift].filter { chord.modifiers.contains($0) }
    for releaseOrder in permutations(bits) {
        let machine = GestureMachine(); machine.chord = chord
        check(machine.flagsChanged(chord.modifiers, at: anchor, otherInputHeld: false) == [.arm(anchor)], "arm \(chord)")
        check(machine.delayElapsed() == [.show(anchor)], "delayed show")
        var flags = chord.modifiers, actions: [GestureMachine.Action] = []
        for bit in releaseOrder { flags.remove(bit); actions += machine.flagsChanged(flags, at: anchor, otherInputHeld: false) }
        check(commits(actions) == 1, "every release order commits once")
        check(actions.contains(.commit(.center, anchor)), "center uses original anchor")
        check(machine.phase == .idle, "all released resets")
    }
    for cancelWhileOpen in [false, true] {
        let machine = GestureMachine(); machine.chord = chord
        _ = machine.flagsChanged(chord.modifiers, at: anchor, otherInputHeld: false)
        if cancelWhileOpen { _ = machine.delayElapsed() }
        check(machine.cancel() == [.hide], "cancel before/after opening")
        check(commits(machine.flagsChanged([], at: anchor, otherInputHeld: false)) == 0, "cancel never sends")
    }
    let short = GestureMachine(); short.chord = chord
    _ = short.flagsChanged(chord.modifiers, at: anchor, otherInputHeld: false)
    check(commits(short.flagsChanged([], at: anchor, otherInputHeld: false)) == 0, "short press")
    check(short.delayElapsed().isEmpty, "old timer cannot reopen")
    let held = GestureMachine(); held.chord = chord
    check(held.flagsChanged(chord.modifiers, at: anchor, otherInputHeld: true).isEmpty, "held key or drag prevents arming")
    check(held.delayElapsed().isEmpty, "held input stays blocked")
    let extra = GestureMachine(); extra.chord = chord
    _ = extra.flagsChanged(chord.modifiers, at: anchor, otherInputHeld: false); _ = extra.delayElapsed()
    let all: Modifiers = [.control, .option, .command, .shift]
    check(extra.flagsChanged(all, at: anchor, otherInputHeld: false) == [.hide], "fourth modifier cancels")
    check(commits(extra.flagsChanged([], at: anchor, otherInputHeld: false)) == 0, "extra modifier no commit")
}
for slot in WheelSlot.outer {
    let angle = Double(slot.rawValue)*Double.pi/4
    let point = CGPoint(x: anchor.x+sin(angle)*110, y: anchor.y+cos(angle)*110)
    check(WheelGeometry.selection(at: point, center: anchor, deadZone: 48) == slot, "direction \(slot)")
}
check(WheelGeometry.selection(at: CGPoint(x: 548, y: 500), center: anchor, deadZone: 48) == .center, "center boundary")
check(WheelGeometry.selection(at: CGPoint(x: 548.01, y: 500), center: anchor, deadZone: 48) == .east, "outside center")
for frame in [CGRect(x: 0, y: 0, width: 1440, height: 900), CGRect(x: -1600, y: -400, width: 1600, height: 1200)] {
    for point in [CGPoint(x: frame.minX, y: frame.minY), CGPoint(x: frame.maxX, y: frame.maxY)] {
        let center = WheelGeometry.clampedCenter(anchor: point, frame: frame, radius: 162)
        check(frame.contains(CGRect(x: center.x-162, y: center.y-162, width: 324, height: 324)), "clamped wheel fits screen")
    }
}
let edge = GestureMachine()
_ = edge.flagsChanged(edge.chord.modifiers, at: .zero, otherInputHeld: false); _ = edge.delayElapsed()
check(edge.setWheelCenter(CGPoint(x: 162, y: 162)).isEmpty, "edge no artificial selection")
check(edge.flagsChanged([], at: .zero, otherInputHeld: false).contains(.commit(.center, .zero)), "edge original anchor retained")
var loadout = Loadout.defaults
check(loadout.slots.count == 9 && loadout.slots.compactMap { $0 }.count == 6, "six equipped nine slots")
check(loadout[.center] == 1492 && loadout[.northWest] == nil, "default center and empty")
for slot in WheelSlot.allCases { loadout.set(3239, at: slot); check(loadout[slot] == 3239, "equip \(slot)"); loadout.set(nil, at: slot); check(loadout[slot] == nil, "clear \(slot)") }
let restored = try JSONDecoder().decode(Loadout.self, from: JSONEncoder().encode(loadout))
check(restored == loadout, "loadout persistence roundtrip")
check(EffectTimeline.frame(at: 0.18).scale > 1, "bounce overshoot")
check(EffectTimeline.frame(at: 1).scale == 1 && EffectTimeline.frame(at: 1).opacity == 1, "hold")
check(EffectTimeline.frame(at: 2.8).opacity > 0 && EffectTimeline.frame(at: 2.8).opacity < 1, "fade")
check(EffectTimeline.frame(at: 3).opacity == 0, "finish at three seconds")
let legacyEmote = try JSONDecoder().decode(Emote.self, from: Data("""
{"id":1468,"title":"机器人问号","gameName":"Does Not Compute","image":"Emotes/1468.png","sound":"Sounds/1468.wav"}
""".utf8))
check(legacyEmote.aliases.isEmpty && legacyEmote.category == .classic && legacyEmote.animation == nil, "legacy manifest compatibility")
let searchable = Emote(id: 1468, title: "机器人问号", gameName: "Does Not Compute", image: "a", sound: "b",
                       aliases: ["无法求解", "机器人吃手", "布里茨", "Blitzcrank"])
check(searchable.matches(" 无法求解 ") && searchable.matches("BLITZCRANK"), "Chinese aliases and case insensitive champion search")
check(searchable.matches("机器人 问号") && !searchable.matches("机器人 提莫"), "all search terms must match")
check(searchable.matches(""), "empty search includes emotes")
let animation = try JSONDecoder().decode(EmoteAnimation.self, from: Data("""
{"duration":4.5,"canvasScale":2,"frames":[{"time":0,"image":"a"},{"time":0.1,"image":"b"},{"time":4,"image":"c"}]}
""".utf8))
check(animation.isValid, "long animation manifest")
check(animation.frame(at: -0.01) == nil && animation.frame(at: 4.5) == nil, "animation outside duration is blank")
check(animation.frame(at: 0)?.image == "a" && animation.frame(at: 0.099)?.image == "a", "frame start and hold")
check(animation.frame(at: 0.1)?.image == "b" && animation.frame(at: 4.49)?.image == "c", "exact frame boundary and long duration")
let unsorted = try JSONDecoder().decode(EmoteAnimation.self, from: Data("""
{"duration":2,"canvasScale":1,"frames":[{"time":0,"image":"a"},{"time":0,"image":"b"}]}
""".utf8))
check(!unsorted.isValid, "invalid duplicate timestamps rejected")
print("PASS \(count) core checks: chords, release orders, selection, cancellation, persistence, search, legacy manifests, and animation boundaries.")
