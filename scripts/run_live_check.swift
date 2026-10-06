#!/usr/bin/env swift
import AppKit
import ApplicationServices
let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let output = rootURL.appendingPathComponent("Verification/Live/\(UUID().uuidString)")
let bundle = rootURL.appendingPathComponent("dist/LoLEmote.app")
let bundleID = "local.allentu.LoLEmote"
func spin(_ time: Double) { RunLoop.main.run(until: Date().addingTimeInterval(time)) }
func attr(_ e: AXUIElement, _ key: String) -> CFTypeRef? { var v:CFTypeRef?; return AXUIElementCopyAttributeValue(e,key as CFString,&v) == .success ? v : nil }
func descendants(_ e: AXUIElement) -> [AXUIElement] { [e]+(attr(e,"AXChildren") as? [AXUIElement] ?? []).flatMap(descendants) }
func toggle(_ app: NSRunningApplication) -> AXUIElement? {
 let root = AXUIElementCreateApplication(app.processIdentifier)
 return (attr(root,"AXWindows") as? [AXUIElement] ?? []).flatMap(descendants).first { attr($0,"AXRole") as? String == "AXCheckBox" && (attr($0,"AXDescription") as? String ?? "").isEmpty }
}
var restoreEnabled = false
if let current = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
 if let control = toggle(current) {
  restoreEnabled = (attr(control,"AXValue") as? NSNumber)?.boolValue ?? false
  if restoreEnabled { guard AXUIElementPerformAction(control,kAXPressAction as CFString) == .success else { fatalError("Cannot pause normal listener") }; spin(0.2) }
 }
 guard current.terminate() else { fatalError("Cannot close current App") }
 let deadline=Date().addingTimeInterval(5)
 while !current.isTerminated && Date() < deadline { spin(0.1) }
 guard current.isTerminated else { fatalError("App still running") }
}
let configuration=NSWorkspace.OpenConfiguration()
configuration.arguments=["--live-check",output.path]
var launched:NSRunningApplication?
var launchError:Error?
NSWorkspace.shared.openApplication(at:bundle,configuration:configuration) {app,error in launched=app;launchError=error}
let report=output.appendingPathComponent("live-check.json")
let deadline=Date().addingTimeInterval(30)
while !FileManager.default.fileExists(atPath:report.path) && launchError == nil && Date() < deadline {spin(0.1)}
if restoreEnabled,let app=launched,let control=toggle(app),(attr(control,"AXValue") as? NSNumber)?.boolValue == false {
 _ = AXUIElementPerformAction(control,kAXPressAction as CFString);spin(0.2)
}
if let error=launchError { print(error);exit(1) }
guard let data=try? Data(contentsOf:report) else {print("No completed report at",report.path);exit(1)}
try data.write(to:rootURL.appendingPathComponent("Verification/Live/live-check.json"),options:.atomic)
print(String(data:data,encoding:.utf8)!)
let decoded=try JSONSerialization.jsonObject(with:data) as! [String:Any]
if decoded["status"] as? String != "passed" {exit(1)}
