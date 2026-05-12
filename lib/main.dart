// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Use normal mode — navigation bar is solid and always visible.
  // App content will sit above it, just like Instagram.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Status bar: transparent with white icons (matches navy AppBar).
  // Navigation bar: solid navy so it looks part of the app, not floating.
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1A3A5C), // navy — matches AppBar
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  final appProvider = AppProvider();
  await appProvider.load();

  runApp(
    ChangeNotifierProvider.value(
      value: appProvider,
      child: const JSSAirExpressApp(),
    ),
  );
}

class JSSAirExpressApp extends StatelessWidget {
  const JSSAirExpressApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSS Air Express',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Wrap every screen in a SafeArea so content always sits
      // between the status bar (top) and navigation bar (bottom).
      // This is exactly how Instagram handles it.
      builder: (context, child) => SafeArea(child: child!),
      home: const HomeScreen(),
    );
  }
}
