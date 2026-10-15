// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PulseBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "PulseBar", targets: ["PulseBar"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "PulseBar",
            dependencies: [],
            path: "PulseBar",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "PulseBar/Info.plist",
                ], .when(platforms: [.macOS])),
            ]
        ),
        .testTarget(
            name: "PulseBarTests",
            dependencies: ["PulseBar"],
            path: "PulseBarTests"
        )
    ]
)
