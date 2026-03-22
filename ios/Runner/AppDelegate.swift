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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "YYNativeTabBarViewFactory") {
      registrar.register(
        YYNativeTabBarViewFactory(messenger: registrar.messenger()),
        withId: "yy/native_tab_bar"
      )
    }
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
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

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

private final class YYNativeTabBarBridge: NSObject {
  static let shared = YYNativeTabBarBridge()

  private weak var hostView: YYLiquidTabBarHostView?
  private var channel: FlutterMethodChannel?

  func register(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: "yy/native_tab_bar_service",
      binaryMessenger: messenger
    )
    channel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }

      switch call.method {
      case "setSelectedIndex":
        if let index = call.arguments as? Int {
          self.hostView?.updateSelectedIndex(index)
        }
        result(nil)
      case "setTabBarVisible":
        if let visible = call.arguments as? Bool {
          self.hostView?.setVisible(visible)
        }
        result(nil)
      case "getTabBarHeight":
        result(Double(self.hostView?.tabBarHeight ?? 49))
      case "getSafeAreaBottom":
        result(Double(self.hostView?.safeAreaBottom ?? 34))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func bind(hostView: YYLiquidTabBarHostView) {
    self.hostView = hostView
    notifyMetricsChanged()
  }

  func unbind(hostView: YYLiquidTabBarHostView) {
    guard self.hostView === hostView else { return }
    self.hostView = nil
  }

  func notifyTabSelected(_ index: Int) {
    channel?.invokeMethod("onTabSelected", arguments: index)
  }

  func notifyMetricsChanged() {
    guard let hostView = hostView else { return }
    channel?.invokeMethod("onMetricsChanged", arguments: [
      "tabBarHeight": hostView.tabBarHeight,
      "safeAreaBottom": hostView.safeAreaBottom,
    ])
  }
}

private final class YYNativeTabBarBridgePlugin: NSObject {
  static func register(with registrar: FlutterPluginRegistrar) {
    YYNativeTabBarBridge.shared.register(messenger: registrar.messenger())
  }
}

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
    YYNativeTabBarPlatformView(
      frame: frame,
      viewIdentifier: viewId,
      arguments: args,
      messenger: messenger
    )
  }
}

private struct YYNativeTabItem {
  let id: Int
  let icon: String
  let selectedIcon: String
  let label: String
}

private final class YYNativeTabBarPlatformView: NSObject, FlutterPlatformView {
  private let hostView: YYLiquidTabBarHostView
  private var channel: FlutterMethodChannel?

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    messenger: FlutterBinaryMessenger
  ) {
    var items: [YYNativeTabItem] = []
    var selectedIndex = 0
    var isDark = false

    if let params = args as? [String: Any] {
      selectedIndex = params["selectedIndex"] as? Int ?? 0
      isDark = params["isDark"] as? Bool ?? false
      if let rawItems = params["items"] as? [[String: Any]] {
        items = rawItems.enumerated().map { index, item in
          YYNativeTabItem(
            id: index,
            icon: item["icon"] as? String ?? "circle",
            selectedIcon: item["selectedIcon"] as? String ?? "circle.fill",
            label: item["label"] as? String ?? ""
          )
        }
      }
    }

    hostView = YYLiquidTabBarHostView(
      items: items,
      selectedIndex: selectedIndex,
      isDark: isDark
    )

    super.init()

    let channelName = "yy/native_tab_bar_\(viewId)"
    channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "updateSelectedIndex":
        if let index = call.arguments as? Int {
          self?.hostView.updateSelectedIndex(index)
        }
        result(nil)
      case "updateTheme":
        if let isDark = call.arguments as? Bool {
          self?.hostView.updateTheme(isDark)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    hostView.onTabTap = { [weak self] index in
      self?.channel?.invokeMethod("onTabTap", arguments: index)
    }
  }

  func view() -> UIView {
    hostView
  }
}

private final class YYLiquidTabBarHostView: UIView, UITabBarDelegate {
  private var itemsConfig: [YYNativeTabItem]
  private var isDark: Bool
  private let tabBar = UITabBar()
  var onTabTap: ((Int) -> Void)?

  var tabBarHeight: CGFloat {
    let measured = tabBar.bounds.height
    if measured > 0 {
      return measured
    }
    return tabBar.sizeThatFits(bounds.size).height
  }

  var safeAreaBottom: CGFloat {
    safeAreaInsets.bottom
  }

  init(items: [YYNativeTabItem], selectedIndex: Int, isDark: Bool) {
    itemsConfig = items
    self.isDark = isDark
    super.init(frame: .zero)
    setUpView()
    rebuildTabs()
    updateSelectedIndex(selectedIndex)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    YYNativeTabBarBridge.shared.unbind(hostView: self)
  }

  private func setUpView() {
    backgroundColor = .clear
    tabBar.translatesAutoresizingMaskIntoConstraints = false
    tabBar.backgroundColor = .clear
    tabBar.delegate = self
    tabBar.tintColor = UIColor(red: 246 / 255, green: 141 / 255, blue: 46 / 255, alpha: 1)
    addSubview(tabBar)

    NSLayoutConstraint.activate([
      tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
      tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
      tabBar.topAnchor.constraint(equalTo: topAnchor),
      tabBar.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])

    configureAppearance()
    YYNativeTabBarBridge.shared.bind(hostView: self)
  }

  private func configureAppearance() {
    if #available(iOS 26.0, *) {
      // iOS 26: Liquid Glass — 设置透明背景，让系统自动应用玻璃质感
      let appearance = UITabBarAppearance()
      appearance.configureWithTransparentBackground()
      tabBar.standardAppearance = appearance
      if #available(iOS 15.0, *) {
        tabBar.scrollEdgeAppearance = appearance
      }
      tabBar.isTranslucent = true
    } else {
      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      appearance.backgroundEffect = UIBlurEffect(
        style: isDark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight
      )
      appearance.backgroundColor = UIColor.clear
      tabBar.standardAppearance = appearance
      if #available(iOS 15.0, *) {
        tabBar.scrollEdgeAppearance = appearance
      }
      tabBar.isTranslucent = true
    }
  }

  private func rebuildTabs() {
    let items = itemsConfig.map { item -> UITabBarItem in
      let tabItem = UITabBarItem(
        title: item.label,
        image: UIImage(systemName: item.icon),
        selectedImage: UIImage(systemName: item.selectedIcon)
      )
      tabItem.tag = item.id
      return tabItem
    }
    tabBar.items = items
  }

  func updateSelectedIndex(_ index: Int) {
    guard let items = tabBar.items,
          index >= 0,
          index < items.count else {
      return
    }
    tabBar.selectedItem = items[index]
  }

  func updateTheme(_ isDark: Bool) {
    guard self.isDark != isDark else { return }
    self.isDark = isDark
    if #unavailable(iOS 26.0) {
      configureAppearance()
    }
  }

  func setVisible(_ visible: Bool) {
    guard isHidden == visible || alpha != (visible ? 1 : 0) else {
      return
    }

    if visible {
      isHidden = false
    }
    isUserInteractionEnabled = visible
    UIView.animate(withDuration: 0.22, animations: {
      self.alpha = visible ? 1 : 0
    }, completion: { _ in
      self.isHidden = !visible
    })
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    YYNativeTabBarBridge.shared.notifyMetricsChanged()
  }

  func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
    YYNativeTabBarBridge.shared.notifyTabSelected(item.tag)
    onTabTap?(item.tag)
  }
}
