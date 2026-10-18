import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/companion_choice_card.dart';
import 'permission_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.enable3dPreviews = true});

  final bool enable3dPreviews;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _signOut(AppState state) async {
    try {
      await state.signOut();
    } catch (error, stackTrace) {
      debugPrint('Could not sign out of Firebase: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please retry.')),
      );
    }
  }

  Future<void> _selectCompanion(AppState state, String companionId) async {
    try {
      await state.setCompanion(companionId);
    } catch (error, stackTrace) {
      debugPrint('Could not change companion: $error\n$stackTrace');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not change companion. Retry.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Consumer<AppState>(
        builder: (context, state, _) {
          final user = state.accountUser;
          final selectedCompanionId = state.companionId ?? 'milo';
          final displayName = user?.displayName?.trim();
          final accountName = displayName == null || displayName.isEmpty
              ? 'Companion user'
              : displayName;
          final email = user?.email;

          return Scaffold(
            appBar: AppBar(
              toolbarHeight: 68,
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${state.companionName} Companion',
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppTheme.paleBlue),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 8,
                        color: Color(0xff16845b),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.companionName.toUpperCase(),
                        style: const TextStyle(
                          color: AppTheme.ink,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                _SectionHeading(
                  icon: Icons.account_circle_outlined,
                  title: 'Account',
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xffeaf7ef),
                      border: Border.all(color: const Color(0xffc9ead5)),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 7, color: Color(0xff16845b)),
                        SizedBox(width: 5),
                        Text(
                          'Active session',
                          style: TextStyle(
                            color: Color(0xff176b47),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 9),
                _SettingsCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _AccountAvatar(
                            photoUrl: user?.photoURL,
                            name: accountName,
                          ),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  accountName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (email != null && email.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    email,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 13,
                                      color: AppTheme.brightBlue,
                                    ),
                                    const SizedBox(width: 4),
                                    const Flexible(
                                      child: Text(
                                        'Firebase Auth · Google',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: AppTheme.muted,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (state.onSignOut != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton.icon(
                            onPressed: () => _signOut(state),
                            icon: const Icon(Icons.logout_rounded, size: 17),
                            label: const Text('Sign out of your account'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.red,
                              backgroundColor: AppTheme.wash,
                              side: const BorderSide(color: Color(0xffffdedb)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(
                  icon: Icons.face_retouching_natural_rounded,
                  title: 'Your companion',
                ),
                const SizedBox(height: 9),
                _SettingsCard(
                  child: Column(
                    children: [
                      CompanionChoiceCard(
                        id: 'milo',
                        name: 'Milo',
                        description: 'Boy · warm voice',
                        selected: selectedCompanionId == 'milo',
                        compact: true,
                        enable3dPreview: widget.enable3dPreviews,
                        previewUnselected: true,
                        onTap: () => _selectCompanion(state, 'milo'),
                      ),
                      const SizedBox(height: 9),
                      CompanionChoiceCard(
                        id: 'suzu',
                        name: 'Suzu',
                        description: 'Girl · bright voice',
                        selected: selectedCompanionId == 'suzu',
                        compact: true,
                        enable3dPreview: widget.enable3dPreviews,
                        previewUnselected: true,
                        onTap: () => _selectCompanion(state, 'suzu'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Voice & Speech',
                ),
                const SizedBox(height: 9),
                _SettingsCard(
                  padding: EdgeInsets.zero,
                  child: SwitchListTile.adaptive(
                    value: state.ttsEnabled,
                    onChanged: state.setTtsEnabled,
                    activeTrackColor: AppTheme.primaryContainer,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 15,
                      vertical: 5,
                    ),
                    secondary: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppTheme.wash,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.volume_up_rounded,
                        color: AppTheme.blue,
                        size: 21,
                      ),
                    ),
                    title: const Text(
                      'Spoken replies',
                      style: TextStyle(
                        color: AppTheme.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        'Play ${state.companionName}’s replies aloud. Device speech is used if cloud audio is unavailable.',
                        style: const TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(
                  icon: Icons.tune_rounded,
                  title: 'Permissions',
                ),
                const SizedBox(height: 9),
                _SettingsCard(
                  padding: EdgeInsets.zero,
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 3,
                      ),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.wash,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.mic_none_rounded,
                          color: AppTheme.blue,
                          size: 21,
                        ),
                      ),
                      title: const Text(
                        'Microphone access',
                        style: TextStyle(
                          color: AppTheme.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Manage voice conversation permissions',
                        style: TextStyle(color: AppTheme.muted, fontSize: 11),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.muted,
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PermissionScreen(),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const _SectionHeading(
                  icon: Icons.info_outline_rounded,
                  title: 'About Milo',
                ),
                const SizedBox(height: 9),
                _SettingsCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        color: AppTheme.brightBlue,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'A friendly AI companion for conversation and spoken replies.',
                          style: TextStyle(
                            color: AppTheme.muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                    'MILO COMPANION',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.icon,
    required this.title,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: AppTheme.blue, size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.ink,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.child,
    this.padding = const EdgeInsets.all(15),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xffe4e8ef)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: child,
        ),
      );
}

class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({required this.photoUrl, required this.name});

  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) => Container(
        width: 54,
        height: 54,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppTheme.paleBlue, width: 2),
        ),
        child: ClipOval(
          child: photoUrl == null || photoUrl!.isEmpty
              ? _fallback
              : Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _fallback,
                ),
        ),
      );

  Widget get _fallback {
    final initial = name.isEmpty ? 'M' : name[0].toUpperCase();
    return ColoredBox(
      color: AppTheme.wash,
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: AppTheme.blue,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
