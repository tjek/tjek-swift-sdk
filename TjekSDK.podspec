Pod::Spec.new do |s|

    s.name            = "TjekSDK"
    s.version         = "5.0.0"
    s.summary         = "Tjek SDK for iOS."
    s.description     = <<-DESC
                         An SDK that makes it easy to talk to the Tjek API.
                         Also allows you to easily embed an interactive publication view into your own iOS app.
                        DESC
    s.homepage         = "https://github.com/shopgun/shopgun-ios-sdk"
    s.license          = "MIT"
    s.author           = "Tjek"

    s.platform         = :ios, "12.0"
    s.swift_version    = "5.0.1"
    s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }

    s.source       = { :git => "https://github.com/shopgun/shopgun-ios-sdk.git", :tag => "v#{s.version}" }
    
    s.subspec 'API' do |ss|
        ss.source_files = "Sources/TjekAPI/**/*.swift",
                          "Sources/TjekUtils/**/*.swift",
                          "Sources/TjekEventsTracker/**/*.swift",
                          "Sources/TjekSDK/**/*.swift"
        ss.frameworks   = "Foundation", "CoreLocation"

        ss.dependency "ShopGun-Future", "~> 0.5"
        ss.dependency "Valet", "~> 4.1.1"
    end
    
    # API + Publication viewer UI
    s.subspec 'PublicationViewer' do |ss|
        ss.dependency "TjekSDK/API"
        ss.source_files = "Sources/TjekPublicationViewer/**/*.swift"
        ss.resources = ["Sources/TjekPublicationViewer/PagedPublication/Resources/**/*"]
        
        ss.frameworks   = "Foundation", "UIKit"
        
        ss.dependency "Incito", "~> 1.0"
        ss.dependency "ShopGun-Future", "~> 0.5"
        ss.dependency "Verso", "~> 1.0"
        ss.dependency "Kingfisher", "~> 7.0"
    end
end
