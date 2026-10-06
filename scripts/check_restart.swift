#!/usr/bin/env swift
import AppKit
import ApplicationServices
func spin(_ t:Double){RunLoop.main.run(until:Date().addingTimeInterval(t))}
func attr(_ e:AXUIElement,_ n:String)->CFTypeRef? {var v:CFTypeRef?;_ = AXUIElementCopyAttributeValue(e,n as CFString,&v);return v}
func nodes(_ e:AXUIElement)->[AXUIElement] {[e]+(attr(e,"AXChildren") as? [AXUIElement] ?? []).flatMap(nodes)}
func require(_ condition:@autoclosure ()->Bool,_ text:String)throws {if !condition(){throw NSError(domain:"RestartCheck",code:1,userInfo:[NSLocalizedDescriptionKey:text])}}
let id="local.allentu.LoLEmote"
let defaults=UserDefaults(suiteName:id)!
let original=defaults.data(forKey:"settings.v1")!
let settings=try JSONSerialization.jsonObject(with:original) as! [String:Any]
let current=NSRunningApplication.runningApplications(withBundleIdentifier:id).first!
let url=current.bundleURL!
let oldPID=current.processIdentifier
try require(current.terminate(),"App did not accept quit")
let quitDeadline=Date().addingTimeInterval(5)
while !current.isTerminated && Date() < quitDeadline {spin(0.05)}
try require(current.isTerminated,"App did not terminate")
var reopened:NSRunningApplication?
NSWorkspace.shared.openApplication(at:url,configuration:NSWorkspace.OpenConfiguration()){app,error in reopened=app}
let deadline=Date().addingTimeInterval(5)
while reopened == nil && Date() < deadline {spin(0.05)}
try require(reopened != nil,"App did not reopen")
spin(0.7)
let app=reopened!
try require(app.processIdentifier != oldPID,"Process was not restarted")
let root=AXUIElementCreateApplication(app.processIdentifier)
let all=(attr(root,"AXWindows") as? [AXUIElement] ?? []).flatMap(nodes)
func named(_ role:String,_ description:String)->AXUIElement? {all.first{attr($0,"AXRole") as? String == role && (attr($0,"AXDescription") as? String ?? "") == description}}
let size=(attr(named("AXSlider","表情大小")!,"AXValue") as! NSNumber).doubleValue
let volume=(attr(named("AXSlider","原声音量")!,"AXValue") as! NSNumber).doubleValue
let muted=(attr(named("AXCheckBox","静音")!,"AXValue") as! NSNumber).boolValue
let enabled=(attr(named("AXCheckBox","")!,"AXValue") as! NSNumber).boolValue
try require(size == (settings["size"] as! Double) && abs(volume-(settings["volume"] as! Double)) < 0.001,"Size/volume did not restore")
try require(muted == (settings["muted"] as! Bool) && enabled == (settings["enabled"] as! Bool),"Mute/enabled did not restore")
let status=all.filter{attr($0,"AXRole") as? String == "AXStaticText"}.compactMap{attr($0,"AXValue") as? String}.first{$0.hasPrefix("已就绪")}
try require(!enabled || status != nil,"Enabled preference did not restart live listener")
let labels=all.filter{attr($0,"AXRole") as? String == "AXButton"}.compactMap{attr($0,"AXDescription") as? String}
let names=["上","右上","右","右下","下","左下","左","左上","中央"]
let manifest=try Data(contentsOf:url.appendingPathComponent("Contents/Resources/emotes.json"))
let entries=try JSONSerialization.jsonObject(with:manifest) as! [[String:Any]]
let titles=Dictionary(uniqueKeysWithValues:entries.map{($0["id"] as! Int,$0["title"] as! String)})
let slots=(settings["loadout"] as! [String:Any])["slots"] as! [Any]
for (i,slot) in slots.enumerated(){let title=(slot as? Int).flatMap{titles[$0]} ?? "空位";try require(labels.contains("\(names[i])位置，\(title)"),"Slot \(i) did not restore")}
let chords=["controlOptionShift":"⌃ ⌥ ⇧  Control + Option + Shift","controlOptionCommand":"⌃ ⌥ ⌘  Control + Option + Command","controlCommandShift":"⌃ ⌘ ⇧  Control + Command + Shift"]
let chord=attr(named("AXPopUpButton","呼出快捷键")!,"AXValue") as? String
try require(chord == chords[settings["chord"] as! String],"Chord did not restore")
let ping=UserDefaults(suiteName:"local.allentu.LoLPing")!
try require(!ping.bool(forKey:"enabled") && ping.string(forKey:"triggerChord") == "controlOptionCommand" && ping.double(forKey:"volume") == 0.55 && ping.double(forKey:"effectScale") == 1,"Ping settings did not return to baseline")
try require(NSRunningApplication.runningApplications(withBundleIdentifier:"local.allentu.LoLPing").isEmpty,"Ping test instance still running")
let report:[String:Any]=["status":"passed","date":ISO8601DateFormatter().string(from:Date()),"checks":["new process after quit","nine slots restored","chord restored","size volume mute restored","enabled live listener restored","Ping baseline restored and test instance closed"]]
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:CommandLine.arguments.dropFirst().first ?? "Verification/restart-check.json"));print(String(data:data,encoding:.utf8)!)
