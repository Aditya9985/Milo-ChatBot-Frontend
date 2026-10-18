import 'package:flutter_test/flutter_test.dart';
import 'package:milo_companion/widgets/character_director.dart';

void main() {
  test('uses the talk loop and returns to listening after a spoken reply', () {
    final director = CharacterDirector();
    director.setLiveLocked(true);
    director.setSpeechText('Hello Milo, how are you?');

    director.setSpeaking(true);
    expect(director.clip, 'talk');

    director.setSpeaking(false);
    expect(director.clip, 'listen');
    director.dispose();
  });

  test('advances mouth words using speech playback progress', () {
    final director = CharacterDirector()
      ..setSpeechText('Hello little friend')
      ..setSpeaking(true);

    director.setSpeechProgress(0);
    expect(director.spokenWord, 'Hello');
    director.setSpeechProgress(0.55);
    expect(director.spokenWord, 'little');
    director.setSpeechProgress(1);
    expect(director.spokenWord, 'friend');

    director.dispose();
  });
}
