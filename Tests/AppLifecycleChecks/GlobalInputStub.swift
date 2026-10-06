import Foundation
import EmoteCore
// Controlled permission/input boundary; AppModel, overlays, audio and settings
// are compiled from the production sources without copying or changing them.
final class GlobalInput {
 static var isTrusted = true
 static var permissionRequests = 0
 static func requestPermission() { permissionRequests += 1 }
 var onAction: ((GestureMachine.Action)->Void)?
 var onUnavailable: (()->Void)?
 private(set) var running = false
 func start(chord: TriggerChord) throws { running = Self.isTrusted }
 func stop() { running = false }
 func cancelCurrent() { onAction?(.hide) }
 func setWheelCenter(_ point: CGPoint) {}
}
