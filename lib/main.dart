import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app/router/router.dart';
import 'app/theme/theme.dart';
import 'app/l10n/strings.dart';
import 'features/player/data/services/music_audio_handler.dart';
import 'features/player/presentation/providers/player_provider.dart';
import 'features/settings/data/services/settings_service.dart';
import 'shared/services/native_tab_bar_service.dart';
import 'shared/widgets/macos_menu_bar.dart';

import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.dumpErrorToConsole(details);
      runApp(MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                'FlutterError:\n${details.exceptionAsString()}\n\n${details.stack}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
        ),
      ));
    };

    NativeTabBarService.instance.initialize();

    // 初始化 Hive
    await Hive.initFlutter();

    // 初始化 AudioHandler（后台播放 + 系统媒体控制）
    MusicAudioHandler? audioHandler;
    try {
      audioHandler = await initAudioHandler();
    } catch (e, st) {
      debugPrint('AudioHandler 初始化失败: $e');
      runApp(MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                'AudioHandler Error:\n$e\n\n$st',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ),
        ),
      ));
      return;
    }

    runApp(
      ProviderScope(
        overrides: [
          if (audioHandler != null)
            audioHandlerProvider.overrideWith((ref) => audioHandler),
        ],
        child: const PrimuseApp(),
      ),
    );
  }, (error, stack) {
    runApp(MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Uncaught Error:\n$error\n\n$stack',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ),
      ),
    ));
  });
}

/// Primuse App 根组件 — 支持 light/dark/system 主题切换 + i18n
class PrimuseApp extends ConsumerWidget {
  const PrimuseApp({super.key});

  ThemeMode _resolveThemeMode(String mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final localeOverride = ref.watch(localeProvider);

    return MacOSMenuBar(
      child: MaterialApp.router(
        title: 'Primuse',
        debugShowCheckedModeBanner: false,
        theme: buildPrimuseLightTheme(),
        darkTheme: buildPrimuseDarkTheme(),
        themeMode: _resolveThemeMode(settings.themeMode),
        routerConfig: goRouter,
        locale: localeOverride,
        supportedLocales: S.supportedLocales,
        localizationsDelegates: const [
          SLocalizationDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
