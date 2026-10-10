// swift-tools-version:5.10
import PackageDescription

// Pure-Foundation logic shared by the app: text tools, base forms, spaced
// repetition, streak, Gutenberg catalog, dictionary client and the library.
// Mirrors `core/` in lingleaf-android, with the same tests.
let package = Package(
    name: "LingleafCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "LingleafCore", targets: ["LingleafCore"])],
    targets: [
        .target(name: "LingleafCore"),
        .testTarget(name: "LingleafCoreTests", dependencies: ["LingleafCore"]),
    ]
)
