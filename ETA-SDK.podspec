Pod::Spec.new do |s|
  s.name         = "ETA-SDK"
  s.version      = "2.2.2"
  s.summary      = "eTilbudsavis iOS SDK."
  s.description  = <<-DESC
                     An SDK that makes it easy to talk to the eTilbudsavis API.
                     Also allows you to easily embed catalogs and shopping lists in your own iOS app.
                    DESC

  s.homepage     = "http://engineering.etilbudsavis.dk/native-ios-eta-sdk/"
  s.license      = 'MIT'
  s.author       = { "Laurie Hufford" => "lh@etilbudsavis.dk" }

  s.platform     = :ios, '6.0'
  s.requires_arc = true

  s.source       = { 
    :git => "https://github.com/eTilbudsavis/native-ios-eta-sdk.git", 
    :tag => "v" + s.version.to_s
  }
  s.source_files = 'ETA-SDK/**/*.{h,m}'
  s.frameworks   = 'CoreLocation', 'Foundation', 'UIKit'

  s.dependency 'AFNetworking', '~> 2.2.0'
  s.dependency 'Mantle', '~> 1.4.1'
  s.dependency 'FMDB', '~> 2.2.0'
  s.dependency 'MAKVONotificationCenter', '~> 0.0.2'
  s.dependency 'CocoaLumberjack', '~> 1.8.1'

end
