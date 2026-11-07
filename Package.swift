// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Mise",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Mise",
            path: "Sources/Mise",
            linkerSettings: [.linkedFramework("WebKit"), .linkedFramework("CoreImage")]
        ),
        .testTarget(name: "MiseTests", dependencies: ["Mise"], path: "Tests/MiseTests"),
    ]
)
