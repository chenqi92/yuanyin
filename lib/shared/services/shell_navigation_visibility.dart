import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_tab_bar_service.dart';

class ShellNavigationVisibility {
  ShellNavigationVisibility._();

  static final ShellNavigationVisibility instance =
      ShellNavigationVisibility._();

  final ValueNotifier<int> _hiddenDepth = ValueNotifier<int>(0);

  ValueListenable<int> get listenable => _hiddenDepth;

  bool get isVisible => _hiddenDepth.value == 0;

  void hide() {
    _hiddenDepth.value = _hiddenDepth.value + 1;
    NativeTabBarService.instance.setTabBarVisible(false);
  }

  void show() {
    if (_hiddenDepth.value == 0) return;
    _hiddenDepth.value = _hiddenDepth.value - 1;
    if (_hiddenDepth.value == 0) {
      NativeTabBarService.instance.setTabBarVisible(true);
    }
  }

  void reset() {
    if (_hiddenDepth.value == 0) return;
    _hiddenDepth.value = 0;
    NativeTabBarService.instance.setTabBarVisible(true);
  }
}

mixin ShellNavigationVisibilityMixin<T extends StatefulWidget> on State<T> {
  bool _didHideNavigation = false;

  void hideShellNavigation() {
    if (_didHideNavigation) return;
    _didHideNavigation = true;
    ShellNavigationVisibility.instance.hide();
  }

  void showShellNavigation() {
    if (!_didHideNavigation) return;
    _didHideNavigation = false;
    ShellNavigationVisibility.instance.show();
  }

  @override
  void dispose() {
    if (_didHideNavigation) {
      ShellNavigationVisibility.instance.show();
    }
    super.dispose();
  }
}

mixin ConsumerShellNavigationVisibilityMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  bool _didHideNavigation = false;

  void hideShellNavigation() {
    if (_didHideNavigation) return;
    _didHideNavigation = true;
    ShellNavigationVisibility.instance.hide();
  }

  void showShellNavigation() {
    if (!_didHideNavigation) return;
    _didHideNavigation = false;
    ShellNavigationVisibility.instance.show();
  }

  @override
  void dispose() {
    if (_didHideNavigation) {
      ShellNavigationVisibility.instance.show();
    }
    super.dispose();
  }
}
