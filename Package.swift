// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "TjekSDK",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .watchOS(.v6),
        .macOS(.v10_15),
        .tvOS(.v12)
    ],
    products: [
        .library(name: "TjekSDK", targets: ["TjekSDK"]),
        .library(name: "TjekAPI", targets: ["TjekAPI"]),
        .library(name: "TjekPublicationViewer", targets: ["TjekPublicationViewer"])
    ],
    dependencies: [
        .package(name: "Incito", url: "https://github.com/tjek/incito-ios.git", from: "1.0.6"),
        .package(name: "Future", url: "https://github.com/tjek/swift-future.git", from: "0.5.0"),
        .package(name: "Verso", url: "https://github.com/tjek/verso-ios.git", from: "1.0.6"),
        .package(name: "Kingfisher", url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0"),
        .package(name: "Valet", url: "https://github.com/square/Valet.git", from: "4.1.1")
    ],
    targets: [
        // MARK: -
        .target(name: "TjekSDK",
                dependencies: [
                    .target(name: "TjekAPI"),
                    .target(name: "TjekEventsTracker"),
                    .target(name: "TjekPublicationViewer", condition: .when(platforms: [.iOS]))
                ]),
        
        // MARK: -
        .target(name: "TjekAPI",
                dependencies: [
                    .target(name: "TjekUtils"),
                    .product(name: "Future", package: "Future")
                ]),
        .testTarget(name: "TjekAPITests",
                    dependencies: [.target(name: "TjekAPI")],
                    resources: [.process("Resources")]
                   ),
        
        // MARK: -
        .target(name: "TjekPublicationViewer",
                dependencies: [
                    .target(name: "TjekAPI"),
                    .target(name: "TjekEventsTracker"),
                    .product(name: "Incito", package: "Incito", condition: .when(platforms: [.iOS])),
                    .product(name: "Future", package: "Future", condition: .when(platforms: [.iOS])),
                    .product(name: "Verso", package: "Verso", condition: .when(platforms: [.iOS])),
                    .product(name: "Kingfisher", package: "Kingfisher", condition: .when(platforms: [.iOS]))
                ],
                resources: [
                    .process("PagedPublication/Resources")
                ]
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
        .target(name: "TjekUtils",
                dependencies: []
               )
    ]
)
