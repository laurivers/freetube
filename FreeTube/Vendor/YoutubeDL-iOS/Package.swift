// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "YoutubeDL-iOS",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "YoutubeDL", targets: ["YoutubeDL"]),
    ],
    dependencies: [
        .package(path: "../Python-iOS"),
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.3.1"),
        .package(url: "https://github.com/kewlbear/FFmpeg-iOS-Lame", from: "0.0.6-b20230730-000000"),
    ],
    targets: [
        .target(
            name: "YoutubeDL",
            dependencies: [
                .product(name: "Python-iOS", package: "Python-iOS"),
                .product(name: "PythonKit", package: "PythonKit"),
                .product(name: "FFmpeg-iOS-Lame", package: "FFmpeg-iOS-Lame"),
            ]
        ),
    ]
)
