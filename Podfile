# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

target 'SVGAParsePlayer_Demo' do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  pod 'SVProgressHUD'
  pod 'Protobuf', '= 3.22.1'
  pod 'SVGAPlayer'

  post_install do |installer|
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      end
    end
  end

end
