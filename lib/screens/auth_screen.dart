import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme/app_theme.dart';
import '../widgets/companion_model_preview.dart';

Future<void>? _googleSignInInitialization;

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.enable3dPreview = true});

  final bool enable3dPreview;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _isBusy = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      _googleSignInInitialization ??= GoogleSignIn.instance.initialize();
      await _googleSignInInitialization;
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw StateError(
          'Google did not return an ID token. Check the Firebase Android '
          'app SHA-1 and Google sign-in configuration.',
        );
      }
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      if (error.code != GoogleSignInExceptionCode.canceled && mounted) {
        setState(() => _errorMessage = _googleErrorMessage(error));
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _firebaseErrorMessage(error.code));
      }
    } catch (error, stackTrace) {
      debugPrint('Google sign-in failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Google sign-in could not start. Check your connection and '
              'Firebase Google sign-in settings.';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _googleErrorMessage(GoogleSignInException error) {
    if (error.code == GoogleSignInExceptionCode.clientConfigurationError) {
      return 'Google sign-in is not fully configured. Check this app’s SHA-1 '
          'in Firebase and refresh its Android configuration.';
    }
    return 'Google sign-in failed. Please try again.';
  }

  String _firebaseErrorMessage(String code) => switch (code) {
        'account-exists-with-different-credential' =>
          'An account already exists with a different sign-in method.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'operation-not-allowed' =>
          'Google sign-in is not enabled in Firebase Authentication.',
        'too-many-requests' =>
          'Too many attempts. Wait a little and try again.',
        _ => 'Could not sign in with Google. Please try again.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.paleBlue.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.auto_awesome_rounded,
                              color: AppTheme.blue, size: 16),
                          const SizedBox(width: 7),
                          Text(
                            'A LITTLE COMPANION, A LOT OF WONDER',
                            style: TextStyle(
                              color: AppTheme.blue,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.paleBlue.withValues(alpha: 0.36),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.blue.withValues(alpha: 0.08),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: CompanionModelPreview(
                        characterId: 'milo',
                        backgroundColor: Colors.transparent,
                        cameraOrbit: '0deg 78deg 130%',
                        enabled: widget.enable3dPreview,
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Meet Milo',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 29,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'A friendly AI companion for curious minds.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.subtle,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 27),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isBusy ? null : _signInWithGoogle,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.blue,
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          elevation: 2,
                        ),
                        child: _isBusy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _GoogleMark(),
                                  SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.red,
                          fontSize: 13,
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    const Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppTheme.muted,
                          size: 14,
                        ),
                        SizedBox(width: 6, height: 20),
                        Text(
                          'Secure sign-in with your Google account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'MADE FOR LITTLE ADVENTURES',
                      style: TextStyle(
                        color: AppTheme.muted.withValues(alpha: 0.8),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: const Text(
          'G',
          style: TextStyle(
            color: Color(0xff4285f4),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
}
