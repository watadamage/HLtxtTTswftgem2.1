// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HLtxtTTswft2.2",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "HLtxtTTswft2.2", targets: ["HLtxtTT"])],
    targets: [.executableTarget(name: "HLtxtTT")]
)
