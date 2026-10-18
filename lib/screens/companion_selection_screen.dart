import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/companion_choice_card.dart';

class CompanionSelectionScreen extends StatefulWidget {
  const CompanionSelectionScreen({super.key, this.enable3dPreviews = true});

  final bool enable3dPreviews;

  @override
  State<CompanionSelectionScreen> createState() =>
      _CompanionSelectionScreenState();
}

class _CompanionSelectionScreenState extends State<CompanionSelectionScreen> {
  String _selected = 'milo';
  bool _saving = false;

  Future<void> _enter() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AppState>().setCompanion(_selected);
    } catch (error, stackTrace) {
      debugPrint('Could not save selected companion: $error\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your choice. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppTheme.data(suzu: _selected == 'suzu');
    return AnimatedTheme(
      data: theme,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 42, 22, 28),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer
                                .withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          Icons.auto_awesome_rounded,
                            color: theme.colorScheme.primary,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'MILO & SUZU',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Choose your companion',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 25,
                      height: 1.18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pick the friend you’d like to explore, learn, and talk with.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 13,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 254,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: CompanionChoiceCard(
                            id: 'milo',
                            name: 'Milo',
                            description: 'Boy · Explorer',
                            selected: _selected == 'milo',
                            enable3dPreview: widget.enable3dPreviews,
                            previewUnselected: true,
                            onTap: () => setState(() => _selected = 'milo'),
                          ),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: CompanionChoiceCard(
                            id: 'suzu',
                            name: 'Suzu',
                            description: 'Girl · Explorer',
                            selected: _selected == 'suzu',
                            enable3dPreview: widget.enable3dPreviews,
                            previewUnselected: true,
                            onTap: () => setState(() => _selected = 'suzu'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      onPressed: _saving ? null : _enter,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Enter ${_selected == 'suzu' ? 'Suzu' : 'Milo'}’s World',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward_rounded),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: Color(0xff4c8e58),
                        size: 16,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'A safe, friendly space made for curious minds',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
