import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Owns the current clip and decides what the companion should do next.
///
/// The 3D viewer listens to this and only runs JS — it does not rebuild
/// the WebView when the clip changes.
class CharacterDirector extends ChangeNotifier {
  CharacterDirector();

  static const looping = {'idle', 'listen', 'talk', 'dance', 'think'};
  static const oneshot = {'jump', 'wave', 'spin', 'run', 'walk'};
  static const userMoves = ['jump', 'dance', 'wave', 'spin'];

  final _rng = Random();
  String clip = 'idle';
  int generation = 0;
  bool busy = false;
  bool speaking = false;
  String spokenWord = '';
  String speechText = '';
  int wordTick = 0;
  bool liveLocked = false;
  String lastUserMove = '';
  int combo = 0;
  Timer? _hold;
  Timer? _wander;

  void startWandering() {
    _wander?.cancel();
    _wander = Timer.periodic(const Duration(seconds: 6), (_) => _maybeWander());
  }

  void _maybeWander() {
    if (busy || liveLocked || speaking || clip != 'idle') return;
    final move = _smartRandom();
    play(move, userInitiated: false);
  }

  String _smartRandom() {
    if (combo >= 2 && lastUserMove == 'jump') return 'dance';
    if (lastUserMove == 'spin') return 'wave';
    if (lastUserMove == 'dance') {
      return _rng.nextBool() ? 'spin' : 'wave';
    }
    const pool = ['wave', 'wave', 'jump', 'spin', 'dance'];
    var pick = pool[_rng.nextInt(pool.length)];
    if (pick == lastUserMove) {
      pick = pool[_rng.nextInt(pool.length)];
    }
    return pick;
  }

  Duration durationFor(String name) {
    switch (name) {
      case 'jump':
        return const Duration(milliseconds: 1200);
      case 'wave':
        return const Duration(milliseconds: 1700);
      case 'spin':
        return const Duration(milliseconds: 2000);
      case 'run':
        return const Duration(milliseconds: 2200);
      case 'walk':
        return const Duration(milliseconds: 2500);
      case 'dance':
        return const Duration(milliseconds: 4000);
      default:
        return const Duration(milliseconds: 1800);
    }
  }

  String lineFor(String name, {String companion = 'Milo'}) {
    switch (name) {
      case 'jump':
        return const [
          'Whee! Super jump!',
          'Up I go!',
          'Did you see that jump?'
        ][_rng.nextInt(3)];
      case 'dance':
        return const [
          'Let’s dance! 1, 2, 3!',
          'Music time!',
          'I have the moves!'
        ][_rng.nextInt(3)];
      case 'wave':
        return [
          'Hi there!',
          '$companion here!',
          'Hello, hello!'
        ][_rng.nextInt(3)];
      case 'spin':
        return const [
          'Whoa, spinning!',
          'Dizzy... hehe!',
          'Round and round!'
        ][_rng.nextInt(3)];
      default:
        return 'Here I go!';
    }
  }

  void play(String name, {bool userInitiated = true, Duration? hold}) {
    if (liveLocked && userInitiated && name != 'listen') {
      // Allow playful moves even while live, but snap back to listen after.
    }
    if (userInitiated) {
      if (name == lastUserMove) {
        combo += 1;
      } else {
        combo = 1;
        lastUserMove = name;
      }
    }
    generation += 1;
    final token = generation;
    clip = name;
    busy = oneshot.contains(name) || name == 'dance';
    notifyListeners();

    _hold?.cancel();
    if (looping.contains(name)) {
      busy = false;
      return;
    }
    final wait = hold ?? durationFor(name);
    _hold = Timer(wait, () {
      if (token != generation) return;
      busy = false;
      if (liveLocked) {
        clip = 'listen';
      } else if (name != 'idle') {
        clip = 'idle';
      }
      notifyListeners();
    });
  }

  void setLiveLocked(bool locked) {
    liveLocked = locked;
    if (locked) {
      play('listen', userInitiated: false);
    } else if (clip == 'listen' || clip == 'talk') {
      play('idle', userInitiated: false);
    }
  }

  void setSpeaking(bool value) {
    if (speaking == value) return;
    speaking = value;
    if (!value) {
      spokenWord = '';
      speechText = '';
    }
    play(
      value ? 'talk' : (liveLocked ? 'listen' : 'idle'),
      userInitiated: false,
    );
  }

  void setSpeechText(String text) {
    if (speechText == text) return;
    speechText = text;
    spokenWord = '';
    notifyListeners();
  }

  void setSpeechProgress(double progress) {
    if (!speaking || speechText.isEmpty) return;
    final words = speechText
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return;

    final weights = words
        .map((word) => word
            .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '')
            .length
            .clamp(1, 12))
        .toList();
    final totalWeight = weights.fold<int>(0, (sum, weight) => sum + weight);
    var elapsedWeight = (progress.clamp(0.0, 1.0) * totalWeight).floor();
    for (var index = 0; index < words.length; index++) {
      if (elapsedWeight < weights[index] || index == words.length - 1) {
        setSpokenWord(words[index]
            .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''));
        return;
      }
      elapsedWeight -= weights[index];
    }
  }

  void setSpokenWord(String word) {
    if (spokenWord == word) return;
    spokenWord = word;
    wordTick += 1;
    notifyListeners();
  }

  void setTalking(bool talking) => setSpeaking(talking);

  void fromReply(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('dance') || lower.contains('music')) {
      play('dance', userInitiated: false);
    } else if (lower.contains('spin') || lower.contains('turn')) {
      play('spin', userInitiated: false);
    } else if (lower.contains('jump') ||
        lower.contains('yay') ||
        lower.contains('happy')) {
      play('jump', userInitiated: false);
    } else if (lower.contains('run') || lower.contains('hurry')) {
      play('run', userInitiated: false);
    } else if (lower.contains('walk') || lower.contains('go')) {
      play('walk', userInitiated: false);
    } else {
      play('wave', userInitiated: false);
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    _wander?.cancel();
    super.dispose();
  }
}
