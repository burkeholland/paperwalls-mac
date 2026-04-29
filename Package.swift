// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Paperwalls",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Paperwalls", targets: ["Paperwalls"]),
        .library(name: "PaperwallsCore", targets: ["PaperwallsCore"])
    ],
    targets: [
        .target(
            name: "PaperwallsCore"
        ),
        .executableTarget(
            name: "Paperwalls",
            dependencies: ["PaperwallsCore"]
        ),
        .executableTarget(
            name: "PaperwallsChecks",
            dependencies: ["PaperwallsCore"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
