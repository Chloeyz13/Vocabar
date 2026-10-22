// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "TranslationReview",
    platforms: [.macOS("15.0")],
    dependencies: [
        .package(url: "https://github.com/soffes/HotKey", from: "0.2.1")
    ],
    targets: [
        .executableTarget(
            name: "TranslationReview",
            dependencies: [.product(name: "HotKey", package: "HotKey")],
            path: "Sources/TranslationReview"
        ),
        .testTarget(
            name: "TranslationReviewTests",
            dependencies: ["TranslationReview"],
            path: "Tests/TranslationReviewTests"
        )
    ]
)
