import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var tabBarOverlayWindow: UIWindow?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)

    guard let windowScene = scene as? UIWindowScene,
          let flutterWindow = windowScene.windows.first,
          let flutterVC = flutterWindow.rootViewController as? FlutterViewController else {
      return
    }

    let overlay = PassthroughWindow(windowScene: windowScene)
    overlay.windowLevel = .normal + 1
    overlay.backgroundColor = .clear
    overlay.isHidden = false

    let tabBarHost = FloatingTabBarController(
      messenger: flutterVC.engine.binaryMessenger
    )
    overlay.rootViewController = tabBarHost
    overlay.makeKeyAndVisible()

    tabBarOverlayWindow = overlay
    flutterWindow.makeKeyAndVisible()
  }
}

// MARK: - PassthroughWindow

/// 只拦截 tab bar 和搜索界面的触摸，其余透传给 Flutter
final class PassthroughWindow: UIWindow {
  override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    guard let hit = super.hitTest(point, with: event) else { return nil }
    guard let tabBarController = rootViewController as? FloatingTabBarController else {
      return nil
    }

    // 始终拦截 tab bar 触摸
    if hit === tabBarController.tabBar || hit.isDescendant(of: tabBarController.tabBar) {
      return hit
    }

    // 搜索激活时，拦截搜索界面的触摸（导航栏、搜索栏、搜索结果区域）
    if tabBarController.isSearchActive {
      return hit
    }

    return nil
  }
}

// MARK: - FloatingTabBarController

final class FloatingTabBarController: UITabBarController, UITabBarControllerDelegate {
  private let messenger: FlutterBinaryMessenger
  private var channel: FlutterMethodChannel?
  private var suppressDelegateEvents = false

  /// 当前是否处于搜索模式（PassthroughWindow 检查此标志）
  var isSearchActive = false

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    delegate = self
    view.backgroundColor = .clear

    let accentColor = UIColor(red: 246/255, green: 141/255, blue: 46/255, alpha: 1)
    tabBar.tintColor = accentColor

    if #available(iOS 18.0, *) {
      configureTabs_iOS18()
    } else {
      configureTabs_legacy()
    }

    configureTabBarAppearance()
    setupMethodChannel()
  }

  // MARK: iOS 18+ — UITab + UISearchTab

  @available(iOS 18.0, *)
  private func configureTabs_iOS18() {
    let clearVC: () -> UIViewController = {
      let vc = UIViewController()
      vc.view.backgroundColor = .clear
      return vc
    }

    let homeTab = UITab(
      title: "首页",
      image: UIImage(systemName: "house"),
      identifier: "home"
    ) { _ in clearVC() }

    let libraryTab = UITab(
      title: "音乐库",
      image: UIImage(systemName: "square.stack.3d.down.right"),
      identifier: "library"
    ) { _ in clearVC() }

    let settingsTab = UITab(
      title: "设置",
      image: UIImage(systemName: "slider.horizontal.3"),
      identifier: "settings"
    ) { _ in clearVC() }

    // 搜索 Tab — 使用原生 UISearchController
    let searchTab = UISearchTab { [weak self] _ in
      guard let self = self else { return UIViewController() }
      return self.createSearchHostVC()
    }

    tabs = [homeTab, libraryTab, settingsTab, searchTab]
  }

  // MARK: 低版本 — UITabBarItem

  private func configureTabs_legacy() {
    let items: [(String, String, String?, Int)] = [
      ("首页", "house", "house.fill", 0),
      ("音乐库", "square.stack.3d.down.right", "square.stack.3d.down.right.fill", 1),
      ("设置", "slider.horizontal.3", nil, 2),
      ("搜索", "magnifyingglass", nil, 3),
    ]

    viewControllers = items.map { title, icon, selectedIcon, tag in
      let vc: UIViewController
      if tag == 3 {
        vc = createSearchHostVC()
      } else {
        vc = UIViewController()
        vc.view.backgroundColor = .clear
      }
      vc.tabBarItem = UITabBarItem(
        title: title,
        image: UIImage(systemName: icon),
        selectedImage: selectedIcon != nil ? UIImage(systemName: selectedIcon!) : nil
      )
      vc.tabBarItem.tag = tag
      return vc
    }
  }

  // MARK: 创建原生搜索 VC

  private func createSearchHostVC() -> UIViewController {
    let searchResultsVC = NativeSearchResultsController(channel: channel)
    let searchController = UISearchController(searchResultsController: nil)
    searchController.searchResultsUpdater = searchResultsVC
    searchController.delegate = searchResultsVC
    searchController.obscuresBackgroundDuringPresentation = false
    searchController.searchBar.placeholder = "搜索歌曲、艺术家、专辑"

    let hostVC = searchResultsVC
    hostVC.title = "搜索"
    hostVC.navigationItem.searchController = searchController
    hostVC.navigationItem.hidesSearchBarWhenScrolling = false
    hostVC.definesPresentationContext = true

    let nav = UINavigationController(rootViewController: hostVC)
    nav.navigationBar.prefersLargeTitles = true
    hostVC.navigationItem.largeTitleDisplayMode = .always

    if #available(iOS 26.0, *) {
      // Liquid Glass 自动应用于导航栏
    } else {
      let navAppearance = UINavigationBarAppearance()
      navAppearance.configureWithDefaultBackground()
      navAppearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
      nav.navigationBar.standardAppearance = navAppearance
      nav.navigationBar.scrollEdgeAppearance = navAppearance
    }

    return nav
  }

  // MARK: Appearance

  private func configureTabBarAppearance() {
    if #available(iOS 26.0, *) {
      // Liquid Glass 自动生效
    } else {
      let appearance = UITabBarAppearance()
      appearance.configureWithDefaultBackground()
      appearance.backgroundEffect = UIBlurEffect(style: .systemChromeMaterial)
      appearance.backgroundColor = .clear
      tabBar.standardAppearance = appearance
      if #available(iOS 15.0, *) {
        tabBar.scrollEdgeAppearance = appearance
      }
    }
    tabBar.isTranslucent = true
  }

  // MARK: MethodChannel

  private func setupMethodChannel() {
    channel = FlutterMethodChannel(
      name: "yy/native_tab_bar_service",
      binaryMessenger: messenger
    )
    channel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(FlutterMethodNotImplemented); return }
      switch call.method {
      case "setSelectedIndex":
        if let index = call.arguments as? Int {
          self.suppressDelegateEvents = true
          self.selectedIndex = min(index, (self.viewControllers?.count ?? 1) - 1)
          self.suppressDelegateEvents = false
        }
        result(nil)
      case "setTabBarVisible":
        if let visible = call.arguments as? Bool {
          self.setTabBarVisible(visible, animated: true)
        }
        result(nil)
      case "getTabBarHeight":
        result(Double(self.tabBar.bounds.height))
      case "getSafeAreaBottom":
        result(Double(self.view.safeAreaInsets.bottom))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: 可见性

  private func setTabBarVisible(_ visible: Bool, animated: Bool) {
    let hidden = !visible
    guard tabBar.isHidden != hidden else { return }
    if animated {
      if !hidden { tabBar.isHidden = false }
      UIView.animate(withDuration: 0.22, animations: {
        self.tabBar.alpha = hidden ? 0 : 1
      }, completion: { _ in
        self.tabBar.isHidden = hidden
      })
    } else {
      tabBar.isHidden = hidden
      tabBar.alpha = hidden ? 0 : 1
    }
  }

  // MARK: UITabBarControllerDelegate

  @available(iOS 18.0, *)
  func tabBarController(
    _ tabBarController: UITabBarController,
    didSelectTab selectedTab: UITab,
    previousTab: UITab?
  ) {
    guard !suppressDelegateEvents else { return }
    let index = tabs.firstIndex(of: selectedTab) ?? 0

    // 搜索 Tab（index 3）→ 激活搜索模式
    if selectedTab is UISearchTab {
      isSearchActive = true
      channel?.invokeMethod("onTabSelected", arguments: index)
      return
    }

    // 其他 Tab → 关闭搜索模式
    isSearchActive = false
    channel?.invokeMethod("onTabSelected", arguments: index)
  }

  func tabBarController(
    _ tabBarController: UITabBarController,
    didSelect viewController: UIViewController
  ) {
    guard !suppressDelegateEvents else { return }
    if #available(iOS 18.0, *) { return }
    let index = viewControllers?.firstIndex(of: viewController) ?? 0

    if index == 3 {
      isSearchActive = true
    } else {
      isSearchActive = false
    }

    channel?.invokeMethod("onTabSelected", arguments: index)
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    channel?.invokeMethod("onMetricsChanged", arguments: [
      "tabBarHeight": tabBar.bounds.height,
      "safeAreaBottom": view.safeAreaInsets.bottom,
    ])
  }
}

// MARK: - NativeSearchResultsController

/// 原生搜索 VC，转发搜索查询到 Flutter
final class NativeSearchResultsController:
  UIViewController,
  UISearchResultsUpdating,
  UISearchControllerDelegate
{
  private weak var channel: FlutterMethodChannel?
  private var debounceTimer: Timer?

  init(channel: FlutterMethodChannel?) {
    self.channel = channel
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    // 背景半透明以看到 Flutter 内容
    view.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.85)
  }

  // MARK: UISearchResultsUpdating

  func updateSearchResults(for searchController: UISearchController) {
    let query = searchController.searchBar.text ?? ""
    debounceTimer?.invalidate()
    debounceTimer = Timer.scheduledTimer(withTimeInterval: 0.22, repeats: false) { [weak self] _ in
      self?.channel?.invokeMethod("onSearchQuery", arguments: query)
    }
  }

  // MARK: UISearchControllerDelegate

  func willDismissSearchController(_ searchController: UISearchController) {
    channel?.invokeMethod("onSearchQuery", arguments: "")
  }
}
