import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() => runApp(ChangeNotifierProvider(
    create: (_) => AppState()..loadPreferences(), child: const MiloApp()));

class MiloApp extends StatelessWidget {
  const MiloApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Milo',
      theme: AppTheme.data(),
      home: const HomeScreen());
}
