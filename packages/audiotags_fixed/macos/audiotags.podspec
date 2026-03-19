# audiotags_fixed - macOS 上禁用 Rust 库
# 原因: libaudiotags.a 与 macOS 26.1 SDK 不兼容
# 解决方案: 使用 FFmpeg 作为后备方案处理音频元数据

# 不再下载 Rust 库
# version = "1.4.5"
# lib_url = "https://github.com/erikas-taroza/audiotags/releases/download/v#{version}/macos.zip"

Pod::Spec.new do |s|
  s.name             = 'audiotags'
  s.version          = '1.4.5'
  s.summary          = 'Audio metadata reading/writing (macOS stub)'
  s.description      = <<-DESC
Audio metadata plugin. On macOS, this is a stub - use FFmpeg fallback instead.
                       DESC
  s.homepage         = 'https://github.com/erikas-taroza/audiotags'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Erikas Taroza' => 'erikastaroza@gmail.com' }

  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  # 移除 vendored_libraries - 不使用 Rust 库
  # s.vendored_libraries = 'Libs/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '10.11'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
end
