import AppKit
import QuartzCore
import EmoteCore

let emoteGold = NSColor(srgbRed: 0.80, green: 0.68, blue: 0.43, alpha: 1)

final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    init(frame: CGRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false; backgroundColor = .clear; hasShadow = false
        ignoresMouseEvents = true; hidesOnDeactivate = false; isReleasedWhenClosed = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .canJoinAllApplications, .ignoresCycle]
        animationBehavior = .none; isExcludedFromWindowsMenu = true
    }
}

final class WheelView: NSView {
    var loadout = Loadout.defaults { didSet { needsDisplay = true } }
    var selected: WheelSlot = .center { didSet { needsDisplay = true } }
    override init(frame: CGRect) { super.init(frame: frame); wantsLayer = true }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isOpaque: Bool { false }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let s = min(bounds.width, bounds.height) / WheelGeometry.panelSide
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let outer = WheelGeometry.outerRadius*s, inner = WheelGeometry.centerRadius*s
        for slot in WheelSlot.outer {
            let degrees = CGFloat(90-slot.rawValue*45), theta = degrees * .pi/180
            let sector = NSBezierPath()
            sector.appendArc(withCenter: c, radius: outer, startAngle: degrees+22.5, endAngle: degrees-22.5, clockwise: true)
            sector.appendArc(withCenter: c, radius: inner, startAngle: degrees-22.5, endAngle: degrees+22.5, clockwise: false)
            sector.close()
            NSColor(srgbRed: 0.025, green: 0.055, blue: 0.075, alpha: 0.94).setFill(); sector.fill()
            if selected == slot {
                context.saveGState(); sector.addClip()
                NSGradient(starting: emoteGold.withAlphaComponent(0.08), ending: emoteGold.withAlphaComponent(0.40))?
                    .draw(fromCenter: c, radius: inner, toCenter: c, radius: outer, options: [])
                context.restoreGState()
            }
            emoteGold.withAlphaComponent(selected == slot ? 0.9 : 0.25).setStroke()
            sector.lineWidth = (selected == slot ? 1.5 : 0.6)*s; sector.stroke()
            let p = CGPoint(x: c.x+cos(theta)*WheelGeometry.iconRadius*s, y: c.y+sin(theta)*WheelGeometry.iconRadius*s)
            let side: CGFloat = (selected == slot ? 64 : 52)*s
            if let id = loadout[slot] {
                Assets.draw(id, in: CGRect(x: p.x-side/2, y: p.y-side/2, width: side, height: side))
            } else {
                NSColor(white: 0.45, alpha: 0.45).setStroke()
                let mark = NSBezierPath(); mark.move(to: CGPoint(x: p.x-5*s, y: p.y)); mark.line(to: CGPoint(x: p.x+5*s, y: p.y))
                mark.move(to: CGPoint(x: p.x, y: p.y-5*s)); mark.line(to: CGPoint(x: p.x, y: p.y+5*s))
                mark.lineWidth = s; mark.stroke()
            }
        }
        let core = NSBezierPath(ovalIn: CGRect(x: c.x-inner, y: c.y-inner, width: inner*2, height: inner*2))
        NSColor(srgbRed: 0.035, green: 0.07, blue: 0.09, alpha: 0.97).setFill(); core.fill()
        emoteGold.withAlphaComponent(selected == .center ? 1 : 0.5).setStroke(); core.lineWidth = 2*s; core.stroke()
        if let id = loadout[.center] {
            let side: CGFloat = (selected == .center ? 62 : 54)*s
            Assets.draw(id, in: CGRect(x: c.x-side/2, y: c.y-side/2+7*s, width: side, height: side))
        }
        let title = Assets.emote(loadout[selected]).map { Assets.isReady($0) ? $0.title : "未配置" } ?? "空位"
        let label = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 10*s, weight: .medium), .foregroundColor: emoteGold])
        label.draw(at: CGPoint(x: c.x-label.size().width/2, y: c.y-34*s))
    }
}

final class EmoteEffectView: NSView {
    let emote: Emote
    let imageSize: CGFloat
    private(set) var elapsed = EffectTimeline.duration
    private var started: CFTimeInterval = 0
    private var timer: Timer?
    private var sequence: EmoteAnimation?
    private var duration: Double { sequence?.duration ?? EffectTimeline.duration }
    init(frame: CGRect, emote: Emote, size: Double) {
        self.emote = emote; imageSize = CGFloat(size)
        sequence = Assets.animation(emote)
        super.init(frame: frame)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isOpaque: Bool { false }
    deinit { timer?.invalidate() }
    func start() {
        timer?.invalidate(); started = CACurrentMediaTime(); seek(to: 0)
        let next = Timer(timeInterval: 1/60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            self.seek(to: CACurrentMediaTime()-self.started)
            if self.elapsed >= self.duration { timer.invalidate(); self.timer = nil }
        }
        timer = next; RunLoop.main.add(next, forMode: .common)
    }
    func seek(to time: Double) { elapsed = time; needsDisplay = true }
    func stop() { timer?.invalidate(); timer = nil; seek(to: duration) }
    override func viewDidChangeBackingProperties() { super.viewDidChangeBackingProperties(); needsDisplay = true }
    override func draw(_ dirtyRect: NSRect) {
        guard NSGraphicsContext.current != nil else { return }
        if let sequence {
            guard let frame = sequence.frame(at: elapsed), let image = Assets.image(path: frame.image) else { return }
            let side = imageSize * sequence.canvasScale
            NSGraphicsContext.current?.imageInterpolation = .high
            image.draw(in: CGRect(x: bounds.midX-side/2, y: bounds.midY-side/2, width: side, height: side),
                       from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
            return
        }
        let frame = EffectTimeline.frame(at: elapsed)
        guard frame.opacity > 0 else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        if frame.glow > 0 {
            NSGradient(starting: emoteGold.withAlphaComponent(frame.glow*frame.opacity), ending: .clear)?
                .draw(fromCenter: center, radius: 0, toCenter: center, radius: imageSize*0.68, options: [])
        }
        let side = imageSize*frame.scale
        Assets.draw(emote.id, in: CGRect(x: center.x-side/2, y: center.y-side/2, width: side, height: side), opacity: frame.opacity)
    }
}

final class OverlayController {
    private(set) var wheel: OverlayPanel?
    private(set) var effect: OverlayPanel?
    private var cleanup: DispatchWorkItem?
    @discardableResult func showWheel(at anchor: CGPoint, loadout: Loadout) -> CGPoint {
        hideWheel()
        let side = WheelGeometry.panelSide
        let center = fittedCenter(anchor, side: side)
        let panel = OverlayPanel(frame: CGRect(x: center.x-side/2, y: center.y-side/2, width: side, height: side))
        let view = WheelView(frame: CGRect(origin: .zero, size: panel.frame.size)); view.loadout = loadout
        panel.contentView = view; panel.orderFrontRegardless(); wheel = panel
        return center
    }
    func select(_ slot: WheelSlot) { (wheel?.contentView as? WheelView)?.selected = slot }
    func hideWheel() { wheel?.close(); wheel = nil }
    func showEmote(_ emote: Emote, at anchor: CGPoint, size: Double) {
        hideEffect()
        let side = CGFloat(size)*max(1.5, Assets.animation(emote)?.canvasScale ?? 1.5)
        let center = fittedCenter(anchor, side: side)
        let panel = OverlayPanel(frame: CGRect(x: center.x-side/2, y: center.y-side/2, width: side, height: side))
        let view = EmoteEffectView(frame: CGRect(origin: .zero, size: panel.frame.size), emote: emote, size: size)
        panel.contentView = view; panel.orderFrontRegardless(); view.start(); effect = panel
        let work = DispatchWorkItem { [weak self] in self?.hideEffect() }
        cleanup = work; DispatchQueue.main.asyncAfter(deadline: .now()+Assets.duration(emote), execute: work)
    }
    private func fittedCenter(_ anchor: CGPoint, side: CGFloat) -> CGPoint {
        let screen = NSScreen.screens.first { NSMouseInRect(anchor, $0.frame, false) } ?? NSScreen.main
        return WheelGeometry.clampedCenter(anchor: anchor, frame: screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900), radius: side/2)
    }
    private func hideEffect() {
        cleanup?.cancel(); cleanup = nil
        (effect?.contentView as? EmoteEffectView)?.stop(); effect?.close(); effect = nil
    }
    func clear() { hideWheel(); hideEffect() }
}
