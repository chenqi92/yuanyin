import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'app/router/router.dart';
import 'app/theme/theme.dart';
import 'features/player/data/services/music_audio_handler.dart';
import 'features/player/presentation/providers/player_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 Hive
  await Hive.initFlutter();

  // 强制暗色状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: YYColors.bgBase,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // 初始化 AudioHandler（后台播放 + 系统媒体控制）
  MusicAudioHandler? audioHandler;
  try {
    audioHandler = await initAudioHandler();
  } catch (e) {
    debugPrint('AudioHandler 初始化失败: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (audioHandler != null)
          audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: const YuanYinApp(),
    ),
  );
}

/// 猿音 App 根组件
class YuanYinApp extends StatelessWidget {
  const YuanYinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '猿音',
      debugShowCheckedModeBanner: false,
      theme: buildYuanYinTheme(),
      routerConfig: goRouter,
    );
  }
}
