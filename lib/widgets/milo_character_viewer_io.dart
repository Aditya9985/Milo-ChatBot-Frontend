import 'dart:async';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'character_director.dart';

class CompanionCharacterViewer extends StatefulWidget {
  const CompanionCharacterViewer({
    super.key,
    required this.director,
    this.onReady,
    this.onError,
    this.onTap,
    this.characterId = 'milo',
    this.cameraOrbit = '0deg 78deg 2.4m',
    this.cameraTarget = '0m 0.55m 0m',
    this.fieldOfView = '28deg',
    this.modelScale = '1 1 1',
  });

  final CharacterDirector director;
  final VoidCallback? onReady;
  final ValueChanged<Object>? onError;
  final VoidCallback? onTap;
  final String characterId;
  final String cameraOrbit;
  final String cameraTarget;
  final String fieldOfView;
  final String modelScale;

  static const src = 'assets/grab3d-cozy-character.glb';

  @override
  State<CompanionCharacterViewer> createState() =>
      _CompanionCharacterViewerState();
}

class _CompanionCharacterViewerState extends State<CompanionCharacterViewer> {
  WebViewController? _controller;
  bool _ready = false;
  bool _loadErrorReported = false;
  Timer? _loadTimeout;
  String? _lastClip;
  bool? _lastSpeaking;
  int _lastWordTick = -1;

  @override
  void initState() {
    super.initState();
    widget.director.addListener(_onDirector);
    _startLoadTimeout();
  }

  @override
  void didUpdateWidget(covariant CompanionCharacterViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.director != widget.director) {
      oldWidget.director.removeListener(_onDirector);
      widget.director.addListener(_onDirector);
    }
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    widget.director.removeListener(_onDirector);
    super.dispose();
  }

  void _startLoadTimeout() {
    _loadTimeout?.cancel();
    _loadTimeout = Timer(const Duration(seconds: 30), () {
      if (!_ready) {
        _reportLoadError(
          StateError(
              'The companion model did not finish loading in 30 seconds.'),
        );
      }
    });
  }

  void _reportLoadError(Object error) {
    if (_loadErrorReported) return;
    _loadErrorReported = true;
    debugPrint('Companion GLB failed to load: $error');
    widget.onError?.call(error);
  }

  void _onDirector() {
    final clip = widget.director.clip;
    if (_lastClip != clip) {
      _lastClip = clip;
      _applyAnimation(clip);
    }
    if (_lastSpeaking != widget.director.speaking) {
      _lastSpeaking = widget.director.speaking;
      _applySpeaking(widget.director.speaking);
    }
    if (_lastWordTick != widget.director.wordTick) {
      _lastWordTick = widget.director.wordTick;
      _applyWord(widget.director.spokenWord);
    }
  }

  Future<void> _applyAnimation(String name) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript("__miloPlay(${_jsString(name)});");
    } catch (_) {}
  }

  Future<void> _applySpeaking(bool on) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript("__miloSpeak(${on ? 'true' : 'false'});");
    } catch (_) {}
  }

  Future<void> _applyWord(String word) async {
    final controller = _controller;
    if (controller == null) return;
    try {
      await controller.runJavaScript("__miloWord(${_jsString(word)});");
    } catch (_) {}
  }

  String _jsString(String value) => "'${value.replaceAll("'", r"\'")}'";

  String get _modelAsset => widget.characterId == 'suzu'
      ? 'assets/grab3d-cozy-character-girl.glb'
      : CompanionCharacterViewer.src;

  static const _lipSyncJs = r'''
    window.__miloMeshes = [];
    window.__miloMouthMesh = null;
    window.__miloMouthBase = null;
    window.__miloLastBody = 'idle';
    window.__face = { mouth:0, mouthT:0, smile:0, smileT:0, blink:0, blinkT:0,
      speaking:false, lastWordAt:0, nextExprAt:0, nextBlinkAt:0 };
    function __miloCollect(root) {
      if (!root) return;
      const stack = [root];
      while (stack.length) {
        const obj = stack.pop();
        if (obj && obj.morphTargetInfluences && obj.morphTargetInfluences.length) {
          window.__miloMeshes.push(obj);
        }
        if (obj && obj.isMesh && obj.material) {
          const materials = Array.isArray(obj.material) ? obj.material : [obj.material];
          if (materials.some((material) => material && material.name === 'fix_mouth')) {
            const geometry = obj.geometry;
            if (geometry && !geometry.boundingBox && geometry.computeBoundingBox) {
              geometry.computeBoundingBox();
            }
            const bounds = geometry && geometry.boundingBox;
            window.__miloMouthMesh = obj;
            window.__miloMouthBase = {
              scaleY:obj.scale.y,
              positionY:obj.position.y,
              centerY:bounds
                ? (bounds.min.y + bounds.max.y) / 2
                : 0
            };
          }
        }
        const kids = (obj && obj.children) || [];
        for (let i = 0; i < kids.length; i++) stack.push(kids[i]);
      }
    }
    function __miloFindScene(mv) {
      const seen = [];
      const visit = function(obj, depth) {
        if (!obj || depth > 5) return null;
        for (let i = 0; i < seen.length; i++) if (seen[i] === obj) return null;
        seen.push(obj);
        if (obj.isScene) return obj;
        if (obj.scene && obj.scene.isScene) return obj.scene;
        try {
          const syms = Object.getOwnPropertySymbols(obj);
          for (let i = 0; i < syms.length; i++) {
            const found = visit(obj[syms[i]], depth + 1);
            if (found) return found;
          }
        } catch (e) {}
        return null;
      };
      return visit(mv, 0);
    }
    window.__miloMotion = {
      root:null, base:null, name:'idle', startedAt:0, procedural:false
    };
    function __miloBindMotion(mv) {
      const scene = __miloFindScene(mv);
      if (!scene) return;
      const hasMesh = function(root) {
        const stack = [root];
        while (stack.length) {
          const obj = stack.pop();
          if (obj && obj.isMesh) return true;
          const kids = (obj && obj.children) || [];
          for (let i = 0; i < kids.length; i++) stack.push(kids[i]);
        }
        return false;
      };
      const root = (scene.children || []).find(hasMesh) || scene;
      window.__miloMotion.root = root;
      window.__miloMotion.base = {
        x:root.position.x, y:root.position.y, z:root.position.z,
        rx:root.rotation.x, ry:root.rotation.y, rz:root.rotation.z
      };
    }
    function __miloResetMotion() {
      const motion = window.__miloMotion;
      if (!motion.root || !motion.base) return;
      const {root, base} = motion;
      root.position.set(base.x, base.y, base.z);
      root.rotation.set(base.rx, base.ry, base.rz);
    }
    function __miloViseme(word) {
      const w = String(word || '').toLowerCase().replace(/[^a-z]/g, '');
      if (!w) return String(word || '').trim() ? 0.34 : 0.08;
      if (/^[mbp]/.test(w)) return 0.05;
      if (/^[fv]/.test(w)) return 0.16;
      if (/o/.test(w)) return 0.64;
      if (/u/.test(w)) return 0.52;
      if (/a/.test(w)) return 0.58;
      if (/[ei]/.test(w)) return 0.32;
      if (/[aeiou]/.test(w)) return 0.4;
      return 0.14;
    }
    function __miloApplyFace() {
      const f = window.__face;
      const meshes = window.__miloMeshes;
      for (let i = 0; i < meshes.length; i++) {
        const obj = meshes[i];
        const inf = obj.morphTargetInfluences;
        if (!inf) continue;
        const d = obj.morphTargetDictionary || {};
        if ('open' in d) inf[d.open] = f.mouth;
        if ('smile' in d) inf[d.smile] = f.smile;
        if ('blink' in d) inf[d.blink] = f.blink;
        if (!('open' in d) && !('blink' in d)) {
          if (inf.length >= 2) { inf[0] = f.mouth; inf[1] = f.smile; }
          else inf[0] = Math.max(f.mouth, f.blink);
        }
      }
      const mouth = window.__miloMouthMesh;
      const base = window.__miloMouthBase;
      if (mouth && base) {
        const verticalScale = base.scaleY * (1 + Math.max(0, f.mouth) * 3.4);
        mouth.scale.y = verticalScale;
        mouth.position.y =
          base.positionY + base.centerY * (1 - verticalScale / base.scaleY);
      }
    }
    window.__miloWord = function(word) {
      const f = window.__face;
      f.mouthT = __miloViseme(word);
      f.lastWordAt = performance.now();
      const lw = String(word || '').toLowerCase();
      if (/hi|hey|yay|happy|love|hehe|wow|thanks/.test(lw)) {
        f.smileT = Math.min(0.72, Math.max(f.smileT, 0.4));
      }
    };
    window.__miloSpeak = function(on) {
      const f = window.__face;
      f.speaking = !!on;
      const now = performance.now();
      if (!on) {
        f.mouthT = 0;
        f.smileT = 0;
        f.blinkT = 0;
        return;
      }
      const mv = document.querySelector('model-viewer');
      if (mv && !window.__miloMeshes.length) __miloBind(mv);
      f.smileT = 0.16;
      f.nextExprAt = now + 800;
      f.nextBlinkAt = now + 600;
    };
    window.__miloPlay = function(name) {
      const mv = document.querySelector('model-viewer');
      if (!mv) return;
      const looping = ['idle','listen','talk','dance'];
      const clips = mv.availableAnimations || [];
      const motion = window.__miloMotion;
      motion.name = name;
      motion.startedAt = performance.now();
      if (!motion.root) __miloBindMotion(mv);
      motion.procedural = clips.indexOf(name) < 0;
      if (motion.procedural) {
        __miloResetMotion();
        mv.animationName = 'idle';
        mv.play();
        return;
      }
      __miloResetMotion();
      const clip = name;
      if (clip !== 'talk') window.__miloLastBody = clip;
      try { mv.animationCrossfadeDuration = 320; } catch (e) {}
      if (mv.animationName === clip) {
        try { mv.currentTime = 0; } catch (e) {}
      }
      mv.animationName = clip;
      try {
        if (looping.indexOf(clip) >= 0) { mv.play(); }
        else { mv.play({repetitions: 1}); }
      } catch (e) {
        if (mv.play) mv.play();
      }
    };
    function __miloBind(mv) {
      window.__miloMeshes = [];
      const scene = __miloFindScene(mv);
      if (scene) __miloCollect(scene);
    }
    (function loop(now) {
      requestAnimationFrame(loop);
      const f = window.__face;
      const motion = window.__miloMotion;
      const root = motion.root;
      const base = motion.base;
      if (root && base && motion.procedural &&
          ['listen','talk','dance','spin','think'].indexOf(motion.name) >= 0) {
        const t = (now - motion.startedAt) / 1000;
        if (motion.name === 'dance') {
          root.position.y = base.y + Math.abs(Math.sin(t * 5.5)) * 0.065;
          root.rotation.x = base.rx + Math.sin(t * 5.5) * 0.035;
          root.rotation.y = base.ry + Math.sin(t * 2) * 0.1;
          root.rotation.z = base.rz + Math.sin(t * 2.7) * 0.12;
        } else if (motion.name === 'spin') {
          const progress = Math.min(1, t / 1.45);
          root.rotation.y = base.ry + progress * Math.PI * 2;
          root.position.y = base.y + Math.sin(progress * Math.PI) * 0.04;
        } else if (motion.name === 'talk') {
          root.position.y = base.y + Math.sin(t * 7) * 0.012;
          root.rotation.x = base.rx + Math.sin(t * 3.5) * 0.018;
        } else if (motion.name === 'think') {
          root.position.y = base.y + Math.sin(t * 1.4) * 0.006;
          root.rotation.x = base.rx - 0.055 + Math.sin(t * 1.1) * 0.012;
          root.rotation.z = base.rz + 0.065;
        } else {
          root.position.y = base.y + Math.sin(t * 2.2) * 0.008;
          root.rotation.x = base.rx + Math.sin(t * 2.2) * 0.035;
        }
      }
      if (f.speaking) {
        if (now - f.lastWordAt > 260) f.mouthT = 0.09;
        if (now > f.nextExprAt) {
          const pick = Math.random();
          if (pick < 0.34) f.smileT = 0.22;
          else if (pick < 0.62) f.smileT = 0.5;
          else if (pick < 0.82) f.smileT = 0.08;
          else f.smileT = 0.64;
          f.nextExprAt = now + 1100 + Math.random() * 1500;
        }
        if (now > f.nextBlinkAt) {
          f.blinkT = 1;
          f.nextBlinkAt = now + 1800 + Math.random() * 2200;
          setTimeout(function() { f.blinkT = 0; }, 140);
        }
      }
      const ease = f.speaking ? 0.07 : 0.05;
      f.mouth += (f.mouthT - f.mouth) * ease;
      f.smile += (f.smileT - f.smile) * 0.045;
      f.blink += (f.blinkT - f.blink) * 0.28;
      __miloApplyFace();
    })(0);
    (function() {
      const mv = document.querySelector('model-viewer');
      if (!mv) return;
      mv.addEventListener('load', function() {
        __miloBind(mv);
        __miloBindMotion(mv);
        if (window.MiloReady) MiloReady.postMessage('ready');
      });
      mv.addEventListener('error', function(event) {
        const detail = event && event.detail ? String(event.detail) : 'GLB load failed';
        if (window.MiloError) MiloError.postMessage(detail);
      });
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: ModelViewer(
        id: 'milo-${widget.characterId}',
        src: _modelAsset,
        alt: 'Milo companion model',
        loading: Loading.eager,
        autoPlay: true,
        animationName: 'idle',
        animationCrossfadeDuration: 320,
        cameraControls: false,
        disablePan: true,
        disableTap: true,
        disableZoom: true,
        touchAction: TouchAction.none,
        backgroundColor: const Color(0x00000000),
        cameraOrbit: widget.cameraOrbit,
        cameraTarget: widget.cameraTarget,
        fieldOfView: widget.fieldOfView,
        scale: widget.modelScale,
        exposure: 1,
        environmentImage: 'neutral',
        shadowIntensity: 1,
        shadowSoftness: 0.8,
        interactionPrompt: InteractionPrompt.none,
        relatedCss:
            'model-viewer { --poster-color: transparent; touch-action: none; pointer-events: none; }',
        relatedJs: _lipSyncJs,
        javascriptChannels: {
          JavascriptChannel(
            'MiloReady',
            onMessageReceived: (_) {
              if (_ready) return;
              _ready = true;
              _loadTimeout?.cancel();
              widget.onReady?.call();
              _lastClip = widget.director.clip;
              _applyAnimation(widget.director.clip);
              _applySpeaking(widget.director.speaking);
            },
          ),
          JavascriptChannel(
            'MiloError',
            onMessageReceived: (message) {
              _reportLoadError(StateError(message.message));
            },
          ),
        },
        onWebViewCreated: (controller) {
          _controller = controller;
        },
      ),
    );
  }
}
