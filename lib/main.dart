import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/companion_selection_screen.dart';
import 'screens/home_screen.dart';
import 'services/api_chat_service.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/milo_splash_screen.dart';
import 'widgets/shared_companion_viewer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FirebaseBootstrap());
}

class MiloApp extends StatefulWidget {
  const MiloApp({
    super.key,
    this.home = const FirebaseAuthGate(),
    this.viewerCoordinator,
  });

  final Widget home;
  final SharedCompanionViewerCoordinator? viewerCoordinator;

  @override
  State<MiloApp> createState() => _MiloAppState();
}

class _MiloAppState extends State<MiloApp> {
  final SharedCompanionViewerCoordinator _localViewerCoordinator =
      SharedCompanionViewerCoordinator();
  final RouteObserver<ModalRoute<dynamic>> _routeObserver =
      RouteObserver<ModalRoute<dynamic>>();

  @override
  void dispose() {
    _localViewerCoordinator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppState? state;
    try {
      state = Provider.of<AppState>(context);
    } on ProviderNotFoundException {
      state = null;
    }
    final suzu = state?.companionId == 'suzu';
    final viewerCoordinator =
        widget.viewerCoordinator ?? _localViewerCoordinator;
    AppTheme.isSuzu = suzu;
    return ChangeNotifierProvider.value(
      value: viewerCoordinator,
      child: Provider<RouteObserver<ModalRoute<dynamic>>>.value(
        value: _routeObserver,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Milo',
          theme: AppTheme.data(suzu: suzu),
          navigatorObservers: [_routeObserver],
          builder: (context, child) => Stack(
            fit: StackFit.expand,
            children: [
              if (child != null) child,
              if (widget.viewerCoordinator == null)
                SharedCharacterViewerHost(coordinator: viewerCoordinator),
            ],
          ),
          home: widget.home,
        ),
      ),
    );
  }
}

class FirebaseBootstrap extends StatefulWidget {
  const FirebaseBootstrap({super.key});

  @override
  State<FirebaseBootstrap> createState() => _FirebaseBootstrapState();
}

class _FirebaseBootstrapState extends State<FirebaseBootstrap> {
  late Future<FirebaseApp> _initialization;
  final SharedCompanionViewerCoordinator _viewerCoordinator =
      SharedCompanionViewerCoordinator();

  @override
  void initState() {
    super.initState();
    _initialization = _initializeFirebase();
  }

  @override
  void dispose() {
    _viewerCoordinator.dispose();
    super.dispose();
  }

  Future<FirebaseApp> _initializeFirebase() async {
    return Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.ltr,
        child: ChangeNotifierProvider.value(
          value: _viewerCoordinator,
          child: Stack(
            fit: StackFit.expand,
            children: [
              FutureBuilder<FirebaseApp>(
                future: _initialization,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    debugPrint(
                        'Firebase initialization failed: ${snapshot.error}');
                    return MiloApp(
                      viewerCoordinator: _viewerCoordinator,
                      home: FirebaseSetupRequiredScreen(
                        onRetry: () => setState(() {
                          _initialization = _initializeFirebase();
                        }),
                      ),
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return MiloApp(
                      viewerCoordinator: _viewerCoordinator,
                      home: const FirebaseLoadingScreen(),
                    );
                  }
                  return const FirebaseAuthGate();
                },
              ),
              Builder(
                builder: (context) => MediaQuery(
                  data: MediaQueryData.fromView(View.of(context)),
                  child: SharedCharacterViewerHost(
                    coordinator: _viewerCoordinator,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class FirebaseAuthGate extends StatelessWidget {
  const FirebaseAuthGate({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MiloApp(home: FirebaseLoadingScreen());
          }

          final user = snapshot.data;
          final viewerCoordinator =
              context.read<SharedCompanionViewerCoordinator>();
          if (user == null) {
            return MiloApp(
              viewerCoordinator: viewerCoordinator,
              home: const AuthScreen(),
            );
          }

          return ChangeNotifierProvider(
            create: (_) => AppState(
              chatService: ApiChatService(
                sessionTokenProvider: () async =>
                    FirebaseAuth.instance.currentUser?.getIdToken(),
              ),
              onSignOut: FirebaseAuth.instance.signOut,
              accountUser: user,
              userId: user.uid,
            )..loadPreferences(),
            child: MiloApp(
              viewerCoordinator: viewerCoordinator,
              home: const AuthenticatedHomeGate(),
            ),
          );
        },
      );
}

class AuthenticatedHomeGate extends StatelessWidget {
  const AuthenticatedHomeGate({super.key});

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (context, state, _) {
          final viewerCoordinator =
              context.read<SharedCompanionViewerCoordinator>();
          if (!state.isReady) {
            return MiloApp(
              viewerCoordinator: viewerCoordinator,
              home: const FirebaseLoadingScreen(),
            );
          }
          if (state.companionId == null) {
            return MiloApp(
              viewerCoordinator: viewerCoordinator,
              home: const CompanionSelectionScreen(),
            );
          }
          return MiloApp(
            viewerCoordinator: viewerCoordinator,
            home: const HomeScreen(),
          );
        },
      );
}

class FirebaseSetupRequiredScreen extends StatelessWidget {
  const FirebaseSetupRequiredScreen({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Milo could not initialize Firebase.',
                  textAlign: TextAlign.center,
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: onRetry,
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
}

class FirebaseLoadingScreen extends StatelessWidget {
  const FirebaseLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const MiloSplashScreen(message: 'Waking up Milo…');
}
