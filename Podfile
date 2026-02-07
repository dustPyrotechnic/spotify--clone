# 1. 直接指定为 iOS 26.0 (匹配你的新系统环境)
#platform :ios, '26.0'

target 'Spotify - clone' do
  use_frameworks!

  pod 'LookinServer'
  pod 'AFNetworking'
  pod 'Masonry'
  pod 'SDWebImage'
  pod 'YYModel'
  
  # 数据库
  pod 'WCDB.objc', :git => 'https://github.com/Tencent/wcdb.git', :tag => 'v2.1.15'
  
  pod 'UICKeyChainStore'
  pod 'ChameleonFramework'
end

# 2. 【核心修复】这段脚本专门用来救活 Masonry 等老库
# 它会强制把所有第三方库的最低支持版本改为 26.0
post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        # 强制覆盖 Deployment Target 为 26.0，解决 libarclite 报错
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'
        
        # Xcode 26 C++ 标准库修复
        config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
        config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'gnu++17'
        
        # 添加 C++ 库搜索路径
        config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
        config.build_settings['LIBRARY_SEARCH_PATHS'] << '$(SDKROOT)/usr/lib'
        
        # 修复 WCDB C++ 头文件找不到问题
        config.build_settings['HEADER_SEARCH_PATHS'] ||= ['$(inherited)']
        config.build_settings['HEADER_SEARCH_PATHS'] << '$(SDKROOT)/usr/include/c++/v1'
      end
    end
  end
end