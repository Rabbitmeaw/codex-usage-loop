// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CodexPetUsageMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "CodexPetUsageMac", targets: ["CodexPetUsageMac"])
    ],
    targets: [
        .executableTarget(name: "CodexPetUsageMac", linkerSettings: [
            .linkedFramework("ScreenCaptureKit")
        ]),
        .testTarget(name: "CodexPetUsageMacTests", dependencies: ["CodexPetUsageMac"])
    ]
)
