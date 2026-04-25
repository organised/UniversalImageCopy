// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "UniversalImageCopy",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "UniversalImageCopy", targets: ["UniversalImageCopy"])
    ],
    targets: [
        .executableTarget(
            name: "UniversalImageCopy",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
