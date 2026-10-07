import 'dart:async';

import 'package:flutter/material.dart';
import 'data/push.dart';
import 'data/storage_maintenance.dart';
import 'data/supa.dart';
import 'theme/kawaii.dart';
import 'theme/prefs.dart';
import 'screens/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bounded in-memory image cache so scrolling piles/map tiles can't
  // balloon RAM; disk is bounded separately in storage_maintenance.
  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;
  PaintingBinding.instance.imageCache.maximumSize = 200;
  // Fire-and-forget: picker leftovers + old OTA APKs, never blocks launch.
  unawaited(cleanupStaleAppFiles());
  await Supa.init();
  // Fire-and-forget: push must never delay first frame or trap splash.
  unawaited(Push.init());
  runApp(const OurSpaceApp());
}

class OurSpaceApp extends StatefulWidget {
  const OurSpaceApp({super.key});
  @override
  State<OurSpaceApp> createState() => _OurSpaceAppState();
}

class _OurSpaceAppState extends State<OurSpaceApp> {
  @override
  void initState() {
    super.initState();
    KawaiiPrefs.loadTheme();
    Kawaii.themeMode.addListener(_persist);
  }

  void _persist() {
    KawaiiPrefs.saveTheme(Kawaii.themeMode.value == ThemeMode.dark);
  }

  @override
  void dispose() {
    Kawaii.themeMode.removeListener(_persist);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Kawaii.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'ourspace',
          debugShowCheckedModeBanner: false,
          theme: Kawaii.light(),
          darkTheme: Kawaii.dark(),
          themeMode: mode,
          home: const AuthGate(),
        );
      },
    );
  }
}
