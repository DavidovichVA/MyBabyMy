platform :ios, '9.0'

target 'MyBabyMy' do

# Comment this line if you're not using Swift and don't want to use dynamic frameworks
use_frameworks!

pod 'Alamofire'
pod 'RealmSwift'
pod 'SwiftyJSON'
pod 'Fabric'
pod 'Crashlytics'
pod 'MBProgressHUD'
pod 'VK-ios-sdk'
pod 'FacebookCore'
pod 'FacebookLogin'
pod 'InstagramKit'
pod 'InstagramKit/UICKeyChainStore'
pod 'EDSunriseSet'

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0' # or '2.3'
    end
  end
end
