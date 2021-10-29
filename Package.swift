// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "TjekSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v12),
        .watchOS(.v6)
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
        // TjekSDK
        .target(name: "TjekSDK", dependencies: [
            .target(name: "TjekAPI"),
            .target(name: "TjekEventsTracker"),
            .target(name: "TjekPublicationReader", condition: .when(platforms: [.iOS]))
        ]),
        .testTarget(name: "TjekSDKTests", dependencies: [
            .target(name: "TjekSDK")
        ]),
        
        // TjekAPI
        .target(name: "TjekAPI", dependencies: [
            .product(name: "Future", package: "Future"),
            .target(name: "TjekUtils")
        ]),
        .testTarget(name: "TjekAPITests", dependencies: [
            .target(name: "TjekAPI")
        ]),
        
        // TjekEventsTracker
        .target(name: "TjekEventsTracker", dependencies: [
        ]),
        .testTarget(name: "TjekEventsTrackerTests", dependencies: [
            .target(name: "TjekEventsTracker")
        ]),
        
        // TjekPublicationReader
        .target(name: "TjekPublicationReader", dependencies: [
            .target(name: "TjekAPI"),
            .target(name: "TjekEventsTracker")
//            .product(name: "Kingfisher", package: "Kingfisher")
         ]),
        .testTarget(name: "TjekPublicationReaderTests", dependencies: [
            .target(name: "TjekPublicationReader")
        ]),
        
        // TjekUtils
        .target(name: "TjekUtils", dependencies: [
        ]),
        .testTarget(name: "TjekUtilsTests", dependencies: [
            .target(name: "TjekUtils")
        ]),
        
        // LEGACY
        .target(
            name: "ShopGunSDK",
            dependencies: [
                "Incito",
                "Future",
                "Verso",
                "Kingfisher",
                "Valet"
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
