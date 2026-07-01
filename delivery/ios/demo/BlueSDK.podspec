Pod::Spec.new do |s|
  s.name             = 'BlueSDK'
  s.version          = '1.0.0'
  s.summary          = 'LX-PD02 Smart Pill Box BLE SDK'
  s.description      = 'BlueSDK encapsulates the LX-PD02 BLE communication protocol.'
  s.homepage         = 'https://github.com/example/BlueSDK'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Blue' => 'sdk@blue.com' }
  s.source           = { :path => '.' }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.7'
  s.vendored_frameworks = 'BlueSDK.xcframework'
end
