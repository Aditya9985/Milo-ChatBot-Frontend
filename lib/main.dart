import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_chat_service.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const MiloApp(home: FirebaseAuthGate()));
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error\n$stackTrace');
    runApp(const MiloApp(home: FirebaseSetupRequiredScreen()));
  }
}

class MiloApp extends StatelessWidget {
  const MiloApp({super.key, this.home = const FirebaseAuthGate()});

  final Widget home;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Milo',
        theme: AppTheme.data(),
        home: home,
      );
}

class FirebaseAuthGate extends StatelessWidget {
  const FirebaseAuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) return const AuthScreen();

          return ChangeNotifierProvider(
            create: (_) => AppState(
              chatService: ApiChatService(
                sessionTokenProvider: () async =>
                    FirebaseAuth.instance.currentUser?.getIdToken(),
              ),
              onSignOut: FirebaseAuth.instance.signOut,
            )..loadPreferences(),
            child: const HomeScreen(),
          );
        },
      );
}

class FirebaseSetupRequiredScreen extends StatelessWidget {
  const FirebaseSetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Configure Firebase Authentication for this app, then rebuild '
              'with its Firebase project settings. See frontend/README.md.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
}
