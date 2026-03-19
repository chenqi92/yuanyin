import Flutter
import UIKit

public class SwiftAudiotagsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audiotags", binaryMessenger: registrar.messenger())
    let instance = SwiftAudiotagsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)

    // Removed: let _ = dummy()
    // The bundling is now handled by the xcframework
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    result("iOS " + UIDevice.current.systemVersion)
  }

  // Removed: public static func dummy() -> Int64
  // { return dummy_method_to_enforce_bundling() }
}
