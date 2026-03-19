Pod::Spec.new do |s|
  s.name             = 'ffmpeg_kit_flutter_new'
  s.version          = '1.0.0'
  s.summary          = 'FFmpeg Kit for Flutter'
  s.description      = 'A Flutter plugin for running FFmpeg and FFprobe commands.'
  s.homepage         = 'https://github.com/sk3llo/ffmpeg_kit_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Anton Karpenko' => 'kapraton@gmail.com' }

  s.platform            = :ios, '12.0'
  s.requires_arc        = true
  s.static_framework    = true

  s.source              = { :path => '.' }
  s.source_files        = 'Classes/**/*'
  s.public_header_files = 'Classes/**/*.h'

  s.dependency          'Flutter'
  
  # Run setup script to download FFmpegKit frameworks if not present
  # Using luthviar/ffmpeg-kit-ios-full self-hosted binaries (FFmpegKit official retired Jan 2025)
  s.prepare_command = <<-CMD
    if [ ! -d "./Frameworks" ] || [ -z "$(ls -A ./Frameworks 2>/dev/null)" ]; then
      chmod +x ../scripts/setup_ios.sh
      ../scripts/setup_ios.sh
    fi
  CMD
  
  # Vendored xcframeworks from luthviar's self-hosted release
  s.ios.vendored_frameworks = 'Frameworks/ffmpegkit.xcframework',
                              'Frameworks/libavcodec.xcframework',
                              'Frameworks/libavdevice.xcframework',
                              'Frameworks/libavfilter.xcframework',
                              'Frameworks/libavformat.xcframework',
                              'Frameworks/libavutil.xcframework',
                              'Frameworks/libswresample.xcframework',
                              'Frameworks/libswscale.xcframework'
  
  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }

  s.ios.frameworks = 'AudioToolbox', 'CoreMedia', 'AVFoundation', 'VideoToolbox'
  s.libraries = 'z', 'bz2', 'c++', 'iconv'
end
