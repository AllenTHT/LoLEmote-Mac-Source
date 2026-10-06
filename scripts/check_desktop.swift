#!/usr/bin/env swift
import AppKit
import ApplicationServices
let application = NSApplication.shared
application.setActivationPolicy(.regular)
application.finishLaunching()
func spin(_ seconds: Double) {
 let deadline=Date().addingTimeInterval(seconds)
 repeat {
  RunLoop.current.run(until:Date().addingTimeInterval(0.002))
  while let event=application.nextEvent(matching:.any,until:.distantPast,inMode:.default,dequeue:true) { application.sendEvent(event) }
 } while Date() < deadline
}
func require(_ condition:@autoclosure ()->Bool,_ message:String) throws {if !condition(){throw NSError(domain:"DesktopCheck",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
func attr(_ e:AXUIElement,_ name:String)->CFTypeRef? {var v:CFTypeRef?;_ = AXUIElementCopyAttributeValue(e,name as CFString,&v);return v}
func nodes(_ e:AXUIElement)->[AXUIElement] {[e]+(attr(e,"AXChildren") as? [AXUIElement] ?? []).flatMap(nodes)}
func controls(_ app:NSRunningApplication)->[AXUIElement] {let root=AXUIElementCreateApplication(app.processIdentifier);return (attr(root,"AXWindows") as? [AXUIElement] ?? []).flatMap(nodes)}
func checkbox(_ app:NSRunningApplication,_ name:String)->AXUIElement? {controls(app).first {attr($0,"AXRole") as? String == "AXCheckBox" && (attr($0,"AXDescription") as? String ?? "") == name}}
func checked(_ element:AXUIElement)->Bool {(attr(element,"AXValue") as? NSNumber)?.boolValue ?? false}
func setChecked(_ element:AXUIElement,_ on:Bool) {if checked(element) != on {_ = AXUIElementPerformAction(element,kAXPressAction as CFString);spin(0.15)}}
let emote=NSRunningApplication.runningApplications(withBundleIdentifier:"local.allentu.LoLEmote").first!
if NSRunningApplication.runningApplications(withBundleIdentifier:"local.allentu.LoLPing").isEmpty {
 let url=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).deletingLastPathComponent().appendingPathComponent("英雄联盟Ping信号Mac版/dist/LoLPing.app")
 _ = NSWorkspace.shared.open(url);spin(0.8)
}
let ping=NSRunningApplication.runningApplications(withBundleIdentifier:"local.allentu.LoLPing").first!
let originalPointer=NSEvent.mouseLocation
let source=CGEventSource(stateID:.privateState)!
var flags:CGEventFlags=[]
let allKeys:[(CGKeyCode,CGEventFlags)]=[(59,.maskControl),(58,.maskAlternate),(56,.maskShift),(55,.maskCommand)]
func key(_ code:CGKeyCode,_ down:Bool,_ type:CGEventType = .flagsChanged) {
 let e=CGEvent(keyboardEventSource:source,virtualKey:code,keyDown:down)!;e.type=type;e.flags=flags;e.post(tap:.cghidEventTap);spin(0.02)
}
func move(_ point:CGPoint) {let e=CGEvent(mouseEventSource:source,mouseType:.mouseMoved,mouseCursorPosition:CGPoint(x:point.x,y:NSScreen.screens[0].frame.maxY-point.y),mouseButton:.left)!;e.flags=flags;e.post(tap:.cghidEventTap);spin(0.03)}
func mouseButton(_ point:CGPoint,_ down:Bool) {let e=CGEvent(mouseEventSource:source,mouseType:down ? .leftMouseDown:.leftMouseUp,mouseCursorPosition:CGPoint(x:point.x,y:NSScreen.screens[0].frame.maxY-point.y),mouseButton:.left)!;e.flags=flags;e.post(tap:.cghidEventTap)}
func chord(ping:Bool=false) {for (code,flag) in [allKeys[0],allKeys[1],allKeys[ping ? 3:2]] {flags.insert(flag);key(code,true)};spin(0.23)}
func release() {for (code,flag) in allKeys {if flags.contains(flag){flags.remove(flag);key(code,false)}};spin(0.05)}
func overlays(_ pid:pid_t)->[CGRect] {
 let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
 return windows.compactMap { w in
  guard (w[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
   (w[kCGWindowLayer as String] as? NSNumber)?.intValue == 25,
   let data=w[kCGWindowBounds as String] as? NSDictionary,
   let rect=CGRect(dictionaryRepresentation:data as CFDictionary),rect.width > 80,rect.height > 80 else {return nil}
  return CGRect(x:rect.minX,y:NSScreen.screens[0].frame.maxY-rect.maxY,width:rect.width,height:rect.height)
 }
}
class Receiver:NSObject {var clicks=0;@objc func hit(){clicks += 1}}
let receiver=Receiver()
var window:NSWindow?
let mute=checkbox(emote,"静音")!
let originalMute=checked(mute)
let output=URL(fileURLWithPath:FileManager.default.currentDirectoryPath).appendingPathComponent("Verification/desktop-check.json")
var report:[String:Any]=["date":ISO8601DateFormatter().string(from:Date())]
defer {
 flags=[];allKeys.forEach {key($0.0,false)};key(0,false,.keyUp)
 mouseButton(NSEvent.mouseLocation,false)
 if let toggle=checkbox(emote,""){setChecked(toggle,true)}
 setChecked(mute,originalMute)
 if let toggle=checkbox(ping,"启用 Ping"){setChecked(toggle,false)}
 _ = ping.terminate()
 window?.close();move(originalPointer);emote.activate(options:[])
}
do {
 try require(CGEventSource.flagsState(.combinedSessionState).intersection([.maskControl,.maskAlternate,.maskShift,.maskCommand]).isEmpty,"Release physical modifier keys first")
 setChecked(mute,true)
 if let toggle=checkbox(ping,"启用 Ping"){setChecked(toggle,true)}
 spin(0.5)
 guard let finder=NSRunningApplication.runningApplications(withBundleIdentifier:"com.apple.finder").first else {throw NSError(domain:"DesktopCheck",code:2)}
 let finderAX=AXUIElementCreateApplication(finder.processIdentifier)
 _ = AXUIElementSetAttributeValue(finderAX,kAXFrontmostAttribute as CFString,kCFBooleanTrue)
 spin(0.5)
 let frontBefore=NSWorkspace.shared.frontmostApplication
 report["foregroundBeforeTest"]=frontBefore?.bundleIdentifier ?? frontBefore?.localizedName ?? "none"
 try require(frontBefore?.processIdentifier == finder.processIdentifier,"Finder activation failed before any wheel event")
 let screen=NSScreen.main!.visibleFrame
 let points=[CGPoint(x:screen.midX,y:screen.midY),CGPoint(x:screen.minX+2,y:screen.minY+2),CGPoint(x:screen.minX+2,y:screen.maxY-2),CGPoint(x:screen.maxX-2,y:screen.minY+2),CGPoint(x:screen.maxX-2,y:screen.maxY-2)]
 var edgeResults:[[String:Any]]=[]
 for point in points {
  move(point);chord()
  let wheels=overlays(emote.processIdentifier).filter {abs($0.width-324)<1}
  try require(wheels.count == 1,"Emote wheel missing above Finder")
  try require(screen.insetBy(dx:-1,dy:-1).contains(wheels[0]),"Wheel clipped at screen edge")
  try require(overlays(ping.processIdentifier).isEmpty,"Emote chord triggered Ping")
  release()
  let effects=overlays(emote.processIdentifier)
  try require(effects.count == 1 && effects[0].width < 200,"Expected one replacement emote effect")
  try require(screen.insetBy(dx:-1,dy:-1).contains(effects[0]),"Emote clipped at screen edge")
  let frontAfter=NSWorkspace.shared.frontmostApplication
  report["foregroundAfterGesture"]=frontAfter?.bundleIdentifier ?? frontAfter?.localizedName ?? "none"
  report["lastAnchor"]=[point.x,point.y]
  try require(frontAfter?.processIdentifier == finder.processIdentifier,"Foreground changed during wheel gesture")
  edgeResults.append(["anchor":[point.x,point.y],"wheel":[wheels[0].minX,wheels[0].minY,wheels[0].width,wheels[0].height],"effect":[effects[0].minX,effects[0].minY,effects[0].width,effects[0].height]])
 }
 report["edges"]=edgeResults
 spin(3.1)
 try require(overlays(emote.processIdentifier).isEmpty,"Emote did not disappear after three seconds")
 let center=CGPoint(x:screen.midX,y:screen.midY)
 move(center);chord(ping:true)
 try require(overlays(ping.processIdentifier).contains {abs($0.width-300)<1},"Ping chord did not open Ping")
 try require(overlays(emote.processIdentifier).isEmpty,"Ping chord triggered emote")
 release()
 let pingDeadline=Date().addingTimeInterval(1.5)
 while !overlays(ping.processIdentifier).contains(where:{abs($0.width-300)>1}) && Date() < pingDeadline {spin(0.025)}
 let pingEffects=overlays(ping.processIdentifier)
 report["pingAfterRelease"]=pingEffects.map {[$0.minX,$0.minY,$0.width,$0.height]}
 try require(pingEffects.contains {abs($0.width-300)>1},"Ping release did not show a non-wheel effect")
 try require(overlays(emote.processIdentifier).isEmpty,"Ping release emitted emote")
 spin(2.2)
 window=NSWindow(contentRect:CGRect(x:center.x-240,y:center.y-140,width:480,height:280),styleMask:[.titled,.closable],backing:.buffered,defer:false)
 window!.isReleasedWhenClosed=false;window!.title="LoLEmote 点击穿透检查"
 let button=NSButton(title:"检查点击穿透",target:receiver,action:#selector(Receiver.hit))
 button.frame=CGRect(x:160,y:120,width:160,height:40);button.bezelStyle = .rounded;window!.contentView!.addSubview(button)
 window!.makeKeyAndOrderFront(nil);application.activate(ignoringOtherApps:true);spin(0.3)
 let target=window!.convertPoint(toScreen:button.convert(CGPoint(x:80,y:20),to:nil))
 move(target);chord();release()
 try require(overlays(emote.processIdentifier).count == 1,"Missing effect above click target")
 mouseButton(target,true);mouseButton(target,false);spin(0.2)
 try require(receiver.clicks == 1,"Emote blocked mouse click")
 // The same live overlay must disappear immediately when disabled.
 if let toggle=checkbox(emote,""){setChecked(toggle,false)}
 try require(overlays(emote.processIdentifier).isEmpty,"Disable left desktop windows visible")
 move(target);chord();release();try require(overlays(emote.processIdentifier).isEmpty,"Disabled app still listens")
 if let toggle=checkbox(emote,""){setChecked(toggle,true)}
 key(0,true,.keyDown);chord();try require(overlays(emote.processIdentifier).isEmpty,"Held regular key allowed wheel")
 release();key(0,false,.keyUp)
 chord();key(0,true,.keyDown);release();key(0,false,.keyUp)
 try require(overlays(emote.processIdentifier).isEmpty,"Extra ordinary key did not cancel")
 let dragPoint=window!.convertPoint(toScreen:CGPoint(x:30,y:50))
 move(dragPoint);mouseButton(dragPoint,true);spin(0.02);chord()
 try require(overlays(emote.processIdentifier).isEmpty,"Existing mouse press allowed wheel")
 release();mouseButton(dragPoint,false);spin(0.03)
 report["status"]="passed";report["edges"]=edgeResults
 report["checks"]=["Finder foreground retained","wheel and effect fit all four screen corners","one effect replaces previous effect","three-second disappearance","both apps enabled with independent default chords","real mouse click through effect","disable stops panels and listening","existing normal key blocked","extra normal key cancels","existing mouse press blocked"]
} catch {report["status"]="failed";report["reason"]=error.localizedDescription}
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:output);print(String(data:data,encoding:.utf8)!)
