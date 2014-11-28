Pod::Spec.new do |s|
  s.name         = "ETA-SDK"
  s.version      = "2.3.0"
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


  # Everything related to making ETA API requests
  s.subspec 'API' do |ss|
    ss.source_files = 'ETA-SDK/ETA.{h,m}', 'ETA-SDK/API/**/*.{h,m}'
      
    ss.dependency 'AFNetworking', '~> 2.2.0'
    ss.dependency 'Mantle', '~> 1.4.1'
    ss.dependency 'FMDB', '~> 2.2.0'
    ss.dependency 'MAKVONotificationCenter', '~> 0.0.2'
    ss.dependency 'CocoaLumberjack', '~> 1.9.0'
    
    ss.frameworks   = 'CoreLocation', 'Foundation', 'UIKit'
  end
  

  # The native catalog reader experience
  s.subspec 'CatalogReader' do |ss|
      ss.source_files = 'ETA-SDK/CatalogReader/*.{h,m}'
      
      ss.dependency 'ETA-SDK/API'
      ss.dependency 'Verso', '~> 0.0.1'
  end
  
  
  # Shopping Lists and related model objects
  s.subspec 'ListManager' do |ss|
      ss.source_files = 'ETA-SDK/ListManager/*.{h,m}'
      
      ss.dependency 'ETA-SDK/API'
  end
  

  # The original, web-based, catalog reader experience. This is deprecated
  s.subspec 'WebCatalogView' do |ss|
    ss.source_files = 'ETA-SDK/WebCatalogView/*.{h,m}'
    
    ss.dependency 'ETA-SDK/API'
  end
  
end
