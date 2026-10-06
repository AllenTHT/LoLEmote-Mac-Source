#!/usr/bin/env swift
import AppKit
import ApplicationServices

// Operates only on LoLEmote's own window. Restores the edited slot and settings.
let identifier = "local.allentu.LoLEmote"
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Verification/ui-check.json")
func attr(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var out: CFTypeRef?
    return AXUIElementCopyAttributeValue(element, name as CFString, &out) == .success ? out : nil
}
func string(_ element: AXUIElement, _ name: String) -> String { attr(element, name) as? String ?? "" }
func description(_ element: AXUIElement) -> String { string(element, "AXDescription") }
func children(_ element: AXUIElement) -> [AXUIElement] { attr(element, "AXChildren") as? [AXUIElement] ?? [] }
func flattened(_ root: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 16 else { return [] }
    return [root]+children(root).flatMap { flattened($0, depth: depth+1) }
}
func spin(_ delay: Double = 0.18) { RunLoop.main.run(until: Date().addingTimeInterval(delay)) }
func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw NSError(domain: "LoLEmote.UI", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
func press(_ element: AXUIElement) throws {
    try require(AXUIElementPerformAction(element, kAXPressAction as CFString) == .success, "Control cannot be pressed")
    spin()
}
var result: [String: Any] = ["date": ISO8601DateFormatter().string(from: Date())]
do {
    guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: identifier).first else {
        throw NSError(domain: "LoLEmote.UI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Open LoLEmote first"])
    }
    let root = AXUIElementCreateApplication(app.processIdentifier)
    func windows() -> [AXUIElement] { attr(root, "AXWindows") as? [AXUIElement] ?? [] }
    func elements() -> [AXUIElement] { windows().flatMap { flattened($0) } }
    func find(_ role: String, _ name: String) throws -> AXUIElement {
        guard let value = elements().first(where: { string($0,"AXRole") == role && (description($0) == name || string($0,"AXTitle") == name) }) else {
            throw NSError(domain: "LoLEmote.UI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Missing control: \(name)"])
        }
        return value
    }
    func texts() -> [String] { elements().filter { string($0,"AXRole") == "AXStaticText" }.compactMap { attr($0,"AXValue") as? String } }
    func value(_ element: AXUIElement) -> Double { (attr(element,"AXValue") as? NSNumber)?.doubleValue ?? -1 }
    func checkAdjustment(_ element: AXUIElement) throws {
        let original = value(element)
        try require(AXUIElementPerformAction(element, "AXIncrement" as CFString) == .success, "Cannot increment slider")
        spin()
        let increased = value(element) > original
        let restored = AXUIElementPerformAction(element, "AXDecrement" as CFString) == .success
        spin()
        try require(increased && restored && abs(value(element)-original) < 0.001, "Slider adjustment or restore failed")
    }
    try require(windows().count == 1, "Expected one control window")
    let size = try find("AXSlider", "表情大小"), volume = try find("AXSlider", "原声音量"), mute = try find("AXCheckBox", "静音")
    let originalSize = value(size), originalVolume = value(volume), originalMute = value(mute)
    let slotButton = elements().first { description($0).hasPrefix("左上位置，") }!
    let originalSlot = description(slotButton).components(separatedBy: "，").last!
    let editingSlot = texts().first { $0.hasPrefix("正在编辑 · ") }!.components(separatedBy: " · ").last!
    let search = try find("AXTextField", "搜索表情")
    let originalSearch = string(search, "AXValue")
    func searchFor(_ query: String) throws {
        try require(AXUIElementSetAttributeValue(search, kAXValueAttribute as CFString, query as CFString) == .success, "Cannot enter search")
        spin(0.25)
    }
    defer {
        if value(mute) != originalMute { try? press(mute) }
        try? searchFor(originalSearch)
    }
    if originalMute == 0 { try press(mute) }
    let manifest = try Data(contentsOf: app.bundleURL!.appendingPathComponent("Contents/Resources/emotes.json"))
    let entries = try JSONSerialization.jsonObject(with: manifest) as! [[String: Any]]
    let emotes = entries.map { $0["title"] as! String }
    for name in emotes {
        try searchFor(name)
        try press(find("AXButton", "试用\(name)"))
        try require(texts().contains(name), "Preview did not start: \(name)")
    }
    try searchFor("不存在的表情xyz")
    try require(texts().contains("没有找到表情，试试其他名称或分类。"), "No-result search did not update")
    for (alias, name) in [("机器人吃手", "机器人问号"), ("Xiaohu", "永恩手势舞"), ("反向Q", "LGD · 不不不不不！Q！")] {
        try searchFor(alias)
        _ = try find("AXButton", "试用\(name)")
    }
    try checkAdjustment(size); try checkAdjustment(volume)
    try searchFor("弱爆")
    try press(slotButton); try press(find("AXButton", "装备弱爆"))
    try require(elements().contains { description($0) == "左上位置，弱爆" }, "Equip did not update wheel")
    try press(find("AXButton", "清空此格"))
    try require(elements().contains { description($0) == "左上位置，空位" }, "Clear did not update wheel")
    if originalSlot != "空位" { try searchFor(originalSlot); try press(find("AXButton", "装备\(originalSlot)")) }
    if let originalEditing = elements().first(where: { description($0).hasPrefix("\(editingSlot)位置，") }) { try press(originalEditing) }
    if value(mute) != originalMute { try press(mute) }
    guard let close = attr(windows()[0], "AXCloseButton") else { fatalError("Missing close button") }
    try press(close as! AXUIElement)
    try require(!app.isTerminated && windows().isEmpty, "Closing window should retain app")
    _ = NSWorkspace.shared.open(app.bundleURL!); spin(0.5)
    try require(windows().count == 1, "Window did not reopen")
    let reopenedSize = try find("AXSlider", "表情大小"), reopenedVolume = try find("AXSlider", "原声音量")
    try require(abs(value(reopenedSize)-originalSize) < 0.001, "Size changed after reopening")
    try require(abs(value(reopenedVolume)-originalVolume) < 0.001, "Volume changed after reopening")
    result["status"] = "passed"
    result["checks"] = ["all \(emotes.count) preview buttons", "Chinese and English alias search", "no-result search", "equip and clear slot", "size and volume adjustment", "mute", "close retains app", "reopen restores window and settings"]
    // Optional: ask the app to enter its own permission flow. Never grants OS access.
    if CommandLine.arguments.contains("--request-permission") {
        if let toggle = elements().first(where: { string($0,"AXRole") == "AXCheckBox" && description($0).isEmpty }), value(toggle) == 0 {
            try press(toggle); spin(0.4)
        }
        result["permissionMessage"] = texts().first { $0.contains("辅助功能") || $0.hasPrefix("已就绪") } ?? "No permission status"
    }
} catch {
    result["status"] = "failed"; result["reason"] = error.localizedDescription
}
try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
try data.write(to: destination)
print(String(data: data, encoding: .utf8)!)
if result["status"] as? String != "passed" { exit(1) }
