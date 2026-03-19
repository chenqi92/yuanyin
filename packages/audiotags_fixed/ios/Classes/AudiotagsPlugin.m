#import "AudiotagsPlugin.h"
// Removed: #import "../Runner/bridge_generated.h"
// iOS build fix: bridge_generated.h references old v1.x symbols that are not in the v2.x library
// See: https://github.com/erikas-taroza/audiotags/issues/21
#if __has_include(<audiotags/audiotags-Swift.h>)
#import <audiotags/audiotags-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "audiotags-Swift.h"
#endif

@implementation AudiotagsPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  // Removed: dummy_method_to_enforce_bundling();
  // The bundling is handled by the xcframework, not the old bridge
  [SwiftAudiotagsPlugin registerWithRegistrar:registrar];
}
@end
