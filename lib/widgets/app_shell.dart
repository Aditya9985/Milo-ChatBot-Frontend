import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppShell extends StatelessWidget {
  const AppShell(
      {super.key,
      required this.title,
      required this.child,
      this.actions = const [],
      this.showBack = false});
  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool showBack;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          leading: showBack
              ? IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded))
              : null,
          title: Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
          actions: actions),
      body: SafeArea(child: child));
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.onPressed,
      this.outline = false});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool outline;
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 52,
      child: FilledButton.icon(
          style: FilledButton.styleFrom(
              backgroundColor: outline ? Colors.white : AppTheme.blue,
              foregroundColor: outline ? AppTheme.blue : Colors.white,
              side: outline ? const BorderSide(color: AppTheme.paleBlue) : null,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18))),
          onPressed: onPressed,
          icon: Icon(icon, size: 20),
          label: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700))));
}
