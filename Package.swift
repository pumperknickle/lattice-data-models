// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "lattice-data-models",
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "lattice-data-models",
            targets: ["lattice-data-models"]),
    ],
    dependencies: [
        .package(url: "https://github.com/pumperknickle/AwesomeTrie.git", from: "0.1.1"),
        .package(url: "https://github.com/pumperknickle/AwesomeDictionary.git", from: "0.1.0"),
        .package(url: "https://github.com/pumperknickle/Bedrock.git", from: "0.2.1"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "lattice-data-models",
            dependencies: ["Bedrock", "AwesomeTrie", "AwesomeDictionary"]),
        .testTarget(
            name: "lattice-data-modelsTests",
            dependencies: ["lattice-data-models"]),
    ]
)
