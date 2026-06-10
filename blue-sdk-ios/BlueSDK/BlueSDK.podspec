Pod::Spec.new do |s|
  s.name             = 'BlueSDK'
  s.version          = '0.1.0'
  s.summary          = 'LX-PD02 智能药盒蓝牙通信 SDK（iOS 原生）'

  s.description      = <<-DESC
    BlueSDK 是专为 LX-PD02 智能药盒硬件设计的 iOS 原生蓝牙通信与控制 SDK。
    完整封装 LX-PD02 私有蓝牙 5.0 通信协议，向上提供简洁、类型安全的高层 API，
    使第三方开发者无需了解底层帧结构、CRC 校验、密钥认证等协议细节，
    即可快速构建具备完整用药提醒闭环能力的移动应用。
  DESC

  s.homepage         = 'https://github.com/allen/BlueSDK'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'allen' => 'allen.gao@item.com' }
  s.source           = { :git => 'https://github.com/allen/BlueSDK.git', :tag => s.version.to_s }

  # 最低支持 iOS 13.0，设备蓝牙须支持 Bluetooth 5.0+
  s.ios.deployment_target = '13.0'
  s.swift_version = '5.7'

  s.source_files = 'BlueSDK/Classes/**/*'

  # 零第三方依赖，仅使用系统 CoreBluetooth 框架
  s.frameworks = 'CoreBluetooth'
end
