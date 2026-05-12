// lib/main.dart
//
// Changes from original:
//   • Calls DriveSyncService.instance.tryRestoreSignIn() before load().
//     This silently restores a previous Google sign-in so that the very first
//     load() already syncs from Drive (no manual sign-in needed after first time).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';
import 'services/drive_sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF1A3A5C),
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Try to restore a previous Google sign-in silently.
  // If it succeeds, load() will automatically pull from Drive.
  // If it fails (first run), the user signs in from the home screen.
  await DriveSyncService.instance.tryRestoreSignIn();

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
      builder: (context, child) => SafeArea(child: child!),
      home: const HomeScreen(),
    );
  }
}
