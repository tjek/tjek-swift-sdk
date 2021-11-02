// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TjekSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12),
        .watchOS(.v6),
        .macOS(.v10_14),
        .tvOS(.v12)
    ],
    products: [
        .library(name: "TjekSDK", targets: ["TjekSDK"]),
        .library(name: "TjekAPI", targets: ["TjekAPI"]),
        .library(name: "TjekEventsTracker", targets: ["TjekEventsTracker"]),
        .library(name: "TjekPublicationReader", targets: ["TjekPublicationReader"]),
        
        .library(name: "ShopGunSDK", targets: ["ShopGunSDK"]),
    ],
    dependencies: [
        .package(name: "Incito", url: "https://github.com/shopgun/incito-ios.git", from: "1.0.3"),
        .package(name: "Future", url: "https://github.com/shopgun/swift-future.git", from: "0.5.0"),
        .package(name: "Verso", url: "https://github.com/shopgun/verso-ios.git", from: "1.0.5"),
        .package(name: "Kingfisher", url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(name: "Valet", url: "https://github.com/square/Valet.git", from: "4.1.1")
    ],
    targets: [
        // MARK: -
        .target(name: "TjekSDK",
                dependencies: [
                    .target(name: "TjekAPI"),
                    .target(name: "TjekEventsTracker"),
                    .target(name: "TjekPublicationReader", condition: .when(platforms: [.iOS]))
                ]),
        
        // MARK: -
        .target(name: "TjekAPI",
                dependencies: [
                    .product(name: "Future", package: "Future"),
                    .target(name: "TjekUtils")
                ]),
        .testTarget(name: "TjekAPITests",
                    dependencies: [.target(name: "TjekAPI")],
                    resources: [.process("Resources")]
                   ),
        
        // MARK: -
        .target(name: "TjekEventsTracker",
                dependencies: [
                    .target(name: "TjekAPI"),
                    .target(name: "TjekUtils"),
                    .product(name: "Valet", package: "Valet")
                ]),
        .testTarget(name: "TjekEventsTrackerTests",
                    dependencies: [.target(name: "TjekEventsTracker")],
                    resources: [.process("Resources")]
                   ),
        
        // MARK: -
        .target(name: "TjekPublicationReader",
                dependencies: [
                    .target(name: "TjekAPI"),
                    .target(name: "TjekEventsTracker")
//             .product(name: "Kingfisher", package: "Kingfisher")
                ]),
        
        // MARK: -
        .target(name: "TjekUtils",
                dependencies: []
               ),
        
        // MARK: - LEGACY
        .target(
            name: "ShopGunSDK",
            dependencies: [
                "Incito",
                "Future",
                "Verso",
                "Kingfisher",
                .target(name: "TjekEventsTracker")
            ],
            resources: [
                .process("IncitoPublication/Resources/IncitoViewer.graphql"),
                .process("PagedPublication/Resources/")
            ]
        ),
        .testTarget(
            name: "ShopGunSDKTests",
            dependencies: ["ShopGunSDK"]
        )
    ]
)
