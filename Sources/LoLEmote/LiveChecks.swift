import AppKit
import EmoteCore

/// Opt-in integration check. Posts only the wheel chord, pointer movement and
/// cancellation events while this app is in front. Uses an isolated loadout.
enum LiveChecks {
    static func run(to directory: URL) {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try exercise()
            try report(["status": "passed", "checks": ["nine slot selection including three empty slots", "all six modifier release orders", "short press", "Escape", "right click", "extra modifier", "real session event tap", "original anchor", "focus retained"], "accessibility": GlobalInput.isTrusted], to: directory)
        } catch {
            try? report(["status": "failed", "reason": error.localizedDescription, "accessibility": GlobalInput.isTrusted], to: directory)
        }
    }
    private static func report(_ values: [String: Any], to directory: URL) throws {
        var values = values
        values["date"] = ISO8601DateFormatter().string(from: Date())
        values["bundle"] = Bundle.main.bundleIdentifier ?? "unknown"
        try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("live-check.json"), options: .atomic)
    }
    private static func spin(_ seconds: Double) { RunLoop.main.run(until: Date().addingTimeInterval(seconds)) }
    private static func exercise() throws {
        try Diagnostics.require(GlobalInput.isTrusted, "请在辅助功能中允许 LoLEmote 后重新运行全局检查。")
        let physical = CGEventSource.flagsState(.combinedSessionState)
        try Diagnostics.require(physical.intersection([.maskControl, .maskAlternate, .maskCommand, .maskShift]).isEmpty && NSEvent.pressedMouseButtons == 0, "请松开键盘修饰键和鼠标按钮后重试。")
        let suite = "local.allentu.LoLEmote.live.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let model = AppModel(defaults: defaults)
        model.setMuted(true)
        let originalPointer = NSEvent.mouseLocation
        let source = CGEventSource(stateID: .privateState)!
        let keys: [(CGKeyCode, CGEventFlags)] = [(59, .maskControl), (58, .maskAlternate), (56, .maskShift)]
        var flags: CGEventFlags = []
        func postKey(_ key: CGKeyCode, down: Bool, type: CGEventType = .flagsChanged) {
            let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down)!
            event.type = type; event.flags = flags; event.post(tap: .cghidEventTap); spin(0.025)
        }
        func mouse(_ point: CGPoint, type: CGEventType = .mouseMoved) {
            let location = CGPoint(x: point.x, y: NSScreen.screens[0].frame.maxY-point.y)
            let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: type == .mouseMoved ? .left : .right)!
            event.flags = flags; event.post(tap: .cghidEventTap); spin(0.025)
        }
        func release(_ order: [Int] = [0, 1, 2]) {
            for i in order { flags.remove(keys[i].1); postKey(keys[i].0, down: false) }
        }
        defer {
            flags = []; keys.forEach { postKey($0.0, down: false) }; postKey(55, down: false)
            model.shutdown(); mouse(originalPointer)
            defaults.removePersistentDomain(forName: suite)
        }
        var actions: [GestureMachine.Action] = []
        let original = model.input.onAction
        model.input.onAction = { action in actions.append(action); original?(action) }
        model.setEnabled(true)
        try Diagnostics.require(model.enabled, model.message)
        let screen = NSScreen.main!.visibleFrame
        let anchor = CGPoint(x: screen.midX, y: screen.midY)
        func commits() -> [(WheelSlot, CGPoint)] {
            actions.compactMap { if case .commit(let slot, let point) = $0 { return (slot, point) }; return nil }
        }
        func arm(wait: Bool = true) throws {
            model.cancelEffects(); actions.removeAll(); mouse(anchor)
            for (key, flag) in keys { flags.insert(flag); postKey(key, down: true) }
            if wait {
                spin(0.21)
                try Diagnostics.require(model.overlay.wheel?.isVisible == true, "Global chord did not open wheel")
            }
        }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        for slot in WheelSlot.allCases {
            try arm()
            if slot != .center {
                let theta = Double(slot.rawValue)*Double.pi/4
                mouse(CGPoint(x: anchor.x+sin(theta)*106, y: anchor.y+cos(theta)*106))
            }
            release()
            try Diagnostics.require(commits().count == 1 && commits()[0].0 == slot, "Live selection: \(slot.title)")
            try Diagnostics.require(hypot(commits()[0].1.x-anchor.x, commits()[0].1.y-anchor.y) < 2, "Original anchor moved")
            let rendered = (model.overlay.effect?.contentView as? EmoteEffectView)?.emote.id
            try Diagnostics.require(rendered == model.settings.loadout[slot], "Empty/equipped slot output: \(slot.title)")
        }
        for order in [[0,1,2], [0,2,1], [1,0,2], [1,2,0], [2,0,1], [2,1,0]] {
            try arm(); release(order)
            try Diagnostics.require(commits().count == 1, "Live release order \(order)")
        }
        try arm(wait: false); release()
        try Diagnostics.require(commits().isEmpty && model.overlay.wheel == nil, "Short press emitted")
        try arm(); postKey(53, down: true, type: .keyDown); postKey(53, down: false, type: .keyUp); release()
        try Diagnostics.require(commits().isEmpty && model.overlay.wheel == nil, "Escape cancellation")
        try arm(); mouse(anchor, type: .rightMouseDown); mouse(anchor, type: .rightMouseUp); release()
        try Diagnostics.require(commits().isEmpty && model.overlay.wheel == nil, "Right-click cancellation")
        try arm(); flags.insert(.maskCommand); postKey(55, down: true)
        flags.remove(.maskCommand); postKey(55, down: false); release()
        try Diagnostics.require(commits().isEmpty && model.overlay.wheel == nil, "Extra-modifier cancellation")
        try Diagnostics.require(NSWorkspace.shared.frontmostApplication?.processIdentifier == front, "Global overlay changed focus")
    }
}
