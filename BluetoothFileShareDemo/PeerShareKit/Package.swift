// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PeerShareKit",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(name: "PeerShareKit", targets: ["PeerShareKit"])
    ],
    targets: [
        .target(name: "PeerShareKit", path: "Sources/PeerShareKit")
    ]
)
