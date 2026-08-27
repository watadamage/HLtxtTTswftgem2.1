// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HLtxtTT",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HLtxtTT", targets: ["HLtxtTT"])],
    targets: [.executableTarget(name: "HLtxtTT")]
)
