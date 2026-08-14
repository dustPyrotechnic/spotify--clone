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
  pod 'WCDB.objc', :git => 'https://github.com/Tencent/wcdb.git', :tag => 'v2.1.16'
  
  pod 'UICKeyChainStore'
  pod 'ChameleonFramework'
end

# 2. 【核心修复】这段脚本专门用来救活 Masonry 等老库
# 它会强制把所有第三方库的最低支持版本改为 26.0
post_install do |installer|
  installer.generated_projects.each do |project|
    project.targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '26.0'

        # ⚠️ 关键：WCDB 相关 target 不覆盖 C++ 标准
        unless ['WCDB.objc', 'WCDBOptimizedSQLCipher'].include?(target.name)
          config.build_settings['CLANG_CXX_LIBRARY'] = 'libc++'
          config.build_settings['CLANG_CXX_LANGUAGE_STANDARD'] = 'gnu++17'
        end

        config.build_settings['LIBRARY_SEARCH_PATHS'] ||= ['$(inherited)']
        config.build_settings['LIBRARY_SEARCH_PATHS'] << '$(SDKROOT)/usr/lib'
      end
    end
  end

  # iOS 26 SDK 将 netinet6/in6.h 私有化；netinet/in.h 已覆盖 IPv6 定义
  Dir.glob("Pods/AFNetworking/**/*.{m,h,mm}").each do |f|
    next unless File.exist?(f)
    content = File.read(f)
    next unless content.include?("#import <netinet6/in6.h>")
    File.chmod(0644, f)
    File.write(f, content.gsub("#import <netinet6/in6.h>\n", ""))
  end
end
