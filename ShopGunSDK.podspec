Pod::Spec.new do |s|

    s.name            = "ShopGunSDK"
    s.version         = "4.0.0"
    s.summary         = "ShopGun SDK for iOS."
    s.description     = <<-DESC
                         An SDK that makes it easy to talk to the eTilbudsavis API.
                         Also allows you to easily embed an interactive catalog view into your own iOS app.
                        DESC
    s.homepage         = "https://github.com/shopgun/shopgun-ios-sdk"
    s.license          = "MIT"
    s.author           = "ShopGun"
    s.social_media_url = "http://twitter.com/ShopGun"

    s.platform         = :ios, "9.3"
    s.swift_version    = "4.0"
    s.pod_target_xcconfig = { 'SWIFT_VERSION' => '4.0' }

    s.source       = { :git => "https://github.com/shopgun/shopgun-ios-sdk.git", :tag => "v#{s.version}" }
    
    s.subspec 'PagedPublicationView' do |ss|
        ss.source_files = "Sources/PagedPublication/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit"
        
        ss.dependency "ShopGunSDK/Shared"
        ss.dependency "ShopGunSDK/CoreAPI"
        ss.dependency "ShopGunSDK/EventsTracker"
        ss.dependency "Verso", "~> 1.0.1"
        ss.dependency "Kingfisher", "~> 4.6.3"
        
        ss.resources = ["Sources/PagedPublication/Resources/**/*"]
    end

    s.subspec 'CoreAPI' do |ss|
        ss.source_files = "Sources/CoreAPI/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit", "CoreLocation"

        ss.dependency "ShopGunSDK/Shared"
        ss.dependency "CryptoSwift", "~> 0.8.3"
    end

    s.subspec 'GraphAPI' do |ss|
        ss.source_files = "Sources/GraphAPI/**/*.swift"
        ss.frameworks   = "Foundation"
        
        ss.dependency "ShopGunSDK/Shared"
    end

    s.subspec 'EventsTracker' do |ss|
        ss.source_files = "Sources/EventsTracker/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit", "CoreLocation"
        
        ss.dependency "ShopGunSDK/Shared"
    end

    s.subspec 'Shared' do |ss|
        ss.source_files = "Sources/Shared/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit"

        ss.dependency "Valet", "~> 3.0.0"
    end
end
