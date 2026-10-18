import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'character_director.dart';
import 'shared_companion_viewer.dart';

class CompanionModelPreview extends StatefulWidget {
  const CompanionModelPreview({
    super.key,
    required this.characterId,
    required this.backgroundColor,
    this.cameraOrbit = '0deg 78deg 120%',
    this.enabled = true,
    this.useSharedCoordinator = false,
  });

  final String characterId;
  final Color backgroundColor;
  final String cameraOrbit;
  final bool enabled;
  final bool useSharedCoordinator;

  @override
  State<CompanionModelPreview> createState() => _CompanionModelPreviewState();
}

class _CompanionModelPreviewState extends State<CompanionModelPreview> {
  final CharacterDirector _director = CharacterDirector();
  final SharedCompanionViewerCoordinator _coordinator =
      SharedCompanionViewerCoordinator();
  String? _greetedCharacterId;

  @override
  void dispose() {
    _director.dispose();
    _coordinator.dispose();
    super.dispose();
  }

  void _greet() {
    if (_greetedCharacterId == widget.characterId) return;
    _greetedCharacterId = widget.characterId;
    _director.play('wave', userInitiated: false);
  }

  @override
  Widget build(BuildContext context) {
    final isSuzu = widget.characterId == 'suzu';
    final coordinator = widget.useSharedCoordinator
        ? context.read<SharedCompanionViewerCoordinator>()
        : _coordinator;
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: ColoredBox(
        color: widget.backgroundColor,
        child: ChangeNotifierProvider.value(
          value: coordinator,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                right: -36,
                top: -44,
                child: _glow(
                  126,
                  (isSuzu ? const Color(0xffffc4d7) : const Color(0xffffdf8b))
                      .withValues(alpha: 0.34),
                ),
              ),
              Positioned(
                left: -28,
                bottom: -56,
                child: _glow(116, Colors.white.withValues(alpha: 0.68)),
              ),
              if (widget.enabled)
                SharedCharacterViewerSlot(
                  director: _director,
                  characterId: widget.characterId,
                  cameraOrbit: widget.cameraOrbit,
                  cameraTarget: 'auto auto auto',
                  fieldOfView: 'auto',
                  loadingColor: isSuzu
                      ? const Color(0xffd96c91)
                      : const Color(0xffc58a13),
                  onReady: _greet,
                )
              else
                Center(
                  child: Icon(
                    isSuzu ? Icons.face_3_rounded : Icons.face_rounded,
                    size: 42,
                    color: isSuzu
                        ? const Color(0xffbd6a78)
                        : const Color(0xff8a5a00),
                  ),
                ),
              if (!widget.enabled)
                const Positioned(
                  left: 4,
                  right: 4,
                  bottom: 5,
                  child: Text(
                    'Preview unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xff6f7882),
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (!widget.useSharedCoordinator)
                SharedCharacterViewerHost(coordinator: coordinator),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      );
}
