// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LoLEmote", platforms: [.macOS(.v13)],
    products: [.executable(name: "LoLEmote", targets: ["LoLEmote"])],
    targets: [
        .target(name: "EmoteCore"),
        .executableTarget(name: "LoLEmote", dependencies: ["EmoteCore"]),
        .executableTarget(name: "EmoteCoreChecks", dependencies: ["EmoteCore"], path: "Tests/EmoteCoreChecks")
    ]
)
