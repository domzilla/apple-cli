// swift-tools-version: 6.0

import Foundation
import PackageDescription

/// Embedded in both binaries so `--version` and the publish script read the same version.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .appendingPathComponent("src/AppleCLIKit/Resources/Info.plist").path

let embedInfoPlist: [LinkerSetting] = [
    .unsafeFlags([
        "-Xlinker",
        "-sectcreate",
        "-Xlinker",
        "__TEXT",
        "-Xlinker",
        "__info_plist",
        "-Xlinker",
        infoPlist,
    ]),
]

let package = Package(
    name: "apple-cli",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "AppleCLIKit",
            path: "src/AppleCLIKit",
            exclude: ["Resources"]
        ),
        .executableTarget(
            name: "asc",
            dependencies: ["AppleCLIKit"],
            path: "src/asc",
            linkerSettings: embedInfoPlist
        ),
        .executableTarget(
            name: "asa",
            dependencies: ["AppleCLIKit"],
            path: "src/asa",
            linkerSettings: embedInfoPlist
        ),
        .testTarget(
            name: "AppleCLIKitTests",
            dependencies: ["AppleCLIKit"],
            path: "src/AppleCLIKitTests"
        ),
        .testTarget(
            name: "ascTests",
            dependencies: ["asc", "AppleCLIKit"],
            path: "src/ascTests"
        ),
        .testTarget(
            name: "asaTests",
            dependencies: ["asa", "AppleCLIKit"],
            path: "src/asaTests"
        ),
    ]
)
