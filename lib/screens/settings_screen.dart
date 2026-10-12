import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell.dart';
import 'permission_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _urlController.text = state.backendUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  void _saveAndTestUrl(AppState state) async {
    setState(() => _isTesting = true);
    String? saveError;
    try {
      await state.setBackendUrl(_urlController.text.trim());
    } catch (error, stackTrace) {
      debugPrint('Could not save backend address: $error\n$stackTrace');
      saveError = 'Could not save the backend address. Please try again.';
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          saveError ??
              (state.isServerConnected
                  ? 'Connected to Milo (${state.serverModel})'
                  : 'Could not connect to ${_urlController.text}. Please verify the address and port.'),
        ),
        backgroundColor:
            saveError == null && state.isServerConnected
                ? const Color(0xff10b981)
                : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (context, state, _) => AppShell(
          title: 'Settings',
          showBack: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              const Text(
                'AI Backend & Server',
                style: TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: state.isServerConnected
                                  ? const Color(0xff10b981)
                                  : const Color(0xffef4444),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isServerConnected
                                ? 'Connected (${state.serverModel})'
                                : 'Server Disconnected',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: state.isServerConnected
                                  ? const Color(0xff059669)
                                  : const Color(0xffdc2626),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Server API URL:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _urlController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          hintText: 'http://localhost:8000',
                          filled: true,
                          fillColor: AppTheme.canvas,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide:
                                const BorderSide(color: Color(0xffcbd5e1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              _isTesting ? null : () => _saveAndTestUrl(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isTesting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.link_rounded, size: 18),
                          label: Text(_isTesting
                              ? 'Testing...'
                              : 'Save & Test Connection'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'For a physical phone, use a backend address reachable over your local network.',
                        style: TextStyle(fontSize: 11, color: AppTheme.muted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Companion',
                style: TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: state.ttsEnabled,
                      onChanged: state.setTtsEnabled,
                      title: const Text('Spoken replies'),
                      subtitle: const Text(
                          'Read Milo’s responses aloud on this device'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Permissions',
                style: TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xffe2e8f0)),
                ),
                child: ListTile(
                  leading:
                      const Icon(Icons.mic_none_rounded, color: AppTheme.blue),
                  title: const Text(
                    'Microphone access',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('Required for voice conversations'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PermissionScreen(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'About Milo',
                style: TextStyle(
                  color: AppTheme.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A conversational companion powered by your configured AI service.',
                style:
                    TextStyle(color: AppTheme.muted, height: 1.5, fontSize: 13),
              ),
            ],
          ),
        ),
      );
}
