// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Python-iOS",
    platforms: [.iOS(.v17)],
    products: [
        .library(
            name: "Python-iOS",
            targets: [
                "LinkPython",
                "libpython3",
                "libssl",
                "libcrypto",
                "libffi",
                "PythonSupport",
            ]
        ),
    ],
    targets: [
        .binaryTarget(name: "libpython3", path: "Artifacts/libpython3.xcframework"),
        .binaryTarget(name: "libssl", path: "Artifacts/libssl.xcframework"),
        .binaryTarget(name: "libcrypto", path: "Artifacts/libcrypto.xcframework"),
        .binaryTarget(name: "libffi", path: "Artifacts/libffi.xcframework"),
        .target(
            name: "LinkPython",
            dependencies: ["libpython3", "libssl", "libcrypto", "libffi"],
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("z"),
                .linkedLibrary("sqlite3"),
            ]
        ),
        .target(
            name: "PythonSupport",
            dependencies: ["LinkPython"],
            resources: [.copy("lib")]
        ),
    ]
)
