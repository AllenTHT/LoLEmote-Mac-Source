import AppKit
import Combine
import EmoteCore

final class AppModel: ObservableObject {
    @Published private(set) var settings: Settings
    @Published private(set) var enabled = false
    @Published private(set) var awaitingPermission = false
    @Published private(set) var message = "桌面表情已关闭，仍可在窗口中试用。"
    @Published var editingSlot: WheelSlot = .center
    @Published private(set) var previewEmote: Emote?
    @Published private(set) var previewToken = UUID()
    let overlay = OverlayController()
    let sound = SoundPlayer()
    let input = GlobalInput()
    private let defaults: UserDefaults
    private var previewCleanup: DispatchWorkItem?
    private var permissionTimer: Timer?
    private var appObservers: [NSObjectProtocol] = []
    private var workspaceObservers: [NSObjectProtocol] = []
    var onStateChange: (() -> Void)?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults; settings = Settings.read(from: defaults)
        input.onAction = { [weak self] in self?.handle($0) }
        input.onUnavailable = { [weak self] in
            self?.setEnabled(false)
            self?.message = "全局输入已暂停，请检查辅助功能权限后重新开启。"
        }
        let center = NotificationCenter.default
        appObservers.append(center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.checkPermission() })
        appObservers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.cancelEffects() })
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.willSleepNotification,
                     NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.didActivateApplicationNotification] {
            workspaceObservers.append(workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.cancelEffects() })
        }
    }
    deinit {
        appObservers.forEach { NotificationCenter.default.removeObserver($0) }
        workspaceObservers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        permissionTimer?.invalidate()
    }
    func restoreState() {
        if settings.enabled {
            if GlobalInput.isTrusted { setEnabled(true) }
            else { message = "上次已启用；请在辅助功能中允许 LoLEmote，再开启开关。" }
        }
        if !Assets.errors.isEmpty { message = Assets.errors.joined(separator: "、") }
        else if Assets.availableEmotes.isEmpty { message = Assets.setupMessage }
    }
    private func save() { settings.save(to: defaults); onStateChange?() }
    func assign(_ emote: Emote?) {
        if let emote, !Assets.isReady(emote) { message = "该表情尚未配置可用图片，请按 README 准备素材并重新构建。"; return }
        cancelEffects()
        settings.loadout.set(emote?.id, at: editingSlot)
        save()
    }
    func setChord(_ chord: TriggerChord) {
        cancelEffects(); settings.chord = chord.rawValue; save()
        if enabled { setEnabled(true) }
    }
    func setSize(_ value: Double) { cancelEffects(); settings.size = min(128, max(64, value)); save() }
    func setVolume(_ value: Double) { settings.volume = min(1, max(0, value)); save(); sound.update(volume: settings.volume, muted: settings.muted) }
    func setMuted(_ value: Bool) { settings.muted = value; save(); sound.update(volume: settings.volume, muted: value) }
    func setEnabled(_ value: Bool) {
        if !value {
            permissionTimer?.invalidate(); permissionTimer = nil
            awaitingPermission = false; input.stop(); cancelEffects()
            enabled = false; settings.enabled = false; save()
            message = "桌面表情已关闭，仍可在窗口中试用。"
            return
        }
        guard Assets.errors.isEmpty else { message = Assets.errors.joined(separator: "、"); return }
        guard !Assets.availableEmotes.isEmpty else { message = Assets.setupMessage; return }
        guard GlobalInput.isTrusted else {
            awaitingPermission = true
            message = "请在系统设置 → 隐私与安全性 → 辅助功能中允许 LoLEmote。"
            GlobalInput.requestPermission()
            startPermissionTimer(); onStateChange?(); return
        }
        do {
            try input.start(chord: settings.trigger)
            enabled = true; awaitingPermission = false; settings.enabled = true; save()
            message = "已就绪。按住 \(settings.trigger.symbols)，移动选择，松开发送。"
            startPermissionTimer()
        } catch {
            enabled = false; awaitingPermission = false; settings.enabled = false; save()
            message = error.localizedDescription
        }
        onStateChange?()
    }
    private func startPermissionTimer() {
        permissionTimer?.invalidate()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.checkPermission() }
    }
    func checkPermission() {
        if awaitingPermission && GlobalInput.isTrusted { setEnabled(true) }
        else if enabled && !GlobalInput.isTrusted {
            setEnabled(false); message = "辅助功能权限已关闭，请重新授权后开启表情。"
        }
    }
    func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func preview(_ emote: Emote) {
        guard Assets.isReady(emote) else { message = "该表情尚未配置可用图片。"; return }
        cancelEffects(); previewEmote = emote; previewToken = UUID()
        playSound(emote)
        let cleanup = DispatchWorkItem { [weak self] in self?.previewEmote = nil }
        previewCleanup = cleanup
        DispatchQueue.main.asyncAfter(deadline: .now()+Assets.duration(emote), execute: cleanup)
    }
    private func playSound(_ emote: Emote) {
        do { try sound.play(emote, volume: settings.volume, muted: settings.muted) }
        catch { message = error.localizedDescription }
    }
    func cancelEffects() {
        input.cancelCurrent(); overlay.clear(); sound.stop()
        previewCleanup?.cancel(); previewCleanup = nil; previewEmote = nil
    }
    func shutdown() { permissionTimer?.invalidate(); input.stop(); cancelEffects() }
    private func handle(_ action: GestureMachine.Action) {
        guard enabled else { return }
        switch action {
        case .show(let anchor):
            input.setWheelCenter(overlay.showWheel(at: anchor, loadout: settings.loadout))
        case .hover(let slot, _): overlay.select(slot)
        case .hide, .dismiss: overlay.hideWheel()
        case .commit(let slot, let anchor):
            guard let emote = Assets.emote(settings.loadout[slot]), Assets.isReady(emote) else { return }
            previewCleanup?.cancel(); previewEmote = nil
            overlay.showEmote(emote, at: anchor, size: settings.size)
            playSound(emote)
        case .arm: break
        }
    }
}
