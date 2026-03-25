import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YYNativeSurfaceViewFactory") {
      registrar.register(YYNativeSurfaceViewFactory(), withId: "yy/native_surface")
    }
    // PlatformView tab bar 空工厂（iOS 上由 FloatingTabBarController 管理）
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YYNativeTabBarViewFactory") {
      registrar.register(
        YYNativeTabBarViewFactory(messenger: registrar.messenger()),
        withId: "yy/native_tab_bar"
      )
    }
    // Tab bar bridge（保留空壳兼容旧代码引用）
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YYNativeTabBarBridgePlugin") {
      YYNativeTabBarBridgePlugin.register(with: registrar)
    }
    // iCloud 同步 MethodChannel
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YYICloudSyncPlugin") {
      let channel = FlutterMethodChannel(
        name: "com.kkape.primuse/icloud",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        let kvs = NSUbiquitousKeyValueStore.default
        switch call.method {
        case "setKVS":
          guard let args = call.arguments as? [String: String],
                let key = args["key"],
                let value = args["value"] else {
            result(false)
            return
          }
          kvs.set(value, forKey: key)
          result(true)
        case "getKVS":
          guard let args = call.arguments as? [String: String],
                let key = args["key"] else {
            result(nil)
            return
          }
          result(kvs.string(forKey: key))
        case "syncKVS":
          result(kvs.synchronize())
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }
    // Music Live Activity MethodChannel (灵动岛 + 锁屏)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MusicLiveActivityChannel") {
      MusicLiveActivityChannel.register(with: registrar)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

// MARK: - Native Surface PlatformView

final class YYNativeSurfaceViewFactory: NSObject, FlutterPlatformViewFactory {
  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    YYNativeSurfacePlatformView(frame: frame, args: args)
  }
}

private final class YYPassthroughView: UIView {
  override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
    false
  }
}

private final class YYNativeSurfacePlatformView: NSObject, FlutterPlatformView {
  private let containerView: YYPassthroughView
  private let effectView: UIVisualEffectView
  private var radius: CGFloat = 28

  init(frame: CGRect, args: Any?) {
    containerView = YYPassthroughView(frame: frame)
    effectView = UIVisualEffectView(frame: frame)
    super.init()
    setUpView()
    update(with: args)
  }

  func view() -> UIView {
    containerView
  }

  private func setUpView() {
    containerView.backgroundColor = .clear
    containerView.clipsToBounds = false

    effectView.translatesAutoresizingMaskIntoConstraints = false
    effectView.isUserInteractionEnabled = false
    containerView.addSubview(effectView)

    NSLayoutConstraint.activate([
      effectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      effectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      effectView.topAnchor.constraint(equalTo: containerView.topAnchor),
      effectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
    ])
  }

  private func update(with args: Any?) {
    if let params = args as? [String: Any],
       let radiusValue = params["radius"] as? Double {
      radius = CGFloat(radiusValue)
    }

    if #available(iOS 26.0, *) {
      let glassEffect = UIGlassEffect()
      glassEffect.isInteractive = false
      UIView.animate(withDuration: 0.22) {
        self.effectView.effect = glassEffect
      }
      return
    }

    effectView.effect = UIBlurEffect(style: .systemChromeMaterial)
    effectView.layer.cornerRadius = radius
    effectView.layer.cornerCurve = .continuous
    effectView.clipsToBounds = true
    effectView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
  }
}

// MARK: - PlatformView Tab Bar（空视图 — iOS 上由 FloatingTabBarController 管理）

final class YYNativeTabBarViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    YYNativeTabBarPlatformView(frame: frame)
  }
}

private final class YYNativeTabBarPlatformView: NSObject, FlutterPlatformView {
  private let hostView: UIView

  init(frame: CGRect) {
    hostView = UIView(frame: frame)
    hostView.backgroundColor = .clear
    super.init()
  }

  func view() -> UIView {
    hostView
  }
}

// MARK: - Tab Bar Bridge（空壳 — 兼容旧代码引用）

private final class YYNativeTabBarBridge: NSObject {
  static let shared = YYNativeTabBarBridge()
  func register(messenger: FlutterBinaryMessenger) {}
}

private final class YYNativeTabBarBridgePlugin: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    YYNativeTabBarBridge.shared.register(messenger: registrar.messenger())
  }
}
