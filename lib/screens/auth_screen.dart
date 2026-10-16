import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isCreatingAccount = false;
  bool _isBusy = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      if (_isCreatingAccount) {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error.code));
    } catch (error, stackTrace) {
      debugPrint('Firebase sign-in failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not sign in right now. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Enter your email address first.');
      return;
    }

    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => _errorMessage = _messageFor(error.code));
    } catch (error, stackTrace) {
      debugPrint('Firebase password reset failed: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not send a reset email. Please try again.';
        });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  String _messageFor(String code) => switch (code) {
        'email-already-in-use' =>
          'An account already uses this email. Sign in instead.',
        'invalid-email' => 'Enter a valid email address.',
        'weak-password' =>
          'Choose a stronger password (at least 6 characters).',
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' =>
          'That email and password combination was not recognized.',
        'too-many-requests' =>
          'Too many attempts. Wait a little and try again.',
        'network-request-failed' =>
          'Check your internet connection and try again.',
        'operation-not-allowed' =>
          'Email/password sign-in is not enabled in Firebase yet.',
        _ => 'Authentication failed. Please try again.',
      };

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.blue,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isCreatingAccount
                            ? 'Create your Milo account'
                            : 'Welcome back',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isCreatingAccount
                            ? 'Sign up with your email and a password.'
                            : 'Sign in to continue chatting with Milo.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppTheme.muted),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (value) {
                          final email = value?.trim() ?? '';
                          if (email.isEmpty || !email.contains('@')) {
                            return 'Enter a valid email address.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        autofillHints: _isCreatingAccount
                            ? const [AutofillHints.newPassword]
                            : const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final password = value ?? '';
                          if (password.length < 6) {
                            return 'Use at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 50,
                        child: FilledButton(
                          onPressed: _isBusy ? null : _submit,
                          child: _isBusy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isCreatingAccount
                                      ? 'Create account'
                                      : 'Sign in',
                                ),
                        ),
                      ),
                      if (!_isCreatingAccount)
                        TextButton(
                          onPressed: _isBusy ? null : _sendPasswordReset,
                          child: const Text('Forgot password?'),
                        ),
                      TextButton(
                        onPressed: _isBusy
                            ? null
                            : () => setState(() {
                                  _isCreatingAccount = !_isCreatingAccount;
                                  _errorMessage = null;
                                }),
                        child: Text(
                          _isCreatingAccount
                              ? 'Already have an account? Sign in'
                              : 'New to Milo? Create an account',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
