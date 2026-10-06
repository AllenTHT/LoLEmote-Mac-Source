import AppKit
import EmoteCore
let app=NSApplication.shared
var count=0
func check(_ condition: @autoclosure ()->Bool,_ message:String) {
 guard condition() else {fputs("FAIL \(message)\n",stderr);exit(1)}
 count += 1
}
let suite="local.allentu.LoLEmote.lifecycle.\(UUID().uuidString)"
let defaults=UserDefaults(suiteName:suite)!
defer {defaults.removePersistentDomain(forName:suite)}
let model=AppModel(defaults:defaults)
model.setVolume(0.01)
let screen=NSScreen.main!.visibleFrame
let point=CGPoint(x:screen.midX,y:screen.midY)
func visiblePlayback() {
 GlobalInput.isTrusted=true;model.setEnabled(true)
 model.input.onAction?(.commit(.center,point))
 model.input.onAction?(.show(point))
 check(model.enabled && model.input.running,"input enabled")
 check(model.overlay.effect?.isVisible == true && model.overlay.wheel?.isVisible == true,"effects and wheel active before cleanup")
 check(model.sound.isPlaying,"audio active before cleanup")
}
func cleared(_ name:String) {
 check(model.overlay.effect == nil && model.overlay.wheel == nil,"\(name): panels cleared")
 check(!model.sound.isPlaying && model.previewEmote == nil,"\(name): audio and preview stopped")
}
GlobalInput.isTrusted=false
model.setEnabled(true)
check(model.awaitingPermission && !model.enabled && GlobalInput.permissionRequests == 1,"missing permission guide")
GlobalInput.isTrusted=true;model.checkPermission()
check(model.enabled && model.input.running && !model.awaitingPermission,"grant detected")
visiblePlayback();GlobalInput.isTrusted=false;model.checkPermission();cleared("permission loss")
check(!model.enabled && !model.input.running && !model.settings.enabled,"permission loss disables monitor and saves off state")
for name in [NSWorkspace.willSleepNotification,NSWorkspace.sessionDidResignActiveNotification,NSWorkspace.activeSpaceDidChangeNotification] {
 visiblePlayback()
 NSWorkspace.shared.notificationCenter.post(name:name,object:NSWorkspace.shared)
 RunLoop.main.run(until:Date().addingTimeInterval(0.03))
 cleared(name.rawValue)
}
visiblePlayback();model.setEnabled(false);cleared("disable")
check(!model.input.running,"disable stops input")
visiblePlayback();model.shutdown();cleared("quit")
check(!model.input.running,"quit stops input")
check(Settings.read(from:defaults).enabled,"quit preserves saved enabled setting")
model.setSize(128);model.setVolume(0.37);model.setMuted(true);model.setChord(.controlCommandShift);model.editingSlot = .northWest;model.assign(Assets.emotes[0])
let expected=model.settings
let restored=AppModel(defaults:UserDefaults(suiteName:suite)!)
restored.restoreState()
check(restored.settings == expected && restored.enabled,"all settings and enabled state restore")
restored.shutdown()
print("PASS \(count) lifecycle checks using production AppModel, overlays, audio, and settings.")
print("Permission changes use a controlled input boundary; sleep/session/space notifications are posted to this test process, without changing macOS permissions or sleeping the computer.")
