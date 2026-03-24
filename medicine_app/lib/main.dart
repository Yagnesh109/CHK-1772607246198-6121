import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/theme/app_theme.dart';
import 'core/navigation/route_observer.dart';
import 'features/secure/data/secure_store_service.dart';
import 'firebase_options.dart';
import 'pages/home_page.dart';
import 'pages/login_page.dart';
import 'pages/role_selection_page.dart';
import 'features/voice/voice_assistant_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {}
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('hi'), Locale('mr')],
      path: 'assets/translations',
      startLocale: const Locale('mr'),
      fallbackLocale: const Locale('mr'),
      useOnlyLangCode: true,
      saveLocale: true,
      child: const MedicineApp(),
    ),
  );
}

class MedicineApp extends StatelessWidget {
  const MedicineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      title: 'MediMind',
      navigatorObservers: [appRouteObserver],
      builder: (context, child) => child ?? const SizedBox.shrink(),
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user != null) {
          // New login: clear any cached role from a previous session so we
          // force-fetch the correct role (or show role selection) for this user.
          SecureStoreService.setCachedRole(null);
          // Show the app immediately; fetch role in the background and only
          // redirect if it is missing. This keeps startup snappy even when the
          // backend is cold.
          return _PostAuthGate(user: user);
        }

        return const LoginPage();
      },
    );
  }
}

class _PostAuthGate extends StatefulWidget {
  const _PostAuthGate({required this.user});

  final User user;

  @override
  State<_PostAuthGate> createState() => _PostAuthGateState();
}

class _PostAuthGateState extends State<_PostAuthGate> {
  @override
  void initState() {
    super.initState();
    _prefetchProfile();
  }

  Future<void> _prefetchProfile() async {
    try {
      final profile = await SecureStoreService.getUserProfile(forceRefresh: true);
      if (!mounted) return;
      final role = profile['role']?.toString().trim();
      if (role == null || role.isEmpty) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => RoleSelectionPage(user: widget.user)),
        );
      }
    } catch (_) {
      // Swallow background errors; the user can still use the app and retries
      // happen on other screens.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Render HomePage immediately; profile check happens in the background.
    return const HomePage();
  }
}
