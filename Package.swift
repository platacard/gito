// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Gito",
    platforms: [.macOS(.v14)],
    products: [
        .library(
            name: "Gito",
            targets: ["Gito"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/platacard/cronista.git", from: "1.0.3"),
        .package(url: "https://github.com/platacard/corredor.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "Gito",
            dependencies: [
                .product(name: "Cronista", package: "cronista"),
                .product(name: "Corredor", package: "corredor")
            ]
        ),
        .testTarget(
            name: "GitoTests",
            dependencies: ["Gito"]
        )
    ]
)
