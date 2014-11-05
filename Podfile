source 'https://github.com/CocoaPods/Specs.git'

workspace 'ETA-SDK'
xcodeproj 'Tests/ETA-SDK Tests.xcodeproj'
xcodeproj 'Examples/ETA-SDK iOS Example.xcodeproj'



target 'ETA-SDK iOS Example' do
  xcodeproj 'Examples/ETA-SDK iOS Example.xcodeproj'
  
  platform :ios, '6.0'
  
  pod 'ETA-SDK/WebCatalogView', :path => './'
end


target 'iOS Tests' do
  xcodeproj 'Tests/ETA-SDK Tests.xcodeproj'
  
  platform :ios, '6.0'
  pod 'ETA-SDK/API', :path => './'
end

