// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "MDViewer",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "MDViewer",
            targets: ["MDViewer"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MDViewer",
            path: "Sources/MDViewer"
        )
    ]
)
