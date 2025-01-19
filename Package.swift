// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NoListSwipeActions",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "NoListSwipeActions",
            targets: ["NoListSwipeActions"]
        ),
    ],
    targets: [
        .target(
            name: "NoListSwipeActions"
        ),
        .testTarget(
            name: "NoListSwipeActionsTests",
            dependencies: ["NoListSwipeActions"]
        ),
    ]
)
