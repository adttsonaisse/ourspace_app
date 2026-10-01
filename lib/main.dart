import 'package:flutter/material.dart';
import 'data/supa.dart';
import 'theme/kawaii.dart';
import 'theme/prefs.dart';
import 'screens/auth_get_started.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supa.init();
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
          home: const GetStartedPage(),
        );
      },
    );
  }
}
