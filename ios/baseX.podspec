Pod::Spec.new do |s|
  s.name             = 'baseX'
  s.version          = '1.0.0'
  s.summary          = 'Flutter app foundation native helpers.'
  s.description      = 'Native display-zoom lookup used by baseX.'
  s.homepage         = 'https://github.com/YeeJiaWei/baseX'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'YeeJiaWei' => 'yeejiawei0811@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
