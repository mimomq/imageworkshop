// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ImageWorkshop",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ImageWorkshop", targets: ["ImageWorkshop"])
    ],
    targets: [
        .executableTarget(
            name: "ImageWorkshop",
            path: "Sources/ImageWorkshop"
        ),
        .testTarget(
            name: "ImageWorkshopTests",
            dependencies: ["ImageWorkshop"],
            path: "Tests/ImageWorkshopTests"
        )
    ],
    swiftLanguageModes: [.v5]
)
