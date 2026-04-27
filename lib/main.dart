import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'login_page.dart';
import 'ui/stream_monitor_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env file - optional for local dev
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env file not found - this is okay for development
    // The app will work with default/hardcoded values
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('[App] Firebase init error: $e');
  }

  runApp(const ProviderScope(child: RightsGuardApp()));
}

class RightsGuardApp extends StatelessWidget {
  const RightsGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ApexVerify',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: AppColors.primaryBrand,
        textTheme: GoogleFonts.interTextTheme(
          Theme.of(context).textTheme,
        ),
        scaffoldBackgroundColor: AppColors.background,
      ),
      // Start with login page
      home: const LoginPage(),
      routes: {
        '/monitor': (_) => const StreamMonitorScreen(),
      },
    );
  }
}