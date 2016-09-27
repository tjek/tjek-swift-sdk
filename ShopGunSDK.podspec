Pod::Spec.new do |s|
  s.name                = 'ShopGunSDK'
  s.version             = '4.0.0'
  s.author              = { "Laurie Hufford" => "lh@shopgun.com" }
  s.homepage            = 'https://shopgun.com/developers'
  s.license             = 'MIT'


  s.summary      = "ShopGun SDK"
  s.description  = <<-DESC
                    A Swift-based SDK for interacting with ShopGun services, including:
                    * Graph API interaction
                    * Event Tracking
                    DESC


  s.source       = {
                    :git => 'https://github.com/shopgun/shopgun-ios-sdk.git',
                    :branch => 'feature/experimental'
#                     :tag => "v" + s.version.to_s
                    }


  s.requires_arc = true
  s.platform     = :ios, '8.0'


  s.module_name = 'ShopGunSDK'

  s.subspec 'Core' do |ss|
    ss.source_files = 'Source/Core/**/*.swift'
    ss.pod_target_xcconfig = { 'ENABLE_TESTABILITY' => 'YES' }
    ss.frameworks   = 'Foundation', 'UIKit'
    ss.dependency 'Valet', '~> 2.2.2'
  end

  s.subspec 'Events' do |ss|
    ss.source_files = 'Source/Events/**/*.swift'
    ss.pod_target_xcconfig = { 'ENABLE_TESTABILITY' => 'YES' }
    ss.frameworks   = 'Foundation', 'UIKit', 'CoreLocation'

    ss.dependency 'ShopGunSDK/Core'
  end

  s.subspec 'Graph' do |ss|
    ss.source_files = 'Source/Graph/**/*.swift'
    ss.pod_target_xcconfig = { 'ENABLE_TESTABILITY' => 'YES' }
    ss.frameworks   = 'Foundation'

    ss.dependency 'ShopGunSDK/Core'
  end

  s.subspec 'PagedPublication' do |ss|
    ss.source_files = 'Source/PagedPublication/**/*.swift'
    ss.frameworks   = 'Foundation', 'UIKit'

    ss.dependency 'ShopGunSDK/Events'
    ss.dependency 'ShopGunSDK/Core'
    ss.dependency 'Verso', '~> 1.0.0'
    ss.dependency 'Kingfisher', '~> 3.1.0'

  end

end
