import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'companion_model_preview.dart';

class CompanionChoiceCard extends StatelessWidget {
  const CompanionChoiceCard({
    super.key,
    required this.id,
    required this.name,
    required this.description,
    required this.selected,
    required this.onTap,
    this.compact = false,
    this.enable3dPreview = true,
    this.previewUnselected = false,
    this.useSharedPreviewCoordinator = false,
  });

  final String id;
  final String name;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;
  final bool enable3dPreview;
  final bool previewUnselected;
  final bool useSharedPreviewCoordinator;

  @override
  Widget build(BuildContext context) {
    final accent =
        id == 'suzu' ? const Color(0xffd96c91) : const Color(0xffc58a13);
    final tint =
        id == 'suzu' ? const Color(0xffffe8eb) : const Color(0xffffefc8);

    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $description',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.all(compact ? 12 : 16),
            decoration: BoxDecoration(
              color: selected
                  ? (id == 'suzu'
                      ? const Color(0xfffff3f7)
                      : const Color(0xfffff8e8))
                  : Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? accent : const Color(0xffeee9dc),
                width: selected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: selected
                      ? accent.withValues(alpha: 0.12)
                      : const Color(0x08000000),
                  blurRadius: selected ? 15 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: compact
                ? Row(
                    children: [
                      SizedBox(
                        width: 76,
                        height: 92,
                        child: CompanionModelPreview(
                          characterId: id,
                          backgroundColor: tint,
                          cameraOrbit: '0deg 78deg 190%',
                          enabled: enable3dPreview &&
                              (selected || previewUnselected),
                          useSharedCoordinator:
                              useSharedPreviewCoordinator,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: AppTheme.ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.muted,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: accent,
                          size: 20,
                        ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Stack(
                        children: [
                          SizedBox(
                            height: 146,
                            child: CompanionModelPreview(
                              characterId: id,
                              backgroundColor: tint,
                              enabled: enable3dPreview &&
                                  (selected || previewUnselected),
                              useSharedCoordinator:
                                  useSharedPreviewCoordinator,
                            ),
                          ),
                          if (selected)
                            Positioned(
                              right: -4,
                              top: -4,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: accent,
                                foregroundColor: Colors.white,
                                child:
                                    const Icon(Icons.check_rounded, size: 15),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    color: AppTheme.ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: accent,
                              size: 21,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to choose',
                        style: TextStyle(
                          color: AppTheme.muted.withValues(alpha: 0.85),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
