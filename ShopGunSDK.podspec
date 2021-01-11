Pod::Spec.new do |s|

    s.name            = "ShopGunSDK"
    s.version         = "4.3.0"
    s.summary         = "ShopGun SDK for iOS."
    s.description     = <<-DESC
                         An SDK that makes it easy to talk to the ShopGun API.
                         Also allows you to easily embed an interactive catalog view into your own iOS app.
                        DESC
    s.homepage         = "https://github.com/shopgun/shopgun-ios-sdk"
    s.license          = "MIT"
    s.author           = "ShopGun"

    s.platform         = :ios, "10.0"
    s.swift_version    = "5.0.1"
    s.pod_target_xcconfig = { 'SWIFT_VERSION' => '5.0' }

    s.source       = { :git => "https://github.com/shopgun/shopgun-ios-sdk.git", :tag => "v#{s.version}" }
    
    s.subspec 'PagedPublicationView' do |ss|
        ss.source_files = "Sources/ShopGunSDK/PagedPublication/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit"
        
        ss.dependency "ShopGunSDK/Shared"
        ss.dependency "ShopGunSDK/CoreAPI"
        ss.dependency "ShopGunSDK/EventsTracker"
        ss.dependency "Verso", "~> 1.0.4"
        ss.dependency "Kingfisher", "~> 6.0.1"
        
        ss.resources = ["Sources/ShopGunSDK/PagedPublication/Resources/**/*"]
    end

    s.subspec 'IncitoPublication' do |ss|
        ss.source_files = "Sources/ShopGunSDK/IncitoPublication/**/*.swift"
        ss.resources = ["Sources/ShopGunSDK/IncitoPublication/**/*.graphql"]
        ss.frameworks   = "Foundation", "UIKit"
        
        ss.dependency "ShopGunSDK/Shared"
        ss.dependency "ShopGunSDK/GraphAPI"
        ss.dependency "ShopGunSDK/EventsTracker"
        ss.dependency "Incito", "~> 1.0"
        ss.dependency "ShopGun-Future", "~> 0.4"
    end
    
    s.subspec 'CoreAPI' do |ss|
        ss.source_files = "Sources/ShopGunSDK/CoreAPI/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit", "CoreLocation"

        ss.dependency "ShopGunSDK/Shared"
    end

    s.subspec 'GraphAPI' do |ss|
        ss.source_files = "Sources/ShopGunSDK/GraphAPI/**/*.swift"
        ss.frameworks   = "Foundation"
        
        ss.dependency "ShopGunSDK/Shared"
    end

    s.subspec 'EventsTracker' do |ss|
        ss.source_files = "Sources/ShopGunSDK/EventsTracker/**/*.swift"
        ss.frameworks   = "Foundation", "UIKit", "CoreLocation"
        
        ss.dependency "ShopGunSDK/Shared"
        ss.dependency "ShopGunSDK/CoreAPI"        
    end

    s.subspec 'Shared' do |ss|
        ss.source_files = "Sources/ShopGunSDK/Shared/**/*.{swift,h,m}"
        ss.frameworks   = "Foundation", "UIKit"

        ss.dependency "Valet", "~> 4.1.1"
    end
end
