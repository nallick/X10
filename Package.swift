// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "X10",
    platforms: [.macOS(.v10_12)],
    products: [
        .library(
            name: "X10",
            targets: ["X10"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "X10",
            dependencies: [],
            path: "Sources"
        ),
    ]
)
