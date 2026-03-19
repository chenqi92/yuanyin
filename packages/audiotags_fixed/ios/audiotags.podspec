# audiotags_fixed - iOS 上禁用 Rust 库
# 原因: audiotags.xcframework 有链接问题
# 参见: https://github.com/erikas-taroza/audiotags/issues/21
# 解决方案: 使用 FFmpeg 作为后备方案处理音频元数据

# 不再下载 Rust 库
# version = "1.4.5"
# lib_url = "https://github.com/erikas-taroza/audiotags/releases/download/v#{version}/ios.zip"

Pod::Spec.new do |s|
  s.name             = 'audiotags'
  s.version          = '1.4.5'
  s.summary          = 'Audio metadata reading/writing (iOS stub)'
  s.description      = <<-DESC
Audio metadata plugin. On iOS, this is a stub - use FFmpeg fallback instead.
                       DESC
  s.homepage         = 'https://github.com/erikas-taroza/audiotags'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Erikas Taroza' => 'erikastaroza@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'
  # 移除 vendored_frameworks - 不使用 Rust 库
  # s.vendored_frameworks = 'Frameworks/**/*.xcframework'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
