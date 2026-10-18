import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'character_director.dart';
import 'milo_character_viewer.dart';

class SharedCompanionViewerCoordinator extends ChangeNotifier {
  final Map<Object, _ViewerSlot> _slots = {};
  _ViewerSlot? _cachedSlot;
  int _sequence = 0;
  String? _viewerKey;
  String? _readyKey;
  Object? _loadError;
  bool _notificationScheduled = false;
  bool _disposed = false;

  _ViewerSlot? get _activeSlot {
    final candidates = _slots.values.where(
      (slot) => slot.enabled && slot.routeActive,
    );
    return candidates.isEmpty
        ? null
        : candidates.reduce((a, b) => a.sequence > b.sequence ? a : b);
  }

  _ViewerSlot? get _retainedSlot {
    final active = _activeSlot;
    if (active != null) return active;
    if (_slots.isNotEmpty) {
      return _slots.values.reduce((a, b) => a.sequence > b.sequence ? a : b);
    }
    return _cachedSlot;
  }

  bool isReady(String characterId, int generation) =>
      _readyKey == _keyFor(characterId, generation);

  Object? loadError(String characterId, int generation) =>
      _viewerKey == _keyFor(characterId, generation) ? _loadError : null;

  void updateSlot({
    required Object token,
    required LayerLink link,
    required String characterId,
    required CharacterDirector director,
    required String cameraOrbit,
    required String cameraTarget,
    required String fieldOfView,
    required int generation,
    required double width,
    required double height,
    required bool enabled,
    required bool routeActive,
    VoidCallback? onReady,
    ValueChanged<Object>? onError,
  }) {
    final previous = _slots[token];
    final slot = _ViewerSlot(
      token: token,
      sequence: previous?.sequence ?? _sequence++,
      link: link,
      characterId: characterId,
      director: director,
      cameraOrbit: cameraOrbit,
      cameraTarget: cameraTarget,
      fieldOfView: fieldOfView,
      generation: generation,
      width: width,
      height: height,
      enabled: enabled,
      routeActive: routeActive,
      onReady: onReady,
      onError: onError,
    );
    _slots[token] = slot;
    _cachedSlot = slot;

    final active = _activeSlot;
    if (active != null) {
      final key = _keyFor(active.characterId, active.generation);
      if (_viewerKey != key) {
        _viewerKey = key;
        _readyKey = null;
        _loadError = null;
      }
    }

    if (previous == null ||
        previous.link != link ||
        previous.characterId != characterId ||
        previous.director != director ||
        previous.cameraOrbit != cameraOrbit ||
        previous.cameraTarget != cameraTarget ||
        previous.fieldOfView != fieldOfView ||
        previous.generation != generation ||
        previous.width != width ||
        previous.height != height ||
        previous.enabled != enabled ||
        previous.routeActive != routeActive) {
      notifyListeners();
    }

    if (isReady(characterId, generation)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_slots[token] == slot) slot.onReady?.call();
      });
    } else {
      final error = loadError(characterId, generation);
      if (error != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_slots[token] == slot) slot.onError?.call(error);
        });
      }
    }
  }

  void setRouteActive(Object token, bool active) {
    final slot = _slots[token];
    if (slot == null || slot.routeActive == active) return;
    slot.routeActive = active;
    if (active) slot.sequence = _sequence++;
    final current = _activeSlot;
    if (current != null) {
      final key = _keyFor(current.characterId, current.generation);
      if (_viewerKey != key) {
        _viewerKey = key;
        _readyKey = null;
        _loadError = null;
      }
    }
    notifyListeners();
  }

  void removeSlot(Object token) {
    if (_slots.remove(token) == null) return;
    final active = _activeSlot;
    if (active != null) {
      final key = _keyFor(active.characterId, active.generation);
      if (_viewerKey != key) {
        _viewerKey = key;
        _readyKey = null;
        _loadError = null;
      }
    }
    if (_notificationScheduled || _disposed) return;
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void viewerReady() {
    final slot = _retainedSlot;
    if (slot == null) return;
    _readyKey = _keyFor(slot.characterId, slot.generation);
    _loadError = null;
    for (final candidate in _slots.values) {
      if (candidate.characterId == slot.characterId &&
          candidate.generation == slot.generation) {
        candidate.onReady?.call();
      }
    }
    notifyListeners();
  }

  void viewerFailed(Object error) {
    final slot = _retainedSlot;
    if (slot == null) return;
    _loadError = error;
    for (final candidate in _slots.values) {
      if (candidate.characterId == slot.characterId &&
          candidate.generation == slot.generation) {
        candidate.onError?.call(error);
      }
    }
    notifyListeners();
  }

  String _keyFor(String characterId, int generation) =>
      '$characterId:$generation';
}

class _ViewerSlot {
  _ViewerSlot({
    required this.token,
    required this.sequence,
    required this.link,
    required this.characterId,
    required this.director,
    required this.cameraOrbit,
    required this.cameraTarget,
    required this.fieldOfView,
    required this.generation,
    required this.width,
    required this.height,
    required this.enabled,
    required this.routeActive,
    required this.onReady,
    required this.onError,
  });

  final Object token;
  int sequence;
  final LayerLink link;
  final String characterId;
  final CharacterDirector director;
  final String cameraOrbit;
  final String cameraTarget;
  final String fieldOfView;
  final int generation;
  final double width;
  final double height;
  final bool enabled;
  bool routeActive;
  final VoidCallback? onReady;
  final ValueChanged<Object>? onError;
}

class SharedCharacterViewerSlot extends StatefulWidget {
  const SharedCharacterViewerSlot({
    super.key,
    required this.director,
    required this.characterId,
    required this.cameraOrbit,
    required this.cameraTarget,
    required this.fieldOfView,
    this.generation = 0,
    this.enabled = true,
    this.onReady,
    this.onError,
    this.loadingColor = const Color(0xffc58a13),
    this.loadingLabel,
  });

  final CharacterDirector director;
  final String characterId;
  final String cameraOrbit;
  final String cameraTarget;
  final String fieldOfView;
  final int generation;
  final bool enabled;
  final VoidCallback? onReady;
  final ValueChanged<Object>? onError;
  final Color loadingColor;
  final String? loadingLabel;

  @override
  State<SharedCharacterViewerSlot> createState() =>
      _SharedCharacterViewerSlotState();
}

class _SharedCharacterViewerSlotState extends State<SharedCharacterViewerSlot>
    with RouteAware {
  final Object _token = Object();
  final LayerLink _link = LayerLink();
  SharedCompanionViewerCoordinator? _coordinator;
  RouteObserver<ModalRoute<dynamic>>? _routeObserver;
  ModalRoute<dynamic>? _route;
  bool _routeActive = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = context.read<SharedCompanionViewerCoordinator>();
    final routeObserver = context.read<RouteObserver<ModalRoute<dynamic>>>();
    final observerChanged = _routeObserver != routeObserver;
    if (_coordinator != coordinator || _routeObserver != routeObserver) {
      if (_route != null) {
        _routeObserver?.unsubscribe(this);
      }
      _coordinator?.removeSlot(_token);
      _coordinator = coordinator;
      _routeObserver = routeObserver;
    }
    final route = ModalRoute.of(context);
    if (_route != route || observerChanged) {
      if (_route != null) routeObserver.unsubscribe(this);
      _route = route;
      if (route != null) {
        routeObserver.subscribe(this, route);
        _routeActive = route.isCurrent;
      } else {
        _routeActive = true;
      }
    }
  }

  @override
  void didUpdateWidget(covariant SharedCharacterViewerSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleUpdate();
  }

  @override
  void didPush() => _setRouteActive(true);

  @override
  void didPopNext() => _setRouteActive(true);

  @override
  void didPushNext() => _setRouteActive(false);

  @override
  void didPop() => _setRouteActive(false);

  void _setRouteActive(bool active) {
    _routeActive = active;
    _coordinator?.setRouteActive(_token, active);
    _scheduleUpdate();
  }

  void _scheduleUpdate([Size? measuredSize]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      final size = measuredSize ??
          (renderObject is RenderBox ? renderObject.size : Size.zero);
      _update(size);
    });
  }

  void _update(Size size) {
    final coordinator = _coordinator;
    if (coordinator == null) return;
    coordinator.updateSlot(
      token: _token,
      link: _link,
      characterId: widget.characterId,
      director: widget.director,
      cameraOrbit: widget.cameraOrbit,
      cameraTarget: widget.cameraTarget,
      fieldOfView: widget.fieldOfView,
      generation: widget.generation,
      width: size.width,
      height: size.height,
      enabled: widget.enabled,
      routeActive: _routeActive,
      onReady: widget.onReady,
      onError: widget.onError,
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
            constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
          );
          _scheduleUpdate(size);
          return CompositedTransformTarget(
            link: _link,
            child: AnimatedBuilder(
              animation: context.read<SharedCompanionViewerCoordinator>(),
              builder: (context, _) {
                final coordinator =
                    context.read<SharedCompanionViewerCoordinator>();
                final ready = coordinator.isReady(
                  widget.characterId,
                  widget.generation,
                );
                final error = coordinator.loadError(
                  widget.characterId,
                  widget.generation,
                );
                if (!widget.enabled || ready) {
                  return SizedBox.fromSize(size: size);
                }
                return ColoredBox(
                  color: Colors.white.withValues(alpha: 0.12),
                  child: Center(
                    child: error == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: widget.loadingColor,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                              if (widget.loadingLabel case final label?) ...[
                                const SizedBox(height: 8),
                                Text(
                                  label,
                                  style: const TextStyle(
                                    color: Color(0xff536071),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : const Icon(
                            Icons.view_in_ar_rounded,
                            color: Color(0xff6f7882),
                            size: 30,
                          ),
                  ),
                );
              },
            ),
          );
        },
      );

  @override
  void dispose() {
    if (_route != null) _routeObserver?.unsubscribe(this);
    _coordinator?.removeSlot(_token);
    super.dispose();
  }
}

class SharedCharacterViewerHost extends StatelessWidget {
  const SharedCharacterViewerHost({
    super.key,
    required this.coordinator,
  });

  final SharedCompanionViewerCoordinator coordinator;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: coordinator,
        builder: (context, _) {
          final active = coordinator._activeSlot;
          final retained = coordinator._retainedSlot;
          if (retained == null || retained.width <= 0 || retained.height <= 0) {
            return const SizedBox.shrink();
          }
          final slot = active ?? retained;
          return Positioned.fill(
            child: ClipRect(
              child: IgnorePointer(
                child: Offstage(
                  offstage: active == null,
                  child: CompositedTransformFollower(
                    link: slot.link,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.topLeft,
                    followerAnchor: Alignment.topLeft,
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: slot.width,
                        height: slot.height,
                        child: CompanionCharacterViewer(
                          key: ValueKey(
                            '${slot.characterId}:${slot.generation}',
                          ),
                          director: slot.director,
                          characterId: slot.characterId,
                          cameraOrbit: slot.cameraOrbit,
                          cameraTarget: slot.cameraTarget,
                          fieldOfView: slot.fieldOfView,
                          modelScale: '1 1 1',
                          onReady: coordinator.viewerReady,
                          onError: coordinator.viewerFailed,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
}
