#!/usr/bin/env swift
import AppKit
import ApplicationServices

func attr(_ e: AXUIElement, _ name: String) -> CFTypeRef? {
    var out: CFTypeRef?; _ = AXUIElementCopyAttributeValue(e,name as CFString,&out); return out
}
func nodes(_ e: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 20 else { return [] }
    return [e]+(attr(e,"AXChildren") as? [AXUIElement] ?? []).flatMap { nodes($0,depth:depth+1) }
}
func spin(_ seconds: Double = 0.15) { RunLoop.main.run(until:Date().addingTimeInterval(seconds)) }
func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw NSError(domain:"ExpansionDesktop",code:1,userInfo:[NSLocalizedDescriptionKey:message]) }
}
let app = NSRunningApplication.runningApplications(withBundleIdentifier:"local.allentu.LoLEmote").first!
let root = AXUIElementCreateApplication(app.processIdentifier)
func all() -> [AXUIElement] { (attr(root,"AXWindows") as? [AXUIElement] ?? []).flatMap { nodes($0) } }
func label(_ e: AXUIElement) -> String { attr(e,"AXDescription") as? String ?? "" }
func role(_ e: AXUIElement) -> String { attr(e,"AXRole") as? String ?? "" }
func find(_ roleName: String, _ description: String) throws -> AXUIElement {
    guard let e=all().first(where:{role($0)==roleName && label($0)==description}) else {
        throw NSError(domain:"ExpansionDesktop",code:2,userInfo:[NSLocalizedDescriptionKey:"Missing \(description)"])
    }
    return e
}
func press(_ e: AXUIElement) throws {
    try require(AXUIElementPerformAction(e,"AXPress" as CFString) == .success,"Cannot press control");spin()
}
func checked(_ e: AXUIElement) -> Bool { (attr(e,"AXValue") as? NSNumber)?.boolValue ?? false }
let preferences=UserDefaults(suiteName:"local.allentu.LoLEmote")!
let before=preferences.data(forKey:"settings.v1")!
let settings=try JSONSerialization.jsonObject(with:before) as! [String:Any]
let entries=try JSONSerialization.jsonObject(with:Data(contentsOf:app.bundleURL!.appendingPathComponent("Contents/Resources/emotes.json"))) as! [[String:Any]]
let originalCenter=((settings["loadout"] as! [String:Any])["slots"] as! [Any])[8] as? Int
let originalPointer=NSEvent.mouseLocation
let originalFront=NSWorkspace.shared.frontmostApplication
let originalSearch=attr(try find("AXTextField","搜索表情"),"AXValue") as? String ?? ""
func texts() -> [String] { all().filter { role($0)=="AXStaticText" }.compactMap { attr($0,"AXValue") as? String } }
let originalEditing=texts().first { $0.hasPrefix("正在编辑 · ") }!.components(separatedBy:" · ").last!
let category=all().first { role($0)=="AXPopUpButton" && label($0).hasPrefix("表情分类") }!
let originalCategory=attr(category,"AXValue") as? String ?? "全部"
func query(_ text:String) throws {
    try require(AXUIElementSetAttributeValue(try find("AXTextField","搜索表情"),"AXValue" as CFString,text as CFString) == .success,"Cannot search");spin()
}
func selectCategory(_ title:String) throws {
    let popup=all().first {role($0)=="AXPopUpButton" && label($0).hasPrefix("表情分类")}!
    if attr(popup,"AXValue") as? String == title {return}
    try press(popup)
    let deadline=Date().addingTimeInterval(1.5)
    while Date()<deadline {
        if let item=nodes(popup).first(where:{role($0)=="AXMenuItem" && attr($0,"AXTitle") as? String == title}) {try press(item);return}
        spin(0.05)
    }
    throw NSError(domain:"ExpansionDesktop",code:3,userInfo:[NSLocalizedDescriptionKey:"Category menu did not open"])
}
func overlays() -> [CGRect] {
    let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String:Any]] ?? []
    return windows.compactMap { window in
        guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value==app.processIdentifier,
              (window[kCGWindowLayer as String] as? NSNumber)?.intValue==25,
              let bounds=window[kCGWindowBounds as String] as? NSDictionary,
              let rect=CGRect(dictionaryRepresentation:bounds as CFDictionary),rect.width>80 else {return nil}
        return CGRect(x:rect.minX,y:NSScreen.screens[0].frame.maxY-rect.maxY,width:rect.width,height:rect.height)
    }
}
let source=CGEventSource(stateID:.privateState)!
let keySets:[String:[(CGKeyCode,CGEventFlags)]]=[
    "controlOptionShift":[(59,.maskControl),(58,.maskAlternate),(56,.maskShift)],
    "controlOptionCommand":[(59,.maskControl),(58,.maskAlternate),(55,.maskCommand)],
    "controlCommandShift":[(59,.maskControl),(55,.maskCommand),(56,.maskShift)]]
let keys=keySets[settings["chord"] as! String]!
var flags:CGEventFlags=[]
func key(_ code:CGKeyCode,_ down:Bool) {
    let event=CGEvent(keyboardEventSource:source,virtualKey:code,keyDown:down)!
    event.type = .flagsChanged;event.flags=flags;event.post(tap:.cghidEventTap);spin(0.025)
}
func move(_ point:CGPoint) {
    let event=CGEvent(mouseEventSource:source,mouseType:.mouseMoved,
                      mouseCursorPosition:CGPoint(x:point.x,y:NSScreen.screens[0].frame.maxY-point.y),mouseButton:.left)!
    event.flags=flags;event.post(tap:.cghidEventTap);spin(0.04)
}
func release() { for (code,flag) in keys { flags.remove(flag);key(code,false) } }
func fire(_ point:CGPoint) throws {
    move(point)
    for (code,flag) in keys { flags.insert(flag);key(code,true) }
    spin(0.23)
    try require(overlays().contains { abs($0.width-324)<1 },"Global wheel did not open")
    release();spin(0.1)
}
var report:[String:Any]=["date":ISO8601DateFormatter().string(from:Date())]
do {
    try require(checked(try find("AXCheckBox","")),"请重新授权并开启新版 LoLEmote 后运行检查。")
    try require(CGEventSource.flagsState(.combinedSessionState).intersection([.maskControl,.maskAlternate,.maskShift,.maskCommand]).isEmpty && NSEvent.pressedMouseButtons==0,"Release physical modifiers and mouse")
    try require(NSRunningApplication.runningApplications(withBundleIdentifier:"local.allentu.LoLPing").isEmpty,"Close Ping during this all-emote check to avoid shared-chord conflicts")
    app.activate(options:[]);spin()
    let mute=try find("AXCheckBox","静音")
    let originalMute=checked(mute)
    defer {
        release()
        try? selectCategory("全部")
        if let originalCenter,let item=entries.first(where:{$0["id"] as? Int==originalCenter}) {
            let title=item["title"] as! String;try? query(title);try? press(find("AXButton","装备"+title))
        } else {try? press(find("AXButton","清空此格"))}
        if let slot=all().first(where:{label($0).hasPrefix(originalEditing+"位置，")}) {try? press(slot)}
        if checked(mute) != originalMute {try? press(mute)}
        try? selectCategory(originalCategory);try? query(originalSearch)
        move(originalPointer)
        if let originalFront {originalFront.activate(options:[])}
    }
    if !originalMute {try press(mute)}
    try selectCategory("全部")
    try press(all().first(where:{label($0).hasPrefix("中央位置，")})!)
    let screen=NSScreen.main!.visibleFrame
    let center=CGPoint(x:screen.midX,y:screen.midY)
    let size=settings["size"] as! Double
    var results:[[String:Any]]=[]
    for item in entries {
        let title=item["title"] as! String
        try query(title);try press(find("AXButton","装备"+title))
        try require(all().contains {label($0)=="中央位置，"+title},"Equip did not update wheel: \(title)")
        let expectedSide:Double
        var duration=3.0
        if let path=item["animation"] as? String {
            let sequence=try JSONSerialization.jsonObject(with:Data(contentsOf:app.bundleURL!.appendingPathComponent("Contents/Resources/"+path))) as! [String:Any]
            expectedSide=size*max(1.5,sequence["canvasScale"] as! Double);duration=sequence["duration"] as! Double
        } else {expectedSide=size*1.5}
        let front=NSWorkspace.shared.frontmostApplication?.processIdentifier
        try fire(center)
        try require(overlays().count==1 && abs(overlays()[0].width-expectedSide)<1,"Expected one emote effect: \(title)")
        try require(NSWorkspace.shared.frontmostApplication?.processIdentifier==front,"Effect stole focus")
        if item["animation"] != nil {
            for corner in [CGPoint(x:screen.minX+2,y:screen.minY+2),CGPoint(x:screen.maxX-2,y:screen.maxY-2)] {
                try fire(corner)
                try require(overlays().count==1 && screen.insetBy(dx:-1,dy:-1).contains(overlays()[0]),"Dynamic effect clipped at corner")
            }
            let deadline=Date().addingTimeInterval(duration+0.3)
            while !overlays().isEmpty && Date()<deadline {spin(0.05)}
            try require(overlays().isEmpty,"Dynamic effect did not clean up")
        }
        results.append(["id":item["id"]!,"title":title,"expectedSide":expectedSide,"duration":duration])
    }
    report["status"]="passed";report["emotes"]=results
    report["checks"]=["all 30 emotes equipped and triggered through actual App global input", "one replacement effect", "focus retained", "animated effect dimensions", "dynamic corner clamping", "original animation duration and cleanup", "restore user loadout and settings"]
} catch {report["status"]="failed";report["reason"]=error.localizedDescription}
spin(0.3)
_ = CFPreferencesAppSynchronize("local.allentu.LoLEmote" as CFString)
if let restored=CFPreferencesCopyAppValue("settings.v1" as CFString,"local.allentu.LoLEmote" as CFString) as? Data,
   let restoredSettings=try? JSONSerialization.jsonObject(with:restored) as? NSDictionary {
    let unchanged=restoredSettings.isEqual(to:settings)
    report["settingsRestored"]=unchanged
    if !unchanged { report["status"]="failed";report["reason"]="User settings were not fully restored" }
} else {report["status"]="failed";report["reason"]="Cannot verify restored settings"}
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
try data.write(to:URL(fileURLWithPath:"Verification/Expansion/desktop-catalog-check.json"))
print(String(data:data,encoding:.utf8)!)
if report["status"] as? String != "passed" {exit(1)}
