import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'core.dart';
import 'firebase_options.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await app.init();
  // Desktop only: open the window at a fixed phone size (390 x 844).
  final desktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);
  if (desktop) {
    await windowManager.ensureInitialized();
    const size = Size(390, 844);
    await windowManager.waitUntilReadyToShow(
      const WindowOptions(size: size, minimumSize: size, maximumSize: size, center: true, title: 'Campus Locker'),
      () async {
        await windowManager.show();
        await windowManager.focus();
      },
    );
  }
  runApp(const CampusLockerApp());
}

class CampusLockerApp extends StatelessWidget {
  const CampusLockerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Campus Locker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: navy),
          scaffoldBackgroundColor: bg,
          appBarTheme: const AppBarTheme(
              backgroundColor: navy,
              foregroundColor: Colors.white,
              titleTextStyle: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
        home: ListenableBuilder(
          listenable: app,
          builder: (_, __) => !app.loggedIn ? const LoginScreen() : !app.hasProfile ? const SignUpScreen() : const HomeShell(),
        ),
      );
}
