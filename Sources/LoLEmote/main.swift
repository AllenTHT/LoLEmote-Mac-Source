import AppKit
import AVFoundation
import EmoteCore

let arguments = CommandLine.arguments
do {
    if arguments.contains("--check-assets") {
        let strict = arguments.contains("--strict")
        let failures = Assets.errors + (strict ? Assets.warnings : [])
        for emote in Assets.emotes { print("\(emote.id) \(emote.title): \(Assets.status(emote))") }
        if !strict { Assets.warnings.forEach { print("WARNING: \($0)") } }
        guard failures.isEmpty else { throw NSError(domain: "Assets", code: 1, userInfo: [NSLocalizedDescriptionKey: failures.joined(separator: "\n")]) }
        print("PASS catalog configuration; \(Assets.availableEmotes.count)/\(Assets.emotes.count) images ready. Mode: \(strict ? "strict" : "optional media")."); exit(0)
    }
    if let index = arguments.firstIndex(of: "--visual-check"), arguments.count > index+1 {
        try Diagnostics.visuals(to: URL(fileURLWithPath: arguments[index+1])); exit(0)
    }
    if arguments.contains("--self-check") { try Diagnostics.behavior(); exit(0) }
    if arguments.contains("--audio-check") { try Diagnostics.audio(); exit(0) }
} catch { fputs("Check failed: \(error.localizedDescription)\n", stderr); exit(1) }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
