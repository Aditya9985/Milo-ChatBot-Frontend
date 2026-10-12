import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'character_director.dart';

class CompanionCharacterViewer extends StatefulWidget {
  const CompanionCharacterViewer({
    super.key,
    required this.director,
    this.onReady,
    this.onTap,
  });

  final CharacterDirector director;
  final VoidCallback? onReady;
  final VoidCallback? onTap;

  static const src = 'assets/grab3d-cozy-character.glb';

  @override
  State<CompanionCharacterViewer> createState() =>
      _CompanionCharacterViewerState();
}

class _CompanionCharacterViewerState extends State<CompanionCharacterViewer> {
  WebViewController? _controller;
  Widget? _viewer;
  bool _ready = false;
  String? _lastClip;
  bool? _lastSpeaking;
  int _lastWordTick = -1;

  @override
  void initState() {
    super.initState();
    widget.director.addListener(_onDirector);
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
    widget.director.removeListener(_onDirector);
    super.dispose();
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

  static const _lipSyncJs = r'''
    window.__miloMeshes = [];
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
    function __miloViseme(word) {
      const w = String(word || '').toLowerCase().replace(/[^a-z]/g, '');
      if (!w) return 0.08;
      if (/^[mbp]/.test(w)) return 0.05;
      if (/^[fv]/.test(w)) return 0.16;
      if (/w/.test(w) && /[oa]/.test(w)) return 0.58;
      if (/o/.test(w)) return 0.62;
      if (/[au]/.test(w)) return 0.52;
      if (/[ei]/.test(w)) return 0.34;
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
      const clip = clips.indexOf(name) >= 0 ? name : 'idle';
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
        if (window.MiloReady) MiloReady.postMessage('ready');
      });
    })();
  ''';

  @override
  Widget build(BuildContext context) {
    _viewer ??= AbsorbPointer(
      absorbing: true,
      child: ModelViewer(
        id: 'milo',
        src: CompanionCharacterViewer.src,
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
        cameraOrbit: '0deg 78deg 2.4m',
        cameraTarget: '0m 0.55m 0m',
        fieldOfView: '28deg',
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
              widget.onReady?.call();
              _lastClip = widget.director.clip;
              _applyAnimation(widget.director.clip);
              _applySpeaking(widget.director.speaking);
            },
          ),
        },
        onWebViewCreated: (controller) {
          _controller = controller;
        },
      ),
    );
    return _viewer!;
  }
}
