// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TmdSwift",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "TmdSwift",
            targets: ["TmdSwift"]
        ),
        .library(
            name: "TmdMIDI",
            targets: ["TmdMIDI"]
        ),
        .library(
            name: "TmdMusicXML",
            targets: ["TmdMusicXML"]
        ),
        .library(
            name: "TmdLilyPond",
            targets: ["TmdLilyPond"]
        ),
        .library(
            name: "TmdUtils",
            targets: ["TmdUtils"]
        ),
        .library(
            name: "TmdAudio",
            targets: ["TmdAudio"]
        ),
        .executable(
            name: "tmd",
            targets: ["TmdCLI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "TmdUtils"
        ),
        .target(
            name: "TmdSwift",
            dependencies: ["TmdUtils"]
        ),
        .target(
            name: "TmdMIDI",
            dependencies: ["TmdSwift"]
        ),
        .target(
            name: "TmdMusicXML",
            dependencies: ["TmdSwift"]
        ),
        .target(
            name: "TmdLilyPond",
            dependencies: ["TmdSwift"]
        ),
        .target(
            name: "TmdAudio",
            dependencies: ["TmdSwift", "TmdMIDI"]
        ),
        .executableTarget(
            name: "TmdCLI",
            dependencies: [
                "TmdSwift",
                "TmdMIDI",
                "TmdMusicXML",
                "TmdLilyPond",
                "TmdAudio",
                "TmdUtils",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "TmdSwiftTests",
            dependencies: ["TmdSwift", "TmdMIDI", "TmdMusicXML", "TmdLilyPond", "TmdAudio", "TmdUtils"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
