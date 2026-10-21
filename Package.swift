// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "hotKeyApp",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "hotKeyApp",
            path: "Sources/hotKeyApp",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
