// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SATin",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "SATin", targets: ["SATin"])
    ],
    targets: [
        .executableTarget(
            name: "SATin",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "SATinTests",
            dependencies: ["SATin"]
        )
    ]
)
