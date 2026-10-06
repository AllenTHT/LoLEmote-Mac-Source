#!/usr/bin/env swift
import AppKit
import ApplicationServices

func attr(_ e: AXUIElement, _ n: String) -> CFTypeRef? {
    var value: CFTypeRef?; _ = AXUIElementCopyAttributeValue(e, n as CFString, &value); return value
}
func nodes(_ e: AXUIElement, depth: Int = 0) -> [AXUIElement] {
    guard depth < 20 else { return [] }
    return [e]+(attr(e,"AXChildren") as? [AXUIElement] ?? []).flatMap { nodes($0, depth: depth+1) }
}
func spin() { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }
func require(_ value: @autoclosure () -> Bool, _ message: String) throws {
    if !value() { throw NSError(domain: "CategoryCheck", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
}
let app = NSRunningApplication.runningApplications(withBundleIdentifier: "local.allentu.LoLEmote").first!
let originalFront = NSWorkspace.shared.frontmostApplication
app.activate(options: [])
spin()
defer { if let originalFront, originalFront.processIdentifier != app.processIdentifier { originalFront.activate(options: []) } }
let root = AXUIElementCreateApplication(app.processIdentifier)
func all() -> [AXUIElement] { (attr(root,"AXWindows") as? [AXUIElement] ?? []).flatMap { nodes($0) } }
func role(_ e: AXUIElement) -> String { attr(e,"AXRole") as? String ?? "" }
func label(_ e: AXUIElement) -> String { attr(e,"AXDescription") as? String ?? "" }
func texts() -> [String] { all().filter { role($0) == "AXStaticText" }.compactMap { attr($0,"AXValue") as? String } }
func categoryControl() -> AXUIElement? { all().first { role($0) == "AXPopUpButton" && label($0).hasPrefix("表情分类") } }
let popup = categoryControl()!
let search = all().first { role($0) == "AXTextField" && label($0) == "搜索表情" }!
let originalSearch = attr(search,"AXValue") as? String ?? ""
let originalCategory = attr(popup,"AXValue") as? String ?? "全部"
func query(_ text: String) throws {
    try require(AXUIElementSetAttributeValue(search,"AXValue" as CFString,text as CFString) == .success,"Set search")
    spin()
}
func select(_ title: String) throws {
    guard let popup = categoryControl() else { throw NSError(domain:"CategoryCheck",code:2,userInfo:[NSLocalizedDescriptionKey:"Category control missing"]) }
    if attr(popup,"AXValue") as? String == title { return }
    func menuItem() -> AXUIElement? {
        nodes(popup).first { role($0) == "AXMenuItem" && attr($0,"AXTitle") as? String == title }
    }
    if menuItem() == nil {
        try require(AXUIElementPerformAction(popup,"AXPress" as CFString) == .success,"Open category menu")
    }
    let deadline = Date().addingTimeInterval(1.5)
    while menuItem() == nil && Date() < deadline { spin() }
    guard let item = menuItem() else {
        throw NSError(domain:"CategoryCheck",code:2,userInfo:[NSLocalizedDescriptionKey:"Category menu item missing: \(title)"])
    }
    try require(AXUIElementPerformAction(item,"AXPress" as CFString) == .success,"Select category")
    spin()
}
var report: [String: Any] = ["date": ISO8601DateFormatter().string(from: Date())]
do {
    defer { try? select(originalCategory); try? query(originalSearch) }
    let entries = try JSONSerialization.jsonObject(with: Data(contentsOf: app.bundleURL!.appendingPathComponent("Contents/Resources/emotes.json"))) as! [[String: Any]]
    try query("")
    for (key,title) in [("classic","峡谷常青树"),("fun","整活型精品"),("esports","电竞趣味")] {
        try select(title)
        let expected = Set(entries.filter { $0["category"] as? String == key }.map { "试用"+($0["title"] as! String) })
        let buttons = Set(all().filter { role($0) == "AXButton" && label($0).hasPrefix("试用") }.map(label))
        try require(!buttons.isEmpty && buttons.isSubset(of: expected),"Wrong category cards: \(title)")
        try require(texts().contains("\(expected.count) 个"),"Wrong category count: \(title)")
    }
    try query("机器人")
    try require(texts().contains("没有找到表情，试试其他名称或分类。"),"Category and search must combine")
    try select("峡谷常青树")
    try require(all().contains { label($0) == "试用机器人问号" },"Switch category while search remains")
    report["status"] = "passed"
    report["checks"] = ["all three categories and counts", "category cards", "combined category and search", "filter switching", "restore original filter and search"]
} catch { report["status"] = "failed"; report["reason"] = error.localizedDescription }
let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted,.sortedKeys])
try data.write(to: URL(fileURLWithPath: "Verification/Expansion/category-check.json"))
print(String(data:data,encoding:.utf8)!)
if report["status"] as? String != "passed" { exit(1) }
