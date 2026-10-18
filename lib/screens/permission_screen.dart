import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';

class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});
  @override
  Widget build(BuildContext context) => AppShell(
      title: 'Microphone access',
      showBack: true,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryContainer.withValues(alpha: 0.28),
              border: Border.all(color: Colors.white, width: 5),
            ),
            child: Icon(
              Icons.mic_rounded,
              size: 68,
              color: AppTheme.blue,
            ),
          ),
          const SizedBox(height: 22),
          const Text('Let’s talk out loud',
              style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.ink)),
          const SizedBox(height: 10),
          Text(
              '${context.watch<AppState>().companionName} uses microphone access for voice conversations. You can change this later in device settings.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.muted, height: 1.5)),
          const SizedBox(height: 28),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.mic_rounded),
                  label: const Text('Allow microphone'))),
        ]),
      ));
}
