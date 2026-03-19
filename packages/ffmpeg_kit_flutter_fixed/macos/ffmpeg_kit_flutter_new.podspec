Pod::Spec.new do |s|
  s.name             = 'ffmpeg_kit_flutter_new'
  s.version          = '1.0.0'
  s.summary          = 'FFmpeg Kit for Flutter - Stub for macOS'
  s.description      = <<-DESC
    A Flutter plugin for running FFmpeg and FFprobe commands.
    Note: macOS uses a stub implementation. FFmpegKit official binaries were retired in January 2025.
    macOS uses system ffmpeg via Process instead.
  DESC
  s.homepage         = 'https://github.com/sk3llo/ffmpeg_kit_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Anton Karpenko' => 'kapraton@gmail.com' }

  s.platform            = :osx, '10.15'
  s.requires_arc        = true
  s.static_framework    = true

  s.source              = { :path => '.' }
  s.source_files        = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.dependency          'FlutterMacOS'

  # Note: macOS uses stub implementation - no FFmpegKit frameworks required
  # The Dart code handles transcoding via system ffmpeg Process

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
