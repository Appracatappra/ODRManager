// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ODRManager",
    platforms: [.iOS(.v17), .tvOS(.v17)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ODRManager",
            targets: ["ODRManager"]),
    ],
    dependencies: [
            // Dependencies declare other packages that this package depends on.
            // .package(url: /* package url */, from: "1.0.0"),
            .package(url: "https://github.com/Appracatappra/LogManager", .upToNextMajor(from: "1.0.1")),
            .package(url: "https://github.com/Appracatappra/SwiftletUtilities", .upToNextMajor(from: "1.1.1")),
            .package(url: "https://github.com/Appracatappra/SoundManager", .upToNextMajor(from: "1.0.0")),
            .package(url: "https://github.com/Appracatappra/SwiftUIKit", .upToNextMajor(from: "1.0.3")),
            .package(url: "https://github.com/Appracatappra/SwiftUIGamepad", .upToNextMajor(from: "1.0.1")),
            .package(url: "https://github.com/Appracatappra/GraceLanguage", .upToNextMajor(from: "1.0.2")),
            .package(url: "https://github.com/Appracatappra/SimpleSerializer", .upToNextMajor(from: "1.0.4")),
        ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "ODRManager",
            dependencies: ["LogManager", "SwiftletUtilities", "SoundManager", "SwiftUIKit", "SwiftUIGamepad", "GraceLanguage", "SimpleSerializer"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ODRManagerTests",
            dependencies: ["ODRManager"]),
    ]
)
