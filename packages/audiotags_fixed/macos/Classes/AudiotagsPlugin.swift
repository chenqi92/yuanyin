import Cocoa
import FlutterMacOS

public class AudiotagsPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "audiotags", binaryMessenger: registrar.messenger)
    let instance = AudiotagsPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    // 移除对 Rust 库的调用 - macOS 上禁用 audiotags
    // let _ = dummy()
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // 移除 dummy() 函数 - macOS 上不使用 Rust 库
  // public static func dummy() -> Int64
  // { return dummy_method_to_enforce_bundling() }
}
