import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class MiloSplashScreen extends StatelessWidget {
  const MiloSplashScreen({
    super.key,
    this.companionName = 'Milo',
    this.message = 'Getting everything ready…',
    this.onRetry,
  });

  final String companionName;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.canvas,
        body: Stack(
          children: [
            Positioned(
              top: -110,
              right: -75,
              child: _splashOrb(250, const Color(0xffffedb7)),
            ),
            Positioned(
              bottom: -130,
              left: -75,
              child: _splashOrb(280, const Color(0xfffff0c9)),
            ),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 196,
                        height: 196,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.76),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 5,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1a8a5a00),
                              blurRadius: 28,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Container(
                          width: 118,
                          height: 118,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.primaryContainer,
                                AppTheme.brightBlue.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            size: 62,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 27),
                      Text(
                        companionName,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 7),
                      const Text(
                        'A little wonder is on its way',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 30),
                      if (onRetry == null) ...[
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: AppTheme.blue,
                            backgroundColor: AppTheme.primaryContainer
                                .withValues(alpha: 0.4),
                          ),
                        ),
                        const SizedBox(height: 13),
                      ],
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          message,
                          key: ValueKey(message),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.subtle,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (onRetry != null) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text('Try loading $companionName again'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.blue,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _splashOrb(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
