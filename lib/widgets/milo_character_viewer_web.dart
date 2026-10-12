import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

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

  @override
  State<CompanionCharacterViewer> createState() =>
      _CompanionCharacterViewerState();
}

class _CompanionCharacterViewerState extends State<CompanionCharacterViewer> {
  late final String _viewType;
  web.HTMLIFrameElement? _iframe;
  JSFunction? _messageListener;
  bool _ready = false;
  String? _lastClip;
  bool? _lastSpeaking;
  int _lastWordTick = -1;

  @override
  void initState() {
    super.initState();
    _viewType = 'milo-3d-${identityHashCode(this)}';
    widget.director.addListener(_onDirector);
    _messageListener = ((web.MessageEvent event) {
      final data = event.data.dartify();
      if (data == 'milo-ready' && !_ready) {
        _ready = true;
        widget.onReady?.call();
        _postAnimation(widget.director.clip);
        _postSpeaking(widget.director.speaking);
      }
    }).toJS;
    web.window.addEventListener('message', _messageListener);

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = Uri.base.resolve('milo_viewer.html').toString()
        ..allow = 'autoplay'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'transparent';
      iframe.setAttribute('allowtransparency', 'true');
      _iframe = iframe;
      return iframe;
    });
  }

  @override
  void didUpdateWidget(covariant CompanionCharacterViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.director != widget.director) {
      oldWidget.director.removeListener(_onDirector);
      widget.director.addListener(_onDirector);
    }
  }

  void _onDirector() {
    final clip = widget.director.clip;
    if (_lastClip != clip) {
      _lastClip = clip;
      _postAnimation(clip);
    }
    if (_lastSpeaking != widget.director.speaking) {
      _lastSpeaking = widget.director.speaking;
      _postSpeaking(widget.director.speaking);
    }
    if (_lastWordTick != widget.director.wordTick) {
      _lastWordTick = widget.director.wordTick;
      _postWord(widget.director.spokenWord);
    }
  }

  void _postAnimation(String name) {
    _iframe?.contentWindow?.postMessage('anim:$name'.toJS, '*'.toJS);
  }

  void _postSpeaking(bool on) {
    _iframe?.contentWindow?.postMessage(
      (on ? 'speak:on' : 'speak:off').toJS,
      '*'.toJS,
    );
  }

  void _postWord(String word) {
    _iframe?.contentWindow?.postMessage('word:$word'.toJS, '*'.toJS);
  }

  @override
  void dispose() {
    widget.director.removeListener(_onDirector);
    if (_messageListener != null) {
      web.window.removeEventListener('message', _messageListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
